# 共享目录协作规范
## 开始与写入
1. 读取 AGENTS.md、职责、PRD、看板和最新交接，写 READ_ACK（列出路径）。
2. PM 在看板分配任务 ID 和排他可写路径。开始前检查该范围的现有文件，发现别人改动则暂停该文件并报告。
3. 不同文件且无依赖可并行；同文件、契约变更、数据库迁移和集成环境变更串行。共享配置、依赖锁文件由 PM 指定唯一写者。
4. 每人只写自己的日志 docs/logs/{pm,backend,qa,ui,coordinator}.md，避免争抢一个总日志。时间统一 ISO 8601 含 +08:00，记录真实系统时间。
5. START/UPDATE/HANDOFF/END 记录：时间、角色、任务 ID、读写路径、操作、验证、阻塞、接收方。中断时记录剩余工作。
6. 日志只是审计；PM 文件授权才是排他规则。外部模型必须先获得分配；无法联系时可读但不抢写。陈旧占用必须由 PM 核实后释放。

## 交接与状态
状态：TODO → READY → IN_PROGRESS → READY_FOR_QA → QA_IN_PROGRESS → DONE。
失败：QA_IN_PROGRESS → CHANGES_REQUESTED → IN_PROGRESS。等待用户或环境则 BLOCKED，写明原因和恢复条件。
独立交接文件 docs/handoffs/{任务ID}-{角色}-{序号}.md：时间、发送/接收角色、基线/契约版本、变更路径、完成事项、验证命令与实际结果、未测项、已知限制、下一步、释放的文件范围。
接收者记录 ACCEPTED；提测不是验收。PM 独占看板；其他角色以交接记录请求更新，不同时编辑看板。
后端完成 → QA 回归 → 缺陷回后端 → QA 复测 → PM 阶段收口。
外部前端由用户安排 → 用户通知完成 → PM 核对交接和契约 → QA 联调 → 按归属修复 → QA 复测。
无代码、设备或 Provider 凭据时标记 NOT_RUN/BLOCKED，不用模拟结果替代真实测试。

## M0 文件授权
PM：docs/project/**、docs/product/ 下新增规划文件、docs/logs/pm.md。
后端：docs/backend/**、docs/logs/backend.md。
QA：docs/qa/**、docs/logs/qa.md。
各角色可新增属于自己任务的唯一交接文件。根规范和角色文件当前由主协调者维护。
