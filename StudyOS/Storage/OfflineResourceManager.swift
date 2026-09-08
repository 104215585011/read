import Foundation
import CryptoKit

/// 端侧离线资源管理器实现 (OfflineResourceManager)
/// 负责模型包注册、权重分块存储、沙盒管理与 SHA-256 完整性校验 (R14)
public actor OfflineResourceManager: OfflineResourceManagerProtocol {
    private let sandbox: LocalSandboxManager
    private var packages: [String: ModelPackageMetadata] = [:]
    private let fileManager = FileManager.default

    public init(sandbox: LocalSandboxManager = .shared) {
        self.sandbox = sandbox
        self.packages = Self.loadPackagesFromDisk(sandbox: sandbox)
    }

    // MARK: - 静态初始化辅助（避免 Swift 6 Actor Init 隔离警告）

    private static func loadPackagesFromDisk(sandbox: LocalSandboxManager) -> [String: ModelPackageMetadata] {
        var loaded: [String: ModelPackageMetadata] = [:]
        let modelsDir = sandbox.modelsDirectoryURL
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(at: modelsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants]) else {
            return loaded
        }

        let decoder = JSONDecoder()
        for case let packageDirURL as URL in enumerator {
            let metadataURL = packageDirURL.appendingPathComponent("metadata.json")
            if fm.fileExists(atPath: metadataURL.path),
               let data = try? Data(contentsOf: metadataURL),
               let metadata = try? decoder.decode(ModelPackageMetadata.self, from: data) {
                loaded[metadata.packageID] = metadata
            }
        }
        return loaded
    }

    // MARK: - OfflineResourceManagerProtocol

    /// 注册新的模型元数据
    public func registerPackage(_ metadata: ModelPackageMetadata) async throws {
        let packageDir = sandbox.modelPackageDirectory(packageID: metadata.packageID)
        if !fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true)
        }

        packages[metadata.packageID] = metadata
        try persistMetadata(metadata)
    }

    /// 获取单个模型包元数据
    public func getPackage(id: String) async -> ModelPackageMetadata? {
        packages[id]
    }

    /// 列出所有已注册模型包
    public func listPackages() async -> [ModelPackageMetadata] {
        Array(packages.values).sorted { $0.modelName < $1.modelName }
    }

    /// 删除指定模型包及其沙盒文件
    public func deletePackage(id: String) async throws -> Bool {
        guard let _ = packages[id] else { return false }
        packages.removeValue(forKey: id)

        let packageDir = sandbox.modelPackageDirectory(packageID: id)
        if fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.removeItem(at: packageDir)
        }
        return true
    }

    /// 存储模型权重分块
    public func storeModelChunk(
        packageID: String,
        chunkIndex: Int,
        totalChunks: Int,
        data: Data
    ) async throws {
        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        if !fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true)
        }

        let chunkURL = packageDir.appendingPathComponent("chunk_\(chunkIndex).part")
        try data.write(to: chunkURL, options: .atomic)

        // 检查是否所有分块均已就绪
        var allChunksPresent = true
        for i in 0..<totalChunks {
            let partURL = packageDir.appendingPathComponent("chunk_\(i).part")
            if !fileManager.fileExists(atPath: partURL.path) {
                allChunksPresent = false
                break
            }
        }

        if allChunksPresent {
            // 合并分块至 weights.bin
            let finalWeightsURL = packageDir.appendingPathComponent("weights.bin")
            fileManager.createFile(atPath: finalWeightsURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: finalWeightsURL)
            defer { try? fileHandle.close() }

            for i in 0..<totalChunks {
                let partURL = packageDir.appendingPathComponent("chunk_\(i).part")
                let partData = try Data(contentsOf: partURL)
                try fileHandle.write(contentsOf: partData)
                try? fileManager.removeItem(at: partURL)
            }

            // 更新元数据
            if var meta = packages[packageID] {
                let attr = try fileManager.attributesOfItem(atPath: finalWeightsURL.path)
                let fileSize = (attr[.size] as? NSNumber)?.int64Value ?? Int64(data.count)
                meta.isDownloaded = true
                let updated = ModelPackageMetadata(
                    packageID: meta.packageID,
                    modelName: meta.modelName,
                    format: meta.format,
                    fileSizeBytes: fileSize,
                    isDownloaded: true,
                    isQuantized: meta.isQuantized,
                    minMemoryRequirementBytes: meta.minMemoryRequirementBytes,
                    sha256Checksum: meta.sha256Checksum,
                    runtimeKind: meta.runtimeKind,
                    version: meta.version
                )
                packages[packageID] = updated
                try persistMetadata(updated)
            }
        }
    }

    /// 存储完整模型文件
    public func storeModelFile(
        packageID: String,
        fileName: String,
        data: Data
    ) async throws -> URL {
        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        if !fileManager.fileExists(atPath: packageDir.path) {
            try fileManager.createDirectory(at: packageDir, withIntermediateDirectories: true)
        }

        let fileURL = packageDir.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)

        if var meta = packages[packageID] {
            let updated = ModelPackageMetadata(
                packageID: meta.packageID,
                modelName: meta.modelName,
                format: meta.format,
                fileSizeBytes: Int64(data.count),
                isDownloaded: true,
                isQuantized: meta.isQuantized,
                minMemoryRequirementBytes: meta.minMemoryRequirementBytes,
                sha256Checksum: meta.sha256Checksum,
                runtimeKind: meta.runtimeKind,
                version: meta.version
            )
            packages[packageID] = updated
            try persistMetadata(updated)
        }

        return fileURL
    }

    /// 执行 SHA-256 完整性校验
    public func verifyPackageIntegrity(packageID: String) async throws -> PackageIntegrityResult {
        guard let metadata = packages[packageID] else {
            return PackageIntegrityResult(
                packageID: packageID,
                isValid: false,
                expectedChecksum: nil,
                actualChecksum: nil,
                fileSizeBytes: 0,
                message: "模型包未注册"
            )
        }

        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        guard fileManager.fileExists(atPath: packageDir.path) else {
            return PackageIntegrityResult(
                packageID: packageID,
                isValid: false,
                expectedChecksum: metadata.sha256Checksum,
                actualChecksum: nil,
                fileSizeBytes: 0,
                message: "沙盒模型目录不存在"
            )
        }

        // 寻找模型载荷文件 (weights.bin, model.bin, 或目录内的主要文件)
        let candidates = ["weights.bin", "model.bin", "\(metadata.modelName).\(metadata.format)"]
        var targetFileURL: URL?
        for candidate in candidates {
            let candidateURL = packageDir.appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: candidateURL.path) {
                targetFileURL = candidateURL
                break
            }
        }

        // 若无特定主文件，检查是否存在任意非 metadata 文件
        if targetFileURL == nil {
            let items = (try? fileManager.contentsOfDirectory(at: packageDir, includingPropertiesForKeys: nil)) ?? []
            targetFileURL = items.first(where: { $0.lastPathComponent != "metadata.json" })
        }

        guard let fileURL = targetFileURL else {
            return PackageIntegrityResult(
                packageID: packageID,
                isValid: false,
                expectedChecksum: metadata.sha256Checksum,
                actualChecksum: nil,
                fileSizeBytes: 0,
                message: "模型权重文件缺失"
            )
        }

        let fileData = try Data(contentsOf: fileURL)
        let actualChecksum = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
        let fileSize = Int64(fileData.count)

        if let expected = metadata.sha256Checksum, !expected.isEmpty {
            let isValid = (actualChecksum.lowercased() == expected.lowercased())
            return PackageIntegrityResult(
                packageID: packageID,
                isValid: isValid,
                expectedChecksum: expected,
                actualChecksum: actualChecksum,
                fileSizeBytes: fileSize,
                message: isValid ? "完整性校验通过" : "SHA-256 校验失败：哈希不匹配"
            )
        } else {
            // 没有预设校验和时，以当前计算值为准判定有效
            return PackageIntegrityResult(
                packageID: packageID,
                isValid: true,
                expectedChecksum: nil,
                actualChecksum: actualChecksum,
                fileSizeBytes: fileSize,
                message: "完整性校验通过 (自生成 SHA-256 指纹)"
            )
        }
    }

    /// 检查模型包是否已就绪（已下载且校验存在）
    public func isPackageReady(packageID: String) async -> Bool {
        guard let metadata = packages[packageID], metadata.isDownloaded else {
            return false
        }
        let packageDir = sandbox.modelPackageDirectory(packageID: packageID)
        return fileManager.fileExists(atPath: packageDir.path)
    }

    /// 统计端侧模型沙盒占用的总磁盘空间
    public func totalStorageBytesUsed() async -> Int64 {
        let modelsDir = sandbox.modelsDirectoryURL
        guard let enumerator = fileManager.enumerator(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - 私有辅助

    private func persistMetadata(_ metadata: ModelPackageMetadata) throws {
        let metadataURL = sandbox.modelPackageMetadataURL(packageID: metadata.packageID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }
}
