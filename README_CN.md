# godot-mcp

[![MCP Server](https://badge.mcpx.dev?type=server)](https://modelcontextprotocol.io/introduction)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://godotengine.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **中文**

一个面向 Godot 游戏引擎的 [Model Context Protocol](https://modelcontextprotocol.io/introduction) 服务器。**156 个工具**，覆盖运行时交互、无头场景操作、项目管理、3D/2D 渲染、UI 控件、音频、动画、物理、网络和 C# 求值。

派生自 [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)（经 [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)），现独立维护，专注于 C# Godot 项目。

## 功能

### 运行时交互（game_* 工具）
- **代码执行**：`game_eval`（GDScript）、`game_eval_csharp` + `game_eval_csharp_snapshot`（C# 经 EvalGateway）
- **节点检查**：`game_get_property`、`game_set_property`、`game_call_method`、`game_get_node_info`、`game_get_scene_tree`
- **输入注入**：`game_click`、`game_key_press`、`game_key_hold`、`game_mouse_drag`、`game_touch`、`game_gamepad`
- **信号系统**：`game_connect_signal`、`game_emit_signal`、`game_await_signal`
- **动画**：`game_play_animation`、`game_tween_property`、`game_animation_tree`、`game_create_animation`
- **调试**：`game_get_logs`、`game_get_errors`、`game_performance`、`game_screenshot`、`game_pause`
- **3D/2D**：灯光、网格、CSG、粒子、画布、物理、射线、导航、瓦片地图
- **UI**：文本控件、弹窗、树、菜单、标签页、滑块、主题
- **音频**：播放、总线控制、效果、空间化
- **网络**：HTTP、WebSocket、ENet 多人、RPC
- **系统**：窗口、OS 信息、时间缩放、语言环境、视口

### 无头操作（不需要运行游戏）
- **场景 I/O**：`read_scene`、`modify_scene_node`、`remove_scene_node`、`create_scene`、`add_node`、`save_scene`
- **项目**：`read_project_settings`、`modify_project_settings`、`manage_autoloads`、`manage_input_map`、`manage_export_presets`
- **文件**：`read_file`、`write_file`、`delete_file`、`create_directory`、`list_project_files`
- **资源**：`create_resource`、`manage_resource`、`manage_shader`、`manage_theme_resource`
- **脚本**：`create_script`、`attach_script`、`manage_scene_signals`

### C# 求值（game_eval_csharp）
对于 C# Godot 项目，`game_eval_csharp` 和 `game_eval_csharp_snapshot` 通过目标项目的 `EvalGateway` autoload 求值 C# 路径表达式并获取结构化快照。这解决了 GDScript `game_eval` 无法访问 C# 静态成员、纯 C# 类（Hero/Minion/Board）、`List<T>` 和枚举的限制。需要下游项目实现一个 `EvalGateway` autoload，提供 `Eval(string path)` 和 `GetSnapshot(string kind)` 方法。

## 环境要求

- [Godot 引擎](https://godotengine.org/download) 4.x（4.4+ 支持 UID 功能）
- [Node.js](https://nodejs.org/) >= 18.0.0
- 支持 MCP 的 AI 助手（Claude Code、Cline、Cursor、OpenCode 等）

## 安装

```bash
git clone https://github.com/WhiteGiverMa/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

## 配置

### Claude Code / OpenCode

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/godot-mcp/build/index.js 的绝对路径"],
      "environment": {
        "GODOT_PATH": "/godot 可执行文件路径",
        "GODOT_PROJECT_PATH": "/你的 godot 项目路径"
      }
    }
  }
}
```

### Cline (VS Code)

添加到 `cline_mcp_settings.json`：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/godot-mcp/build/index.js 的绝对路径"]
    }
  }
}
```

### Cursor

创建 `.cursor/mcp.json`：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/godot-mcp/build/index.js 的绝对路径"]
    }
  }
}
```

## 运行时工具设置

要使用 `game_*` 运行时工具，你的 Godot 项目需要 MCP 交互服务器 autoload：

1. 将 `build/scripts/mcp_interaction_server.gd` 复制到你的项目
2. 在 Godot 中：**项目 > 项目设置 > Autoload**
3. 以 autoload 名 `McpInteractionServer` 添加该脚本

服务器监听 `127.0.0.1:9090`，在游戏运行时通过 TCP 接收 JSON 命令。

### C# 求值设置

要使用 `game_eval_csharp` / `game_eval_csharp_snapshot`，你的 C# Godot 项目需要一个 `EvalGateway` autoload，暴露：
- `Variant Eval(string pathExpr)` — 求值 C# 路径表达式
- `Variant GetSnapshot(string kind)` — 返回结构化快照（combat/player/enemy/board）

参考实现见 [odyssey-cards/Scripts/Infrastructure/EvalGateway.cs](https://github.com/WhiteGiverMa/odyssey-cards/blob/dev/Scripts/Infrastructure/EvalGateway.cs)。

## 环境变量

| 变量 | 说明 |
|------|------|
| `GODOT_PATH` | Godot 可执行文件路径（覆盖自动检测） |
| `GODOT_PROJECT_PATH` | 默认项目路径 |
| `DEBUG` | 设为 `"true"` 开启服务器端详细日志 |

## 架构

两个通信通道：

1. **无头 CLI** — 不需要运行游戏的场景/资源/项目操作。执行 `godot --headless --script godot_operations.gd <op> <json>`。
2. **TCP Socket** — 与运行中游戏的实时交互。`mcp_interaction_server.gd` autoload 监听 9090 端口，处理来自 TypeScript MCP 服务器的 JSON 命令。

### 源码结构

| 路径 | 说明 |
|------|------|
| `src/index.ts` | MCP 服务器、156 个工具定义、156 个处理器 |
| `src/utils.ts` | 纯工具函数（参数映射、校验） |
| `src/scripts/mcp_interaction_server.gd` | 运行时 TCP 交互服务器 autoload |
| `src/scripts/godot_operations.gd` | 无头 GDScript 操作执行器 |
| `tests/` | Vitest 测试套件（426 个测试） |

## 测试

```bash
npm test            # 运行一次
npm run test:watch  # 监视模式
```

| 文件 | 测试数 | 覆盖范围 |
|------|--------|----------|
| `tests/utils.test.ts` | 31 | 参数映射、路径校验、错误响应 |
| `tests/tool-definitions.test.ts` | 159 | 全部 156 工具声明、schema 合法性、描述 ≤ 80 字符 |
| `tests/handlers.test.ts` | 236 | 处理器参数转换、必填校验、switch 完整性 |

## 开发

```bash
npm run build       # tsc + 复制 GDScript 到 build/scripts
npm run watch       # tsc --watch
npm run inspector   # MCP inspector 调试
```

### 下游同步

`scripts/sync-downstream.ps1` 将 `build/scripts/*.gd` 同步到下游 Godot 项目：

```powershell
./scripts/sync-downstream.ps1           # 构建 + 同步
./scripts/sync-downstream.ps1 -SkipBuild # 仅同步
```

## 示例提示词

```text
"运行我的 Godot 项目并检查错误"
"获取运行游戏中玩家的位置"
"将玩家生命值设为 100"
"读取 test_level.tscn 场景并显示节点树"
"求值这个 C# 路径：CombatManager.PlayerHero.CurrentHealth"
"从运行中的 C# 游戏获取战斗快照"
"将敌人的 'died' 信号连接到游戏管理器的 'on_enemy_died' 方法"
"用 ease-out 在 2 秒内将相机位置补间到 (0, 10, -5)"
"获取性能指标——我的 FPS 和绘制调用数是多少？"
"暂停游戏并截图"
"创建一个名为 'MyGame' 的新 Godot 项目并编写玩家脚本"
```

## 致谢

- **原始项目**：[godot-mcp](https://github.com/Coding-Solo/godot-mcp) 作者 Solomon Elias (Coding-Solo)
- **扩展 fork**：[tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) 作者 Tugcan Topaloglu — 扩展至 149 个工具
- **当前维护者**：[WhiteGiverMa](https://github.com/WhiteGiverMa) — 2026-06 派生，新增 C# 求值工具，独立维护，面向 C# Godot 项目垂直领域

## 许可证

MIT 许可证 — 见 [LICENSE](LICENSE)。

Copyright (c) 2026 马戈 (WhiteGiverMa)
