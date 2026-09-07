# StudyOS

面向 iPad 的原生文档学习工具。用户主动阅读，AI 按需帮助理解，随后回到原文。

当前阶段：M0 项目启动与方案准备，尚无可运行 App。

## 所有人开始前

先读 [AGENTS.md](AGENTS.md)，再读自己的职责文件并记录 READ_ACK。外部 Claude 也可从 [CLAUDE.md](CLAUDE.md) 进入。

| 岗位 | 代号 | 职责文件 |
|---|---|---|
| 项目经理 | Claude1 | [PM](docs/roles/Claude1-PM.md) |
| UI 总监／外部前端 | Claude2 | [UI](docs/roles/Claude2-UI.md) |
| 项目后端／本地核心服务 | Codex1 | [Backend](docs/roles/Codex1-Backend.md) |
| 项目测试 | Codex2 | [QA](docs/roles/Codex2-QA.md) |

三个子 agent 对应项目经理、项目后端、项目测试；岗位代号不代表实际模型。前端由用户另行安排模型。

## 项目资料

- [完整 PRD 原文](docs/product/PRD-v0.1-source.md)
- [共享目录协作与交接](docs/collaboration/WORKFLOW.md)
- 项目看板：docs/project/BOARD.md，由 PM 独占维护。
- 技术提案：docs/backend/；验收资料：docs/qa/。
- 每人操作日志：docs/logs/；任务交接：docs/handoffs/。

并行以文件范围和依赖划分；同文件串行。后端提测后由 QA 独立回归；前端完成由用户通知后组织联调。

## 已确认与环境

2026-09-07 用户确认 iPad 原生 App，优先阅读和手写体验，并确认有 Mac 和 iPad 可配合后续构建测试。当前目录在 Windows，未检测到 Swift/Xcode 命令；原生编译、模拟器和 Apple Pencil 真机结果须在相应环境实际验证后记录。
