# tests/ — 测试结构

## OVERVIEW
Vitest 426 测试，3 文件。测试工具计数和 schema 合法性是核心保障。

## STRUCTURE
```
tests/
├── utils.test.ts              # 31 测试 — 参数映射、路径校验、错误响应、版本检测
├── tool-definitions.test.ts   # 159 测试 — 全部 156 工具声明校验
└── handlers.test.ts           # 236 测试 — handle 方法参数转换、必填校验、headless 路径
```

## WHERE TO LOOK

| 做什么 | 位置 |
|-------|------|
| 新增工具后更新计数 | `tool-definitions.test.ts` 的 `ALL_TOOL_NAMES` 数组 + `handlers.test.ts` 的 `toBe(N)` 断言 |
| 工具描述长度校验 | `tool-definitions.test.ts` `no tool description exceeds 80 characters` |
| handle 方法参数转换测试 | `handlers.test.ts` `Game command handlers` describe 块 |
| switch case 完整性 | `handlers.test.ts` `Tool dispatch switch statement` |

## Conventions

### 新增工具测试 checklist
1. `tool-definitions.test.ts`：`ALL_TOOL_NAMES` 数组加工具名
2. `tool-definitions.test.ts`：更新 `defines exactly N tools` 的 `toHaveLength(N)` + `toBe(N)`
3. `handlers.test.ts`：更新 `every case returns await this.handle*` 的 `toBe(N)` 注释和断言
4. `handlers.test.ts`：加 `handleGameXxx` 参数转换测试（参照现有 `handleGameClick` 模式）

### 计数断言位置
- `tool-definitions.test.ts:74` — `defines exactly 156 tools` → `toHaveLength(156)`
- `handlers.test.ts:1945` — `every case returns await this.handle*` → `toBe(156)`

## ANTI-PATTERNS

- **禁止** 新增工具不更新计数断言 — 测试会失败，CI 会挂
- **禁止** 删除测试来通过 — 修源码或修断言
- **禁止** 工具描述超 80 字符 — `tool-definitions.test.ts:122` 强制
