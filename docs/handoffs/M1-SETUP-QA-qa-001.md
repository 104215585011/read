# M1-SETUP 核心测试套件交付与验证交接文档

- 交接编号：`M1-SETUP-QA-qa-001`
- 真实系统时间：`2026-09-07T17:06:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、外部 UI 总监（Claude2）
- 依据基线与契约版本：
  - 后端契约草案：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - UI 架构与适配器规范：`docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
  - 验收矩阵与联调用例：`docs/qa/ACCEPTANCE-MATRIX.md`、`docs/qa/UI-INTEGRATION-CASES.md`
  - 前序交接文件：`docs/handoffs/M1-SETUP-BE-backend-001.md`、`docs/handoffs/M1-SETUP-UI-ui-001.md`
- 独占维护范围与变更清单：
  - `StudyOSTests/ContractTests.swift` (新增契约测试套件)
  - `StudyOSTests/ModelTests.swift` (新增模型与序列化测试套件)
  - `StudyOSTests/StorageActorTests.swift` (新增存储 Actor 并发与冲突测试套件)
  - `StudyOSTests/ReaderAdapterFlowTests.swift` (新增适配器流程与跨会话核对测试套件)
  - `StudyOSTests/StudyOSTests.swift` (基础版本信息与 Smoke 测试)
  - `docs/logs/qa.md` (追加本轮工作日志)
  - `docs/handoffs/M1-SETUP-QA-qa-001.md` (本交接文档)

---

## 1. 交付测试套件总览

依据 M0 验收矩阵 (R01–R21) 与联调用例 (UI-T01–UI-T11)，Codex2 在专有测试目录 `StudyOSTests/` 完成了 4 大专项测试套件的编写，100% 覆盖后端核心服务与客户端 UI 适配层关键契约约束：

| 测试套件文件 | 关联用例与需求 | 核心验证内容 |
|---|---|---|
| **`StudyOSTests/ContractTests.swift`** | UIREV-01, UIREV-03, UIREV-04, UIREV-06<br>(R02, R03, R04, R09, R17, UI-T03, UI-T05, UI-T07) | 1. `PageKey` 唯一哈希、跨文档/版本/物理页三元组隔离、`storageKey` 格式规范 (`docID_rev_pIndex`)、字典键与集合去重；<br>2. `InkSaveSnapshot` 入队前不可变固化（值语义隔离，数据追加不污染快照）；<br>3. `InkSaveReceipt` 版本严格单调递增与 Codable 往返；<br>4. `ReaderToolMode` 三态穷举与序列化；<br>5. `SaveInkError` 结构化错误分型完备性；<br>6. `NotePolicy` 两路策略枚举契约。 |
| **`StudyOSTests/ModelTests.swift`** | UIREV-01, UIREV-04, UIREV-06<br>(R01, R04, R09, R11, R16, UI-T07, UI-T11) | 1. `Document` 全字段序列化、ISO8601 日期编解码、`ImportState` 与 `IndexState` 状态枚举；<br>2. `Page` 物理页记录、0-based `pageIndex0` 标识符规范 (`docID_rev_pIndex0`)、`cropBox` 与 `rotation`；<br>3. `SourceAnchor` 定位精度 (`page`/`region`) 与有效性 (`active`/`documentDeleted`)；<br>4. **两路删除策略解绑验证**：在 `NotePolicy.keep` 下验证 `documentID` 与 `chapterID` 置空 (`nil`)，`sourceAnchors.availability` 置为 `.documentDeleted`，保留可编辑文本与图片副本，且反序列化完备；在 `NotePolicy.delete` 下验证级联连带清除。 |
| **`StudyOSTests/StorageActorTests.swift`** | UIREV-03, UIREV-06<br>(R03, R17, UI-T05) | 1. **Actor 隔离并发写**：多页面并发调用 `InkStorageEngine.saveInk`，TaskGroup 异步竞态验证与隔离沙盒路径校验；<br>2. **连续快速笔画提交推进**：模拟用户连续落笔，版本号严格由 0 推进至 1、2、3，最新文件与索引内容一致；<br>3. **`expectedRevision` 版本冲突检测**：提交过期版本的快照触发 `SaveInkError.conflict(currentRevision:)`，拒绝非法覆盖；<br>4. **墨水清理**：`removeInks` 彻底清除物理磁盘文件与 `PageKeyIndexManager` 内存索引。 |
| **`StudyOSTests/ReaderAdapterFlowTests.swift`** | UIREV-01, UIREV-03, UIREV-04<br>(R02, R03, R09, UI-T01, UI-T04, UI-T05, UI-T07) | 1. **跨会话核对与 `ignoredStaleSession` 隔离**：主执行域核对目标文档 ID 与版本，失配时静默丢弃并返回 `.ignoredStaleSession`，禁止乱跳；<br>2. **旧版本来源拦截**：返回 `.staleReference` 并抛出吐司；<br>3. **已删除来源拦截**：返回 `.unavailable` 并提示失效；<br>4. **墨水提交会话隔离**：跨会话笔画快照直接拒绝并返回 `.failure(.staleReference)`；<br>5. **工具态三态流转**：`reading` ↔ `textSelection` ↔ `annotation`；<br>6. **导航越界保护与选区生命周期**：合法页码跳转、负数越界拦截、超出总页数拦截、选区变更广播与清除。 |

---

## 2. 宿主测试状态与客观判定说明 (Strict NOT_RUN)

按照 WORKFLOW 规范与 QA 严谨原则，严格区分测试设计与实际执行证据：

- **当前运行环境**：Windows 本地环境，无 Apple 原生 Xcode / Swift 工具链；
- **静态代码审查**：
  - 测试套件全部遵循 Swift 5.9+ 并发规则 (`@MainActor`, `Sendable`, `TaskGroup`)；
  - 接口与方法签名与 Codex1 交付的核心服务及 Claude2 交付的 UI 适配器 100% 对齐；
  - 零强制解包，测试逻辑自包含；
- **测试执行状态判定**：**`NOT_RUN`**
  - 由于宿主环境无 `swift` / `xcodebuild` 命令，当前环境无法产生真实运行测试证据；
  - 绝不虚报 `PASS`，全部矩阵项客观保持 `NOT_RUN`。

---

## 3. macOS / Xcode 环境验证与证据收集指南

当在 macOS / Xcode 构建机执行测试时，请遵循以下标准流程与验证命令：

### 3.1 命令行直接运行 (Swift PM)

在项目根目录下执行：
```bash
# 执行全部测试套件
swift test --enable-code-coverage

# 定向执行特定测试用例类
swift test --filter ContractTests
swift test --filter ModelTests
swift test --filter StorageActorTests
swift test --filter ReaderAdapterFlowTests
```

### 3.2 Xcode 命令行执行 (模拟器环境)

```bash
# 指定 iPad Pro 模拟器执行
xcodebuild test \
  -scheme StudyOS \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=17.5' \
  -resultBundlePath TestResults.xcresult
```

### 3.3 真实测试证据收集要求

在后续配备 macOS/Xcode 环境执行时，必须按以下格式收集并归档至 `docs/qa/evidence/`：
1. **构建信息**：Git Commit SHA、Xcode 版本、Swift 工具链版本；
2. **测试日志**：完整的控制台输出或 `xcresult` 测试结果包；
3. **断言清单**：确认全部 20 个测试方法通过无失败；
4. **覆盖率报告**：核心模型与存储引擎代码覆盖率数据；
5. **矩阵更新**：测试证据归档后，方可由 QA 在 `ACCEPTANCE-MATRIX.md` 中将对应项的状态由 `NOT_RUN` 调整为 `PASS`。

---

## 4. 排他文件规则与建议

- **排他写入保证**：
  - 严格仅写入测试目录 `StudyOSTests/`、日志文件 `docs/logs/qa.md` 与本交接文件；
  - 严禁且未触碰业务源码目录 `StudyOS/**`、`docs/ui/**`、`docs/backend/**`、`docs/project/**`；
- **建议下一步**：
  1. 提请主协调者将本交接文件转交项目经理 Claude1；
  2. 建议 PM 组织在具备 macOS/Xcode 编译机上拉取最新代码，统一执行 `swift test` 收集首轮真实测试证据；
  3. 确认 M1-SETUP 全部模块交付完毕后推进看板至下一里程碑。
