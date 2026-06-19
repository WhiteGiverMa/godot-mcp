# godot-mcp — 项目知识库

**Updated:** 2026-06-19
**Fork origin:** Coding-Solo/godot-mcp → tugcantopaloglu/godot-mcp → **WhiteGiverMa/godot-mcp**（2026-06 分家，垂直定制）
**Scale:** 156 MCP 工具 · TypeScript 6860 行 + GDScript 5902 行 · 426 测试

## Start

- 本文件是公共版。工作语言中文。代码注释中文。子代理调度中文。
- 本仓库已与上游 tugcantopaloglu 分家，不再跟踪 upstream。origin = `WhiteGiverMa/godot-mcp.git`。
- 改动 `src/` 后必须 `npm run build`；`build/scripts/*.gd` 是 GDScript 产物，通过 `scripts/sync-downstream.ps1` 同步到下游项目。
- 新增 MCP 工具三步：(1) `src/index.ts` 工具声明 + case 分发 + handle 方法 (2) 更新 `tests/tool-definitions.test.ts` 的 `ALL_TOOL_NAMES` 数组 (3) 更新 `tests/handlers.test.ts` 的 switch case 计数断言。

## Map

```
godot-mcp/
├── src/
│   ├── index.ts                    # MCP 服务器主入口：GodotServer 类 + 156 工具声明 + 156 handle 方法
│   ├── utils.ts                    # 纯工具函数（参数映射、路径校验、错误响应、版本检测）
│   └── scripts/
│       ├── mcp_interaction_server.gd  # Godot 运行时 TCP autoload（4195 行，监听 127.0.0.1:9090）
│       └── godot_operations.gd        # Headless GDScript 操作执行器（场景/资源/项目设置）
├── tests/                          # Vitest 426 测试
│   ├── utils.test.ts               # 31 测试 — 参数映射、路径校验、错误响应
│   ├── tool-definitions.test.ts    # 159 测试 — 全部 156 工具声明校验、schema 合法性、描述长度
│   └── handlers.test.ts            # 236 测试 — handle 方法参数转换、必填校验、headless 路径
├── docs/
│   ├── eval-lambda-capture-bug.md  # GDScript lambda 捕获只读副本 bug 根因 + 修复记录
│   └── upstream-sync.md            # 上游同步工作流（分家后仅作历史参考）
├── scripts/
│   ├── build.js                    # tsc 后复制 GDScript 到 build/scripts
│   └── sync-downstream.ps1         # 同步 build/scripts/*.gd 到下游项目 addons/godot_mcp
├── build/                          # tsc 产物 + GDScript 副本（gitignored）
├── package.json                    # @whitemagiverma/godot-mcp（分家后改名）
├── server.json                     # MCP server registry metadata
├── tsconfig.json                   # ES2022 + ESNext + strict
└── vitest.config.ts                # Vitest 配置
```

## WHERE TO LOOK

| 做什么 | 位置 | 注意 |
|-------|------|------|
| 新增 MCP 工具 | `src/index.ts` | 工具声明在 `ListToolsRequestSchema` handler 的 tools 数组；case 分发在 `CallToolRequestSchema` handler 的 match；handle 方法是 `private async handleXxx` |
| 改运行时 TCP 协议 | `src/scripts/mcp_interaction_server.gd` | GDScript autoload，`_cmd_*` 函数对应每个 runtime 命令 |
| 改 headless 操作 | `src/scripts/godot_operations.gd` | `--headless --script` 模式执行 |
| 参数转换/校验 | `src/utils.ts` | `PARAMETER_MAPPINGS`、`normalizeParameters`、`validatePath` |
| 测试新工具 | `tests/tool-definitions.test.ts` + `tests/handlers.test.ts` | 必须更新 `ALL_TOOL_NAMES` 数组 + switch case 计数断言 |
| Variant ↔ JSON 转换 | `mcp_interaction_server.gd` 的 `_variant_to_json` / `_json_to_variant` | GDScript 侧，覆盖 Vector2/3、Color、Transform、PackedArray |
| eval 实现 | `mcp_interaction_server.gd` 的 `_cmd_eval` | 子线程编译 + Dictionary 容器绕 lambda 捕获限制 |
| C# eval 路由 | `src/index.ts` 的 `handleGameEvalCsharp` | 路由到 `call_method` → `/root/EvalGateway`，GDScript 侧无改动 |
| 同步到下游项目 | `scripts/sync-downstream.ps1` | 复制 `build/scripts/*.gd` 到下游 `addons/godot_mcp/` |

## Architecture

### 双通道通信

1. **Headless CLI** — 不需要运行游戏：场景读写、资源创建、项目设置。`godot --headless --script godot_operations.gd <op> <json>`
2. **TCP Socket** — 运行时交互：`mcp_interaction_server.gd` autoload 监听 `127.0.0.1:9090`，TypeScript 服务器通过 `net.createConnection` 发送 JSON 命令

### 工具命名约定

- `game_*` — 运行时工具（需要游戏在跑）
- 无前缀 — headless 工具（`create_scene`、`read_scene`、`manage_*` 等）
- `game_eval_csharp` / `game_eval_csharp_snapshot` — C# 项目专用，路由到下游项目的 `EvalGateway` autoload

### GDScript 陷阱（已踩坑记录）

- **lambda 捕获只读副本**：GDScript lambda 捕获局部变量是只读副本，内部赋值不写回外部。用 Dictionary 引用类型容器绕过。见 `docs/eval-lambda-capture-bug.md`。
- **主线程编译错误卡死**：debug 模式下主线程 `GDScript.reload()` 编译错误触发调试器 break 暂停整个游戏。必须子线程编译。
- **缩进混合**：GDScript "Mixed use of tabs and spaces" 编译错误。`_indent_code` 统一用户代码缩进为 tab（4 空格 = 1 tab）。

## Conventions

### 命名/格式
- TypeScript：camelCase 方法，PascalCase 类/接口，工具名 snake_case（`game_get_property`）
- GDScript：snake_case 函数/变量，`_cmd_*` 命令处理函数
- 描述长度 ≤ 80 字符（测试强制）

### 测试
- 工具计数测试硬编码：`ALL_TOOL_NAMES` 数组 + `toBe(N)` 断言。新增工具必须同步更新两处。
- `handlers.test.ts` 用正则从源码提取 `case 'xxx':` 匹配数，断言与工具数一致。

### 构建
- `npm run build` = `tsc && node scripts/build.js`
- `build.js` 复制 `src/scripts/*.gd` 到 `build/scripts/`（tsc 不处理 .gd）
- `build/` gitignored，但 `build/index.js` 是 MCP 服务器入口（`package.json` bin）

## Commands

```bash
npm run build              # tsc + 复制 GDScript 到 build/scripts
npm test                   # vitest run（426 测试）
npm run test:watch         # vitest watch
npm run inspector          # MCP inspector 调试
./scripts/sync-downstream.ps1 [-SkipBuild]  # 同步到下游项目
```

## Anti-Patterns

- **禁止** 跳过测试更新就提交新工具 — `tool-definitions.test.ts` 和 `handlers.test.ts` 的计数断言必须同步
- **禁止** 工具描述超 80 字符 — 测试强制
- **禁止** 在 `mcp_interaction_server.gd` 主线程编译用户 GDScript — debug 模式会触发调试器 break
- **禁止** 在 GDScript lambda 内直接赋值捕获的局部标量 — 只读副本，不写回外部
- **禁止** 直接修改 `build/` 产物 — 改 `src/` 后 `npm run build`

## Unique Styles

- **双语言架构**：TypeScript MCP 服务器 + GDScript 运行时 autoload，通过 TCP 桥接
- **工具声明即文档**：每个工具的 `inputSchema` 是 JSON Schema，测试验证 schema 合法性
- **C# eval 间接路由**：`game_eval_csharp` 不在 GDScript 侧实现，而是路由到 `call_method` → 下游项目的 `EvalGateway` autoload，GDScript 侧零改动
- **子线程编译**：GDScript 动态编译用户代码必须在 `Thread` 子线程执行，避免主线程调试器 break
- **分家后垂直定制**：不再追上游，面向 WhiteGiverMa 的三个 Godot C# 项目（odyssey-cards、operation-taklamakan、dreamer-heroines）定向优化

## State

- ✅ 156 MCP 工具（含 `game_eval_csharp` + `game_eval_csharp_snapshot`）
- ✅ 426 测试全绿
- ✅ eval 超时 + 编译卡死两个 bug 已修（2026-06-18）
- ✅ 2026-06-19 分家：移除 upstream remote，origin 更新到 `WhiteGiverMa/godot-mcp.git`
- ⚠️ `package.json` 的 `name` 仍为 `@tugcantopaloglu/godot-mcp`，待改名
- ⚠️ `server.json` 的 `name` 仍为 `io.github.tugcantopaloglu/godot-mcp`，待改名

## 子目录规则

- `src/AGENTS.md`：源码架构、工具声明模式、handle 方法约定
- `tests/AGENTS.md`：测试结构、计数断言维护、新增工具测试 checklist
