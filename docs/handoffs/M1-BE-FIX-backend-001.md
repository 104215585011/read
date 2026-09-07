# M1-BE-FIX 工程配置修复交接文件

- 文件编号：`M1-BE-FIX-backend-001`
- 时间：`2026-09-07T22:44:08+08:00`
- 发送角色：项目后端（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与原则：
  - 产品设计基线：`AGENTS.md`、`docs/product/PRD-v0.1-source.md` 明确项目为 iPadOS 原生应用（UIKit / PencilKit / PDFKit / touch & pencil），非 macOS 原生应用
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 单一工程配置写者（Single Config Writer）：由 Codex1 独占维护根工程构建配置
- 变更路径：
  - `Package.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M1-BE-FIX-backend-001.md`

---

## 1. 修复事项说明

### 1.1 背景与问题
在前期工程脚手架中，`Package.swift` 声明了 `.macOS(.v14)` 平台支持。由于本项目核心功能与 UI 层深度依赖 iOS/iPadOS 原生能力（如 UIKit、PencilKit、UIFont、UIColor 等），在多平台构建矩阵或 CI/SPM 构建时，macOS 目标平台会因缺少 iPadOS 原生系统框架而触发编译错误。

### 1.2 修复动作
在 `Package.swift` 中，将 `platforms` 配置由：
```swift
platforms: [
    .iOS(.v17),
    .macOS(.v14)
],
```
修正为纯 iPadOS/iOS 平台目标：
```swift
platforms: [
    .iOS(.v17)
],
```

### 1.3 语法与结构完整性检查
- 语法与工具版本：`// swift-tools-version: 5.9`，遵循 PackageDescription 规范；
- 目标结构：保留 `StudyOS` 主 Target（路径 `StudyOS`）与 `StudyOSTests` 测试 Target（路径 `StudyOSTests`）；
- 依赖项：保持本地优先、零外部重度依赖策略；
- 语言标准：保持 `swiftLanguageVersions: [.v5]`。
- 经人工语法与括号配对走查，结构完整规范，无语法与配置冗余。

### 1.4 边界隔离与排他守则执行
- 严禁修改目录遵守：未触碰 `StudyOS/Views/**`、`docs/ui/**`、`docs/project/**`、`docs/qa/**` 或测试目录。

---

## 2. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 纪律，不得在无环境时伪造命令输出：
- 当前运行环境：Windows (PowerShell)
- 验证方式：代码结构与 SPM 声明人工静态走查（Manual Walkthrough Pass）
- 构建命令执行状态：**NOT_RUN**（当前环境缺少 Apple Swift/Clang/iOS SDK 工具链，未在 macOS/Linux 运行 `swift build`）

---

## 3. 后续交接与建议
1. 请主协调者（parent）与 QA（Codex2）知悉平台配置已纠偏至纯 `.iOS(.v17)`；
2. 消除后续 CI/测试执行时误触发 macOS 架构编译的问题。
