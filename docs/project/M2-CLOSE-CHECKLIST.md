# M2 收口检查表与任务编排

审计基线：main@4f7b9a9c566f027bb67d9bf45069f957c1c1a536。本轮核对源码清单、提交记录与七份M2交接；未在Windows编译运行。开发交付已进入仓库，M2尚未验收关闭。主协调者已将AIService上下文丢失与伪SHA256摘要问题交后端修复；须等待修复基线的新CI及QA证据。

## 已交付与证据边界

| 范围 | 现有证据 | 结论 |
|---|---|---|
| 后端 | 5e7c72f服务/协议、b051da9并发捕获修复、4f7b9a9上下文覆盖与取消修复；BE/BE-FIX/BE-FIX2交接 | 已交付，存在本轮待修缺口，不是DONE |
| UI | ReaderViewModel、AISidebarView、SelectionCalloutMenu及M2-UI-ui-001 | 已交付待联调；接口存在不证明完整阅读/AI路径可用 |
| 测试源码 | AIServiceTests中11个test方法，M2-QA-qa-001、M2-QA-FIX-qa-001 | 测试代码已交付，不能据用例数量推算执行PASS数 |
| 最新CI | .github/workflows/ci.yml配置macos-14并实际选择可用iPad模拟器，上传xcresult | 本轮尚未拿到4f7b9a9运行ID/结论；历史M1绿灯不覆盖M2 |
| 真机/真实Provider | 本轮无对应执行记录 | NOT_RUN；用户有Mac/iPad不等于验证完成 |

## 阶段关闭必须检查

- [ ] M2-FIX-CONTEXT：真实发送消息包含已确认的选区/页/章上下文，不能只传占位清单；未确认或清单变更不发送。后端修复、QA截获实际请求断言。
- [ ] M2-FIX-DIGEST：使用真实摘要并绑定实际发送内容，不能用带sha256字样的长度/非加密哈希冒充；QA检验内容变化、同长度不同内容及确认失效。
- [ ] M2-CI：记录最终修复commit SHA、run URL/ID、job、命令、实际Xcode/SDK/模拟器、成功失败跳过数及xcresult；核对任务确实执行而不是仅工作流绿色。
- [ ] M2-QA-REGRESSION：重跑上下文覆盖、流取消、Task取消、失败互斥、重复attempt、来源过滤、存储/跨会话回归；旧失败必须在新基线上复测。
- [ ] M2-SCOPE-AUDIT：逐项核对R01–R09、R14/R16/R17以及启动交接承诺，未实现与未验证分别登记，不能按“已全量完成”自述关闭。
- [ ] M2-PROVIDER：确认实际可配置Provider/Keychain与真实服务调用；本轮文件清单只有OpenAICompatibleProvider，CoreService默认apiKey为空，设置入口和Anthropic原生协议尚待核对。无需用户现在发密钥。
- [ ] M2-AI-QUALITY：六段结构、当前章节真实范围、文档不足回答、回答证据归属和引用定位由QA评估；不能用HTTP成功或自动附当前页当文档忠实性证据。
- [ ] M2-DEVICE：iPad/Pencil验证旋转裁切缩放、写擦/选择手势、保存重启、后台及删除；模拟器结果不能替代手写证据。
- [ ] M2-PM-CLOSE：缺陷关闭、范围差异处理与风险明确后再判M2 DONE；R10全文学习视图及其他P1依PLAN保留后续阶段，不静默删除。

本轮未找到StudyOSUITests目录，故启动计划中的UI端到端套件尚无目录证据；Provider级HTTP/SSE测试与MockLLMProvider业务流测试必须分开核对。这是待QA核实的覆盖缺口，不冒充已执行FAIL。

## 下一步任务与排他顺序

| ID | 负责人 | 依赖/状态 | 可写范围 | 完成条件 |
|---|---|---|---|---|
| M2-BE-FIX3 | Codex1 | 主协调者已派发；IN_PROGRESS | 原授权StudyOS/Core、Services、Models、Storage、Contracts及backend文档/日志 | 上下文与摘要修复，交接真实自测/未测项 |
| M2-QA-REGRESSION | Codex2 | QA_IN_PROGRESS；修复基线后执行 | StudyOSTests、StudyOSUITests、docs/qa、qa日志 | 新基线CI/回归与范围审计报告；失败回所属作者 |
| M2-UI-RECHECK | Claude2，用户外部路由 | READY_FOR_QA；依修复契约与QA发现 | 原授权UI、Views、Adapters、ViewModels及ui文档/日志 | 真实上下文/确认/配置/状态与引用链联调，必要修复由PM明确文件 |
| M2-DEVICE | QA协调用户 | TODO；可用构建就绪后 | QA设备证据目录，用户Mac/iPad运行 | 设备/系统/Pencil/构建SHA及操作结果齐全 |
| M2-CLOSE-PM | Claude1 | IN_PROGRESS；依上述证据 | docs/project、pm日志、自有唯一交接 | 更新状态和证据范围，不改产品或他人记录 |

代码修复与QA用例准备可在排他文件并行；契约变更先BE交接再UI/QA对齐；最新CI结果核对和真机验收串接于最终源码。工程配置仍由原指定单一写者Codex1负责，QA报告失败不能抢改共享配置。PM只新增自己的handoff，不能独占整个docs/handoffs目录。

## 临时UI路由与全文范围阻塞

- [ ] M2-FULL-SCOPE：当前全文scope unsupported是M2收口阻塞。QA复现并记录入口/错误，BE/UI提供可用实现或PM明确范围处置并保持R10 P0后续交付；不得把unsupported当成功或静默消除整文需求。
- [ ] M2-UI-CONTEXT-MIGRATION：BE/QA交接落盘后，主协调者临时独占ReaderViewModel.swift完成两处pageTexts→同一AggregatedContext→确认manifest→generateStream迁移。授权/冲突检查/关闭条件见docs/handoffs/M2-UI-CONTEXT-ROUTE-pm-001.md；其余UI文件仍Claude2独占。

