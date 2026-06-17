# Eval 超时根因：GDScript lambda 捕获只读副本

**发现日期：** 2026-06-18
**修复提交：** `21b9c54` fix: eval 超时 — GDScript lambda 捕获局部变量为只读副本

## 现象

`game_eval` 工具几乎 100% 超时（28s），无论用户代码多简单。`return 42` 都超时。

## 根因

`_cmd_eval` 用 lambda 包裹用户协程，通过 `__finished` 局部布尔变量通知 while 循环退出：

```gdscript
# 旧代码（坏）
func execute(timeout_seconds: float):
    var __result = null
    var __finished := false
    var __runner := func():
        __result = await _run()   # ← 赋值不写回外部
        __finished = true          # ← 赋值不写回外部
    __runner.call_deferred()
    while not __finished and ... < __deadline:
        await get_tree().process_frame
```

GDScript 的 lambda 捕获外部局部变量时，捕获的是**只读副本**。在 lambda 内部对捕获变量赋值不会修改外部的同名变量——Godot 会发出警告：

```
WARNING: Reassigning lambda capture does not modify the outer local variable "__result".
WARNING: Reassigning lambda capture does not modify the outer local variable "__finished".
```

因此 while 循环里的 `__finished` 永远是初始值 `false`，循环空转到 `__deadline`，28s 后超时返回 `{"__eval_timed_out": true}`。**与用户代码无关**——即使 `return 42` 这种零副作用代码也必然超时。

## 修复

用 Dictionary 引用类型作为可变容器绕过只读副本限制（Dictionary 是引用类型，lambda 内修改其内容会写回外部）：

```gdscript
# 新代码（修复后）
func execute(timeout_seconds: float):
    var __state := {"result": null, "finished": false}
    var __runner := func():
        __state["result"] = await _run()
        __state["finished"] = true
    __runner.call()
    while not __state["finished"] and ... < __deadline:
        await get_tree().process_frame
    if not __state["finished"]:
        return {"__eval_timed_out": true}
    return __state["result"]
```

同时将 `call_deferred()` 改为 `call()`：同步 `_run` 在当前栈完成，减少 idle 帧调度竞态。

## 验证

修复后 `return 42` 立即返回 `{"result": 42}`。

## 教训

GDScript lambda 捕获语义与 C# / JS / Python 不同：

| 语言 | lambda 捕获局部变量 | 修改写回外部？ |
|------|---------------------|---------------|
| C# | 闭包捕获变量本身 | ✅ 是 |
| JS | 闭包捕获变量绑定 | ✅ 是 |
| Python | 闭包捕获变量绑定 | ❌ 需 `nonlocal` |
| GDScript | lambda 捕获**只读副本** | ❌ 无法写回 |

**规则：** GDScript 中需要在 lambda 内修改外部状态时，必须用引用类型容器（Dictionary / Array / Object），不能直接捕获局部标量。

## 影响范围

此 bug 影响 `mcp_interaction_server.gd` 的 `_cmd_eval` 函数，即 `game_eval` MCP 工具。所有依赖 `game_eval` 的运行时诊断都会超时失败。其他 MCP 工具（`call_method`、`set_property`、`get_property` 等）不受影响，因为它们是同步的，不经过 lambda 协程机制。

---

# Eval 编译错误卡死游戏 — 调试器 break

**发现日期：** 2026-06-18
**修复提交：** `150731e` fix: eval 编译错误卡死游戏 — 子线程编译 + 缩进统一

## 现象

`game_eval` 用户代码有 GDScript 编译错误（如引用不存在的类、混用 tab/空格缩进）时，Godot 调试器 break，暂停整个游戏。Timer 驱动的 `_poll_connection` 停止轮询，后续所有 MCP 命令超时，只能手动重启游戏。

## 根因

`_cmd_eval` 在主线程调用 `GDScript.reload()` 编译用户代码。debug 模式下，GDScript 编译错误会触发 Godot 内置调试器的 `debug_break()`，暂停主线程执行。`McpInteractionServer` 的 `_poll_timer` 虽然设置了 `PROCESS_MODE_ALWAYS`，但调试器 break 暂停的是整个主线程，Timer 回调无法执行。

`EngineDebugger` 类在 GDScript 中没有 `set_active(false)` 或 `set_skip_breakpoints(true)` 的绑定（C++ 有但未暴露到 GDScript API），无法从 GDScript 侧禁用调试器 break。

## 修复

### 1. 子线程编译

将 `script.reload()` 移到 `Thread` 子线程执行。子线程的 GDScript 编译错误只返回错误码（如 `ERR_PARSE_ERROR = 43`），不触发主线程调试器 break：

```gdscript
var __compile_state := {"err": OK}
var __compile_thread := Thread.new()
var __compile_func := func():
    __compile_state["err"] = script.reload()
__compile_thread.start(__compile_func)
__compile_thread.wait_to_finish()
var err: int = __compile_state["err"]
if err != OK:
    _send_response({"error": "Failed to compile GDScript (error %d). Check syntax." % err})
    return
```

### 2. _indent_code 缩进统一

`_indent_code` 原来只在每行前加一个 tab，不处理用户代码本身的前导空格。当用户代码用空格缩进时，与外层 tab 缩进混合，触发 "Mixed use of tabs and spaces" 编译错误。

修复：逐行检测前导空格数，按 4 空格 = 1 tab 转换为 tab，保留行内空格不变。

## 验证

- `return NonExistentClass.foo()` → 返回 `error 43`，游戏继续正常运行
- `LineEdit.SignalName.text_submitted`（C# API 误用在 GDScript 中）→ 返回 `error 43`，游戏继续正常运行
- 空格缩进的代码 → 正常执行（缩进已自动转换）
- 正常代码 → 正常返回结果

## 教训

Godot 4 debug 模式下，主线程的 GDScript 编译错误是**致命的**——会触发调试器 break 暂停整个游戏，且无法从 GDScript 侧禁用。任何动态编译用户代码的场景都必须在子线程中进行，将编译错误降级为可处理的返回值。
