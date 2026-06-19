# godot-mcp

**English** | [中文](README_CN.md)

[![MCP Server](https://badge.mcpx.dev?type=server)](https://modelcontextprotocol.io/introduction)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://godotengine.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

A [Model Context Protocol](https://modelcontextprotocol.io/introduction) server for the Godot game engine. **156 tools** spanning runtime interaction, headless scene operations, project management, 3D/2D rendering, UI controls, audio, animation, physics, networking, and C# eval.

Forked from [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) (via [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)), now independently maintained with a focus on C# Godot projects.

## Features

### Runtime Interaction (game_* tools)
- **Code execution**: `game_eval` (GDScript), `game_eval_csharp` + `game_eval_csharp_snapshot` (C# via EvalGateway)
- **Node inspection**: `game_get_property`, `game_set_property`, `game_call_method`, `game_get_node_info`, `game_get_scene_tree`
- **Input injection**: `game_click`, `game_key_press`, `game_key_hold`, `game_mouse_drag`, `game_touch`, `game_gamepad`
- **Signals**: `game_connect_signal`, `game_emit_signal`, `game_await_signal`
- **Animation**: `game_play_animation`, `game_tween_property`, `game_animation_tree`, `game_create_animation`
- **Debug**: `game_get_logs`, `game_get_errors`, `game_performance`, `game_screenshot`, `game_pause`
- **3D/2D**: lights, meshes, CSG, particles, canvas, physics, raycasts, navigation, tilemap
- **UI**: text controls, popups, trees, menus, tabs, ranges, themes
- **Audio**: playback, bus control, effects, spatial
- **Networking**: HTTP, WebSocket, ENet multiplayer, RPC
- **System**: window, OS info, time scale, locale, viewport

### Headless Operations (no running game needed)
- **Scene I/O**: `read_scene`, `modify_scene_node`, `remove_scene_node`, `create_scene`, `add_node`, `save_scene`
- **Project**: `read_project_settings`, `modify_project_settings`, `manage_autoloads`, `manage_input_map`, `manage_export_presets`
- **Files**: `read_file`, `write_file`, `delete_file`, `create_directory`, `list_project_files`
- **Resources**: `create_resource`, `manage_resource`, `manage_shader`, `manage_theme_resource`
- **Scripts**: `create_script`, `attach_script`, `manage_scene_signals`

### C# Eval (game_eval_csharp)
For C# Godot projects, `game_eval_csharp` and `game_eval_csharp_snapshot` route through the target project's `EvalGateway` autoload to evaluate C# path expressions and get structured snapshots. This solves the GDScript `game_eval` limitation where C# static members, pure C# classes (Hero/Minion/Board), `List<T>`, and enums are inaccessible. Requires the downstream project to implement an `EvalGateway` autoload with `Eval(string path)` and `GetSnapshot(string kind)` methods.

## Requirements

- [Godot Engine](https://godotengine.org/download) 4.x (4.4+ for UID features)
- [Node.js](https://nodejs.org/) >= 18.0.0
- An MCP-compatible AI assistant (Claude Code, Cline, Cursor, OpenCode, etc.)

## Installation

```bash
git clone https://github.com/WhiteGiverMa/godot-mcp.git
cd godot-mcp
npm install
npm run build
```

## Configuration

### Claude Code / OpenCode

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/godot-mcp/build/index.js"],
      "environment": {
        "GODOT_PATH": "/path/to/godot",
        "GODOT_PROJECT_PATH": "/path/to/your/godot/project"
      }
    }
  }
}
```

### Cline (VS Code)

Add to `cline_mcp_settings.json`:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/godot-mcp/build/index.js"]
    }
  }
}
```

### Cursor

Create `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/godot-mcp/build/index.js"]
    }
  }
}
```

## Runtime Tools Setup

To use `game_*` runtime tools, your Godot project needs the MCP interaction server autoload:

1. Copy `build/scripts/mcp_interaction_server.gd` to your project
2. In Godot: **Project > Project Settings > Autoload**
3. Add the script with autoload name `McpInteractionServer`

The server listens on `127.0.0.1:9090` and accepts JSON commands over TCP when the game is running.

### C# Eval Setup

For `game_eval_csharp` / `game_eval_csharp_snapshot`, your C# Godot project needs an `EvalGateway` autoload exposing:
- `Variant Eval(string pathExpr)` — evaluate a C# path expression
- `Variant GetSnapshot(string kind)` — return a structured snapshot (combat/player/enemy/board)

See [odyssey-cards/Scripts/Infrastructure/EvalGateway.cs](https://github.com/WhiteGiverMa/odyssey-cards/blob/dev/Scripts/Infrastructure/EvalGateway.cs) for a reference implementation.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GODOT_PATH` | Path to the Godot executable (overrides auto-detection) |
| `GODOT_PROJECT_PATH` | Default project path for operations |
| `DEBUG` | Set to `"true"` for detailed server-side logging |

## Architecture

Two communication channels:

1. **Headless CLI** — scene/resource/project operations without a running game. Runs `godot --headless --script godot_operations.gd <op> <json>`.
2. **TCP Socket** — runtime interaction with a running game. `mcp_interaction_server.gd` autoload listens on port 9090, processes JSON commands from the TypeScript MCP server.

### Source Layout

| Path | Description |
|------|-------------|
| `src/index.ts` | MCP server, 156 tool definitions, 156 handlers |
| `src/utils.ts` | Pure utility functions (parameter mapping, validation) |
| `src/scripts/mcp_interaction_server.gd` | Runtime TCP interaction server autoload |
| `src/scripts/godot_operations.gd` | Headless GDScript operations runner |
| `tests/` | Vitest test suite (426 tests) |

## Testing

```bash
npm test            # run once
npm run test:watch  # watch mode
```

| File | Tests | Coverage |
|------|-------|----------|
| `tests/utils.test.ts` | 31 | Parameter mappings, path validation, error responses |
| `tests/tool-definitions.test.ts` | 159 | All 156 tools defined, schemas valid, descriptions ≤ 80 chars |
| `tests/handlers.test.ts` | 236 | Handler arg transforms, required-param validation, switch completeness |

## Development

```bash
npm run build       # tsc + copy GDScript to build/scripts
npm run watch       # tsc --watch
npm run inspector   # MCP inspector debugging
```

### Downstream Sync

`scripts/sync-downstream.ps1` copies `build/scripts/*.gd` to downstream Godot projects:

```powershell
./scripts/sync-downstream.ps1           # build + sync
./scripts/sync-downstream.ps1 -SkipBuild # sync only
```

## Example Prompts

```text
"Run my Godot project and check for errors"
"Get the player's position in the running game"
"Set the player's health to 100"
"Read the test_level.tscn scene and show me the node tree"
"Eval this C# path: CombatManager.PlayerHero.CurrentHealth"
"Get a combat snapshot from the running C# game"
"Connect the enemy's 'died' signal to the game manager's 'on_enemy_died' method"
"Tween the camera's position to (0, 10, -5) over 2 seconds with ease-out"
"Get performance metrics - what's my FPS and draw call count?"
"Pause the game and take a screenshot"
"Create a new Godot project called 'MyGame' and write a player script"
```

## Credits

- **Original project**: [godot-mcp](https://github.com/Coding-Solo/godot-mcp) by Solomon Elias (Coding-Solo)
- **Extended fork**: [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) by Tugcan Topaloglu — extended to 149 tools
- **Current maintainer**: [WhiteGiverMa](https://github.com/WhiteGiverMa) — forked 2026-06, added C# eval tools, independently maintained for C# Godot project verticals

## License

MIT License — see [LICENSE](LICENSE).

Copyright (c) 2026 马戈 (WhiteGiverMa)
