# StudyOS 协作入口
所有模型在每次开始任务、恢复任务、接手任务前，必须先阅读本文件、自己的职责文件、docs/collaboration/WORKFLOW.md、docs/project/BOARD.md（存在时）及任务交接记录。先记录 READ_ACK 再工作。
角色代号不代表实际运行模型。主协调者负责当前会话路由；项目经理负责需求、排期和验收统筹。
- 项目经理 / Claude1：docs/roles/Claude1-PM.md
- UI 总监 / Claude2（用户外部安排）：docs/roles/Claude2-UI.md
- 项目后端 / Codex1：docs/roles/Codex1-Backend.md
- 项目测试 / Codex2：docs/roles/Codex2-QA.md

产品基线：docs/product/PRD-v0.1-source.md。不得自行缩减 P0；用户已确认 iPad 原生 App，优先阅读与手写体验。
同一共享目录按文件所有权排他写入，不覆盖他人修改。日志不能替代文件排他。不得擅自 reset、清理、stash、切分支或提交他人文件。
首阶段为 M0：需求拆解、技术方案、验收准备。原生平台已确认；先完成可审阅的架构与接口方案，再进入产品代码实施。
