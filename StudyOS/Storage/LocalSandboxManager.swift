import Foundation

/// 本地沙盒路径与目录管理器
public final class LocalSandboxManager: @unchecked Sendable {
    public static let shared = LocalSandboxManager()

    public let rootDirectoryURL: URL
    private let fileManager = FileManager.default

    public init(rootDirectoryURL: URL? = nil) {
        if let root = rootDirectoryURL {
            self.rootDirectoryURL = root
        } else if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.rootDirectoryURL = appSupport.appendingPathComponent("StudyOS", isDirectory: true)
        } else {
            self.rootDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("StudyOS", isDirectory: true)
        }
        ensureBaseDirectoriesExist()
    }

    public var documentsDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("Documents", isDirectory: true)
    }

    public var metadataDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("Metadata", isDirectory: true)
    }

    public var notesDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("Notes", isDirectory: true)
    }

    public var modelsDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("Models", isDirectory: true)
    }

    public var temporaryDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("Temp", isDirectory: true)
    }

    public func ensureBaseDirectoriesExist() {
        let dirs = [documentsDirectoryURL, metadataDirectoryURL, notesDirectoryURL, modelsDirectoryURL, temporaryDirectoryURL]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    public func documentDirectory(id: String) -> URL {
        documentsDirectoryURL.appendingPathComponent(id, isDirectory: true)
    }

    public func documentPDFURL(id: String) -> URL {
        documentDirectory(id: id).appendingPathComponent("source.pdf")
    }

    public func inkDirectory(documentID: String, documentRevision: Int) -> URL {
        documentDirectory(id: documentID)
            .appendingPathComponent("rev_\(documentRevision)", isDirectory: true)
            .appendingPathComponent("ink", isDirectory: true)
    }

    public func inkFileURL(pageKey: PageKey, drawingRevision: Int) -> URL {
        inkDirectory(documentID: pageKey.documentID, documentRevision: pageKey.documentRevision)
            .appendingPathComponent("page_\(pageKey.pageIndex0)_rev\(drawingRevision).ink")
    }

    public func metadataFileURL(fileName: String) -> URL {
        metadataDirectoryURL.appendingPathComponent("\(fileName).json")
    }

    public func modelPackageDirectory(packageID: String) -> URL {
        modelsDirectoryURL.appendingPathComponent(packageID, isDirectory: true)
    }

    public func modelPackageMetadataURL(packageID: String) -> URL {
        modelPackageDirectory(packageID: packageID).appendingPathComponent("metadata.json")
    }

    public func modelPackageFileURL(packageID: String, fileName: String) -> URL {
        modelPackageDirectory(packageID: packageID).appendingPathComponent(fileName)
    }
}
