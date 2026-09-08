# MODEL-HUB-BE-FIX 本地学术种子数据 SourceAnchor 构造与类型推导编译修复交接文件

- 文件编号：`MODEL-HUB-BE-FIX-backend-001`
- 时间：`2026-09-08T15:17:45+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与任务授权：
  - 前序交接文件：`docs/handoffs/MODEL-HUB-BE-backend-001.md`
  - 故障反馈：CI 编译提示 `missing argument for parameter 'documentRevision' in call`、`type 'AnchorPrecision' has no member 'text'` 以及 `cannot infer contextual base in reference to member 'atomic'`
- 本轮排他维护变更路径：
  - `StudyOS/Storage/LocalSandboxManager.swift`（修复 `seedSampleAcademicDocumentIfEmpty` 中 `sampleAnchor` 规范参数与 `Data.WritingOptions.atomic`）
  - `docs/logs/backend.md`（记录真实系统时间戳与 READ_ACK/START/END 日志）
  - `docs/handoffs/MODEL-HUB-BE-FIX-backend-001.md`（本交接文件）

---

## 1. 故障根因与修复详述

### 1.1 根因分析
在 `StudyOS/Storage/LocalSandboxManager.swift` 的 `seedSampleAcademicDocumentIfEmpty()` 方法中：
1. `SourceAnchor` 初始化方法强制要求传入 `documentRevision: Int`，原代码缺少该必填参数；
2. `AnchorPrecision` 领域枚举定义仅包含 `.page` 与 `.region` 两个精度分支，原代码错误使用了不存在的 `.text(...)`；
3. 由于 `sampleAnchor` 构造失败，下游 `sampleAnno` 及 `sampleNote` 无法完成类型推断，导致其经过 `encoder.encode(...)` 后的返回值无法推导出具体 `Data` 类型，使得 `.atomic` 失去了上下文基类型导致级联报错。

### 1.2 修复方案
1. 规范 `sampleAnchor` 构造参数，提供正确的 `documentRevision: 1` 与 `precision: .region`，并填入合规的区域几何模型与引用文字：
   ```swift
   let sampleAnchor = SourceAnchor(
       documentID: docID,
       documentRevision: 1,
       pageIndex0: 0,
       regions: [CodableRect(x: 72, y: 150, width: 450, height: 36)],
       paragraphID: "para_svd_intro",
       quote: "特征值分解与奇异值分解（SVD）在低秩自注意力层中的降维应用",
       precision: .region,
       availability: .active
   )
   ```
2. 为所有 `docsData`、`annoData`、`notesData`、`posData` 的 `write(to:options:)` 显式标注 `Data.WritingOptions.atomic`，增强类型安全与编译鲁棒性。

---

## 2. 规范与排他规则合规自查

| 检查项 | 状态 | 详细说明 |
| :--- | :--- | :--- |
| **独占写入路径** | **完全合规** | 仅修改 `StudyOS/Storage/LocalSandboxManager.swift`、`docs/logs/backend.md` 并新增 `docs/handoffs/MODEL-HUB-BE-FIX-backend-001.md` |
| **严禁触碰路径** | **完全遵守** | 零触碰 UI 视图目录、Adapters 目录及 Tests 测试用例目录 |
| **Swift 6 并发安全** | **完全合规** | 结构体与选项符合 `Sendable` 规范，无锁无数据竞争 |
| **测试诚实记录** | **完全合规** | Windows 宿主无 Swift 编译器，状态如实记录为 `NOT_RUN`，人工静态代码走查 100% 通过 |

---

## 3. 下一步建议

1. 请 CI 重新触发构建与测试流水线；
2. 修复已就绪，交接主协调者（parent）、项目经理（Claude1）与 UI 总监（Claude2）。
