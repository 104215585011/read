import Foundation

/// 页面手写生命周期状态
public enum InkPageState: String, Sendable {
    case clean
    case dirty
    case saving
    case saved
    case failed
    case conflict
}

/// PageKey 索引与并发版本追踪器 (Actor 隔离)
public actor PageKeyIndexManager {
    public struct KeyRecord: Sendable {
        public var persistedRevision: Int
        public var inFlightSnapshotID: String?
        public var isDirty: Bool
        public var state: InkPageState
        public var lastSavedAt: Date?
    }

    private var records: [PageKey: KeyRecord] = [:]

    public init() {}

    /// 获取当前持久化版本（默认为 0）
    public func getPersistedRevision(for key: PageKey) -> Int {
        records[key]?.persistedRevision ?? 0
    }

    /// 获取状态记录
    public func getRecord(for key: PageKey) -> KeyRecord? {
        records[key]
    }

    /// 标记页面脏状态
    public func markDirty(for key: PageKey) {
        if var record = records[key] {
            record.isDirty = true
            record.state = .dirty
            records[key] = record
        } else {
            records[key] = KeyRecord(
                persistedRevision: 0,
                inFlightSnapshotID: nil,
                isDirty: true,
                state: .dirty,
                lastSavedAt: nil
            )
        }
    }

    /// 开始排队提交快照，校验 expectedRevision
    public func beginSave(
        key: PageKey,
        snapshotID: String,
        expectedRevision: Int
    ) -> Result<Void, SaveInkError> {
        let currentPersisted = getPersistedRevision(for: key)
        if expectedRevision != currentPersisted {
            var rec = records[key] ?? KeyRecord(persistedRevision: currentPersisted, inFlightSnapshotID: nil, isDirty: true, state: .conflict, lastSavedAt: nil)
            rec.state = .conflict
            records[key] = rec
            return .failure(.conflict(currentRevision: currentPersisted))
        }

        var rec = records[key] ?? KeyRecord(persistedRevision: currentPersisted, inFlightSnapshotID: nil, isDirty: false, state: .saving, lastSavedAt: nil)
        rec.inFlightSnapshotID = snapshotID
        rec.state = .saving
        records[key] = rec
        return .success(())
    }

    /// 完成保存，推进 persistedRevision
    public func completeSave(
        key: PageKey,
        snapshotID: String,
        savedRevision: Int
    ) {
        var rec = records[key] ?? KeyRecord(persistedRevision: 0, inFlightSnapshotID: nil, isDirty: false, state: .saved, lastSavedAt: Date())
        if rec.inFlightSnapshotID == snapshotID {
            rec.inFlightSnapshotID = nil
        }
        rec.persistedRevision = savedRevision
        rec.state = rec.isDirty ? .dirty : .saved
        rec.lastSavedAt = Date()
        records[key] = rec
    }

    /// 标记保存失败
    public func failSave(
        key: PageKey,
        snapshotID: String,
        error: SaveInkError
    ) {
        var rec = records[key] ?? KeyRecord(persistedRevision: 0, inFlightSnapshotID: nil, isDirty: true, state: .failed, lastSavedAt: nil)
        if rec.inFlightSnapshotID == snapshotID {
            rec.inFlightSnapshotID = nil
        }
        rec.state = .failed
        records[key] = rec
    }

    /// 清空指定文档的索引缓存（文档删除时调用）
    public func removeKeys(forDocumentID documentID: String) {
        records = records.filter { $0.key.documentID != documentID }
    }
}
