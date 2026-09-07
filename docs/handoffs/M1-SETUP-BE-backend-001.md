# M1-SETUP 核心服务骨架与工程配置交接文件

- 文件编号：`M1-SETUP-BE-backend-001`
- 时间：`2026-09-07T16:58:00+08:00`
- 发送角色：项目后端（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与契约版本：
  - 后端契约草案：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - UI 交互与适配规范：`docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`
  - 前序交接文件：`docs/handoffs/M0-CLOSE-pm-001.md`
- 变更路径：
  - `Package.swift`
  - `Config/Info.plist`
  - `Scripts/build.sh`
  - `StudyOS/StudyOS.swift`
  - `StudyOS/Contracts/` (`Contracts.swift`, `ContractTypes.swift`, `CoreServiceProtocol.swift`, `ReaderAdapterProtocol.swift`)
  - `StudyOS/Models/` (`GeometryModels.swift`, `Document.swift`, `Page.swift`, `Paragraph.swift`, `Chapter.swift`, `SourceAnchor.swift`, `InkModels.swift`, `Annotation.swift`, `ReadingPosition.swift`, `Note.swift`, `Evidence.swift`, `AIModels.swift`, `ContextManifest.swift`, `NavigationModels.swift`)
  - `StudyOS/Storage/` (`LocalSandboxManager.swift`, `PageKeyIndexManager.swift`, `InkStorageEngine.swift`, `MetadataStorageEngine.swift`)
  - `StudyOS/Services/` (`ReaderCoreService.swift`, `DocumentService.swift`, `NoteService.swift`, `CoreService.swift`)
  - `StudyOSTests/StudyOSTests.swift` (占位用例骨架)
  - `docs/logs/backend.md`
  - `docs/handoffs/M1-SETUP-BE-backend-001.md`

---

## 1. 完成事项概述

作为单一工程配置写者（Single Config Writer）与核心服务负责人，Codex1 已完成现代化 Swift Package Manager 脚手架与核心后端/存储/契约实现的落地：

### 1.1 工程配置与脚手架
- **`Package.swift`**：基于 Swift 5.9+，定义 `.iOS(.v17)` 与 `.macOS(.v14)` 平台支持，配置主 Target `StudyOS` 与测试 Target `StudyOSTests`，坚持本地优先设计，零重度外部依赖；
- **`Config/Info.plist`**：定义 iPadOS 17.0+ 原生设备能力、横竖屏与文档打开支持；
- **`Scripts/build.sh`**：提供构建与单元测试一键运行脚本。

### 1.2 契约与领域模型落地 (`0.1-draft / M0-BE-REV2`)
- **`StudyOS/Contracts/`**：
  - `ReaderAdapterProtocol`：对齐 UIREV-01、UIREV-03、UIREV-04，定义 `readerSessionID`、`PageKey`、`InkSaveSnapshot`、`InkSaveReceipt`、安全导航、缩放与工具态切换协议；
  - `CoreServiceProtocol` 与分模块协议（`DocumentServiceProtocol`、`ReaderCoreServiceProtocol`、`NoteServiceProtocol`）；
  - `SaveInkError`、`ReaderToolMode`、`NotePolicy`、`DeleteImpact`、`DeleteResult`、`Bookmark`、`ReaderSnapshot`、`OutlineNode`、`SearchResultItem`。
- **`StudyOS/Models/`**：
  - 全部 14 组领域模型实现：`Document`, `Page`, `Paragraph`, `Chapter`, `SourceAnchor`, `InkPage`, `Annotation`, `ReadingPosition`, `Note`, `Evidence`, `AIModels`, `ContextManifest`, `NavigationModels`, `GeometryModels`；
  - 全部模型严格遵循 `Codable`, `Sendable`, `Hashable`；
  - 坐标系统使用 `CodableRect`/`CodablePoint`/`CodableTransform` 严格对应 PDF 页面空间 points，并提供 CoreGraphics `CGRect`/`CGPoint`/`CGAffineTransform` 无缝桥接扩展。

### 1.3 本地优先持久化引擎 (`StudyOS/Storage/`)
- **`LocalSandboxManager`**：本地文件沙盒目录管理（Documents, Metadata, Notes, Temp），路径隔离与安全降级；
- **`PageKeyIndexManager`**：基于 Actor 的手写生命周期状态机与版本追踪（`persistedRevision`、`isDirty`、`inFlightSnapshotID`、状态跃迁：`clean` -> `dirty` -> `saving` -> `saved` / `failed` / `conflict`）；
- **`InkStorageEngine`**：原子化二进制墨水写盘，串行提交与版本校验，生成 `InkSaveReceipt`；
- **`MetadataStorageEngine`**：Actor 隔离的 JSON/内存双层元数据引擎，支持两路删除策略（`keep` 保留笔记副本并标记 `documentDeleted` 不可导航，`delete` 连带清理关联笔记）。

### 1.4 核心领域服务 (`StudyOS/Services/`)
- **`ReaderCoreService`**：实现 `resolveSource`（严格跨版本核对，失配返回 `staleReference`，禁止跳转旧版本疑似位置）、`savePosition`、`flushInk`、`getReaderSnapshot`；
- **`DocumentService`**：实现 `importPDF`、`unlockDocument`、`previewDeleteDocument`、`deleteDocument`；
- **`NoteService`**：实现笔记创建、版本乐观锁更新、查询与删除；
- **`CoreService`**：统一外观聚合门面，提供 `makeDefault()` 单例便捷构造与协议代理。

---

## 2. 验证命令与实际结果 (Strict NOT_RUN)

- **宿主环境说明**：当前开发环境为 Windows，无 macOS / Xcode 编译链；
- **静态检查**：代码结构、语法规则、强类型完备性及 Swift Concurrency 语义经人工与静态代码规则全面走查；
- **实际构建与测试状态**：
  - `swift build`：**`NOT_RUN`**（宿主无 Swift CLI）
  - `swift test`：**`NOT_RUN`**（宿主无 Swift CLI）
  - 验收用例 (R01–R21, UI-T01–UI-T11)：如实保持 **`NOT_RUN`**，无虚报或伪造测试。

---

## 3. 已知限制与未测项

1. **平台限制**：PencilKit 与 UIKit 专用渲染需在 macOS / iPadOS 17.0+ 运行，模型层对 CoreGraphics 和 PencilKit 采用了 `#if canImport(...)` 防御隔离；
2. **AI Provider 与 PDF 文本提取**：当前为 M1-SETUP 最小骨架切片，实际 OCR/PDF 文本流提取与 Provider 网络客户端将在后续任务中逐步接入。

---

## 4. 排他文件权限与下一步

- **排他写入遵循**：
  - 本轮严格未修改 `docs/ui/**`、`docs/qa/**`、`docs/project/**`；
  - 严禁触碰客户端 UI 目录：`StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/`；
- **建议下一步**：
  1. 主协调者将进展同步项目经理 Claude1；
  2. 协调外部 UI 总监 Claude2 接入 `StudyOS/UI/` 与 `StudyOS/Adapters/`，基于 `ReaderAdapterProtocol` 与 `CoreServiceProtocol` 实现 SwiftUI + PDFKit/PencilKit 原生 UI 切片；
  3. 协调项目测试 Codex2 基于已生成的 `StudyOSTests/` 骨架接入契约单元测试套件。
