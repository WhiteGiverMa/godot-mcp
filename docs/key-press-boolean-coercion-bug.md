# game_key_press 传入 `pressed: false` 触发类型错误 — 游戏被调试器 break

**发现日期：** 2026-06-27
**状态：** 未修复（已定位根因，待修复）

## 现象

调用 `game_key_press({ action: "ui_accept", pressed: false })` 触发：

```
SCRIPT ERROR: Trying to assign value of type 'String' to a variable of type 'bool'.
   at: _cmd_key_press (res://mcp_interaction_server.gd:513)
   GDScript backtrace (most recent call first):
       [0] _cmd_key_press (res://mcp_interaction_server.gd:513)
       [1] _handle_command (res://mcp_interaction_server.gd:228)
       [2] _poll_connection (res://mcp_interaction_server.gd:99)
```

debug 模式下触发 `debug_break()` 暂停主线程，`_poll_timer` 停止轮询，后续所有 MCP 命令超时（30s after typed `key_press` tool calls），只能手动停游戏重启。

调用 `pressed: true` (默认值)或 `pressed` 未传时正常工作。

## 根因（双层缺陷）

### L1 GDScript 静态类型注解对传入值做严格类型检查

`mcp_interaction_server.gd` L513：

```gdscript
var pressed: bool = params.get("pressed", true)
```

`params` 来自 TCP JSON 反序列化的 Dictionary。理论上 schema 把 `pressed` 标为 boolean (`src/index.ts` L1092-1095)，但实际 MCP transport 在某些客户端会把 boolean 字符化为 JSON String `"false"`（具体见 L2）。

Godot 4 对 `var x: bool = <Variant>` 这种带静态类型注解的赋值做**严格类型检查**。当右侧 Variant 实际是 String `"false"` 时，不会隐式转换，直接报 Parse/Runtime Error "Trying to assign value of type 'String' to a variable of type 'bool'"。这与 Godot 3 的隐式转换不同，是 4.x 的有意设计。

**debug 模式下**该错误进一步通过 `debug_break()` 暂停主线程，与 `eval-lambda-capture-bug.md` 描述的"主线程 script reload 错误卡死游戏"是同一故障模式。

### L2 TS handler 不强制类型 coercion

`src/index.ts` L4632-4640 `handleGameKeyPress`：

```typescript
private async handleGameKeyPress(args: any) {
  args = args || {};
  if (!args.key && !args.action) return createErrorResponse('Must provide either "key" or "action" parameter.');
  const params: Record<string, any> = {};
  if (args.key) params.key = args.key;
  if (args.action) params.action = args.action;
  if (args.pressed !== undefined) params.pressed = args.pressed;
  return this.gameCommand('key_press', args, () => params);
}
```

`args.pressed` 透传不经类型校验。`CallToolRequestSchema` 处理函数把 `request.params.arguments` 原样喂给 handler（L3327-3329），不经过 zod 或类似 schema validate，所以 `args.pressed` 可以是任意类型。

通过对 `game_key_press` 工具时实测：MCP transport 曾把 boolean `false` 序列化为字符串 `"false"` 进入 GDScript Dictionary。原因不明（可能是某个 MCP 客户端 SDK 的 serde 缺陷，OpenCode 的 mcp 客户端或 stdio transport 强制 stringify），但好防御代码不该依赖 transport 行为。

## 复现步骤

1. 启动一个 Godot 项目（如 maze-explorer）   ```
   godot-mcp.run_project
   ```
2. 调用：
   ```
   godot-mcp.game_key_press({ action: "ui_accept", pressed: false })
   ```
3. 30 秒后超时；游戏进程陷入调试器 break 模式；`game_get_logs` 看到上述 SCRIPT ERROR。

## 影响范围

- `game_key_press` 在 `pressed: false` 路径下 100% 不可用
- `game_key_release` （从 TS 角度同名工具）实际上应该是单独的 `key_release`，但 GDScript 端只有 `_cmd_key_press`，没有 key_release 通道。这暗示 release 当前靠 `key_press(pressed: false)` 实现，意味着 release 路径整体 broken
- `game_key_hold` 内部是否走 `_cmd_key_press`？未读代码，需后续确认
- 任何依赖"释放按键"语义的自动化场景（如：长按移动后松开、双击间隔的 release 帧）全部 broken

## 修复方案（推荐）

双层加防御：

### Fix 1: GDScript `_cmd_key_press` 用 Variant + 显式 bool 转换

`src/scripts/mcp_interaction_server.gd` L510 起:

```gdscript
# 旧代码（坏）
func _cmd_key_press(params: Dictionary) -> void:
  var action: String = params.get("action", "")
  var key: String = params.get("key", "")
  var pressed: bool = params.get("pressed", true)  # ← 严格类型注解报错
  ...

# 新代码（推荐）
func _cmd_key_press(params: Dictionary) -> void:
  var action: String = params.get("action", "")
  var key: String = params.get("key", "")
  # 用 Variant 暂存 + 显式 bool() 转换避免严格类型注解直接 check
  var pressed_val: Variant = params.get("pressed", true)
  # String "false"/"true" → bool；其它类型走 bool() 内置
  var pressed: bool
  if pressed_val is String:
    pressed = (pressed_val.to_lower() == "true")
  else:
    pressed = bool(pressed_val)
  ...
```

同样的防御应铺遍所有 `var x: <primitive> = params.get(...)` 这种从 transport 输入解包的字段（至少：所有 `bool` 与 `int` 字段）。

### Fix 2: TS handler 强制类型 coercion

`src/index.ts` L4632 起：

```typescript
// 旧代码
if (args.pressed !== undefined) params.pressed = args.pressed;

// 新代码
if (args.pressed !== undefined) {
  // 强制 coercion：string "false"/"true" 或 boolean 都可入
  if (typeof args.pressed === 'string') {
    params.pressed = args.pressed.toLowerCase() === 'true';
  } else {
    params.pressed = Boolean(args.pressed);
  }
}
```

### Fix 3 (可选): 在 `gameCommand` 入口加 schema validate

更宏大的修复是给 `gameCommand` 接入 zod schema validation。156 个 tool 都各加一个 schema 工程量大，但能根除一类 transport-is-coercing-types 的 bug。

## 与既有 bug 的关系

| 既有 bug | 共同模式 |
|---|---|
| `eval-lambda-capture-bug.md` 第一段 | 主线程 GDScript 错误 → 调试器 break → 全局卡死 |
| `eval-lambda-capture-bug.md` 第二段 (eval 编译错误) | 同上 |
| **本次** | 同上 |

模式已稳定：**任何 _cmd_* 在主线程抛 GDScript 错误都会 debug-break 整个游戏**，MCP 永远无法恢复。架构层修复对策（参考 `eval-lambda-capture-bug.md` 第二段已尝试的）：

- 把 `_cmd_*` dispatcher 在 Thread 子线程跑，编译/类型错误降级为返回值
- 或者：包一层 try-catch + 在 `_send_response` 失败时 emit error 不站主线程 ptr

当前架构 `_poll_connection` 是 `_send_response` 的同步调用者，所以 _cmd_* 报错前必然已进入 debug break。子线程化是更彻底的方案，可作为 next iteration 的大重构项。

## 短期缓解

在 Fix 1+2 上线前：

- 使用 `game_key_hold` + `game_key_release`（如果 key_release 独立，需查证）替代 `game_key_press({pressed: false})`
- 或：调用方一直传 `pressed: true`，跳过 release 场景
- 或：用 `game_eval` 直接 `Input.action_release("ui_accept")` 绕过 `_cmd_key_press`

## 教训

1. **GDScript 4 的静态类型注解 = 严格 type check，不做隐式转换**。任何 `var x: T = <external Variant>` 都假设 transport 已正确类型化，否则会 nil→报错。
2. **MCP transport 的类型契约不可信**。所有从 `params` Dictionary 解包的值需要先用 Variant 接住，再容错转换。
3. **主线程的 GDScript 错误是炸弹**。任何能在主线程抛错的 `_cmd_*` 都可能整局卡死，不该只在具体场景修，应全 dispatch 路径加防御。