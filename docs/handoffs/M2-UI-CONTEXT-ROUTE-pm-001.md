# M2 UI 上下文调用临时路由授权

时间：2026-09-08T08:39:20.3268244+08:00。PM Claude1 → 主协调者；任务M2-UI-CONTEXT-MIGRATION。

决定：授权主协调者在BE新接口与QA用例交接落盘并读取后，临时独占 StudyOS/ViewModels/ReaderViewModel.swift，完成两处最小上下文调用迁移。此为M2既有功能修复的排他重新分配，不改变Claude2整体UI职责。

占用核实：M2-UI-ui-001已声明实施交付并转QA；主协调者确认Claude2当前为外部角色不可调度。本轮git status对该文件无未提交修改，因此本次核实释放该文件旧任务占用。开工前再检查文件状态/时间，若出现外部新修改立即暂停冲突文件并报PM；不能覆盖。授权期间Claude2不得同时编辑该文件，交接中向外部角色说明。

依赖：Codex1完成新AggregatedContext/generateStream接口与正文传输修复，QA完成对应测试迁移和交接；两者落盘后主协调者记录READ_ACK/ACCEPTED再编辑。QA测试执行不以此授权宣称通过。

唯一产品可写文件：StudyOS/ViewModels/ReaderViewModel.swift。审计只写主协调者自己的日志及唯一handoff。不能改其他UI视图、后端契约/实现、测试或工程配置；确需新增路径时向PM报告实际必要范围。

具体任务：askAI和generateStudyGuide两处先读取当前固定文档/版本范围的实际pageTexts，构建同一不可变AggregatedContext；呈现并确认context.manifest，随后将同一个context传入新generateStream。禁止确认后重建/换范围/换Provider，不能只传空pageTexts或元数据占位。保持取消/失败与会话防污染约束；新接口unsupported范围如实提示，不伪造成功。

关闭条件：QA截获请求核对真实选区/页/章文本与展示清单一致，未确认不发送、确认内容变化失效；最终修复SHA的CI与回归记录齐全。完成后主协调者交接修改、实际验证/未测项及释放该文件，PM恢复常规Claude2所有权。

全文scope当前unsupported另列M2收口阻塞，不能以本次最小UI迁移覆盖或关闭；须实现或明确阶段范围处置，R10 P0始终保留。当前阶段CHANGES_REQUESTED/QA_IN_PROGRESS。
