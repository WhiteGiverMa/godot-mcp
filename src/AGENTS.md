# src/ — 源码架构

## OVERVIEW
TypeScript MCP 服务器主入口 + GDScript 运行时/autoload 脚本。双语言通过 TCP 桥接。

## STRUCTURE
```
src/
├── index.ts                          # GodotServer 类 + 156 工具 + 156 handle 方法（6860 行）
├── utils.ts                          # 纯工具函数（318 行）
└── scripts/
    ├── mcp_interaction_server.gd     # 运行时 TCP autoload（4195 行）
    └── godot_operations.gd           # Headless 操作执行器（1707 行）
```

## WHERE TO LOOK

| 做什么 | 位置 | 行号区间 |
|-------|------|---------|
| 工具声明（JSON Schema） | `index.ts` `ListToolsRequestSchema` handler | ~1000-3500 |
| 工具 case 分发 | `index.ts` `CallToolRequestSchema` handler 的 `match command` | ~3300-3650 |
| handle 方法 | `index.ts` `private async handleXxx` | ~3670-6860 |
| TCP 连接管理 | `index.ts` `GodotServer.gameCommand` | ~3500-3670 |
| Variant ↔ JSON | `mcp_interaction_server.gd` `_variant_to_json` / `_json_to_variant` | ~950-1160 |
| eval 实现 | `mcp_interaction_server.gd` `_cmd_eval` + `_indent_code` | ~658-744 |
| 命令分发 | `mcp_interaction_server.gd` `_handle_command` match | ~220-280 |
| Headless 操作 | `godot_operations.gd` main switch | ~100-1707 |

## Conventions

### 新增 MCP 工具三步
1. **声明**：`index.ts` tools 数组加 `{ name: 'game_xxx', description: '≤80字符', inputSchema: {...} }`
2. **分发**：`index.ts` match 加 `case 'game_xxx': return await this.handleGameXxx(args);`
3. **handle**：`index.ts` 加 `private async handleGameXxx(args: any) { args = normalizeParameters(args||{}); ... return this.gameCommand('xxx', args, a => ({...})); }`

### handle 方法模式
- `normalizeParameters(args || {})` 开头
- 必填参数校验：`if (!args.xxx) return createErrorResponse('xxx is required.');`
- runtime 工具：`return this.gameCommand('snake_case_command', args, a => ({ snake_case: a.camelCase }));`
- headless 工具：`return this.runHeadlessOperation('op_name', {...});`

### GDScript 命令处理
- `_cmd_xxx(params: Dictionary)` 函数对应每个 runtime 命令
- `_send_response({...})` 返回结果
- `_variant_to_json(value)` 序列化 Godot 类型为 JSON

## ANTI-PATTERNS

- **禁止** handle 方法不做 `normalizeParameters` — MCP 客户端可能传不同大小写
- **禁止** 工具描述超 80 字符 — `tool-definitions.test.ts` 强制
- **禁止** GDScript 主线程 `script.reload()` 编译用户代码 — debug 模式触发调试器 break
- **禁止** GDScript lambda 内赋值捕获的局部标量 — 只读副本，用 Dictionary 容器
