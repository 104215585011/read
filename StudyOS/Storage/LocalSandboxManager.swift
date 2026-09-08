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
        seedSampleAcademicDocumentIfEmpty()
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

    /// 播种初始学术样例文档与关联笔记（冷启动空白防护）
    public func seedSampleAcademicDocumentIfEmpty() {
        let docsFileURL = metadataFileURL(fileName: "documents")
        let fm = FileManager.default

        // 如果已有文档元数据且非空，则跳过
        if fm.fileExists(atPath: docsFileURL.path),
           let data = try? Data(contentsOf: docsFileURL),
           let docs = try? JSONDecoder().decode([String: Document].self, from: data),
           !docs.isEmpty {
            return
        }

        let docID = "doc_chapter4_linalg_dl"
        let docDir = documentDirectory(id: docID)
        if !fm.fileExists(atPath: docDir.path) {
            try? fm.createDirectory(at: docDir, withIntermediateDirectories: true)
        }

        // 写入最小合规学术 PDF 二进制
        let pdfString = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << >> >> endobj
        4 0 obj << /Length 55 >> stream
        BT
        /F1 18 Tf
        50 780 Td
        (Chapter 4: Linear Algebra & Deep Learning Foundations) Tj
        ET
        endstream
        endobj
        xref
        0 5
        0000000000 65535 f 
        0000000009 00000 n 
        0000000058 00000 n 
        0000000115 00000 n 
        0000000216 00000 n 
        trailer << /Size 5 /Root 1 0 R >>
        startxref
        322
        %%EOF
        """
        let pdfData = Data(pdfString.utf8)
        let pdfFileURL = documentPDFURL(id: docID)
        try? pdfData.write(to: pdfFileURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // 1. 文档元数据
        let sampleDoc = Document(
            id: docID,
            title: "Chapter 4: 线性代数与深度学习基础.pdf",
            sourceHash: "hash_chapter4_seed_sample",
            revision: 1,
            localFileRef: pdfFileURL.path,
            pageCount: 18,
            importState: .readable,
            indexState: .ready
        )
        let docsDict = [docID: sampleDoc]
        if let docsData = try? encoder.encode(docsDict) {
            try? docsData.write(to: docsFileURL, options: .atomic)
        }

        // 2. 划线与考点批注 (Annotation)
        let sampleAnchor = SourceAnchor(
            documentID: docID,
            pageIndex0: 0,
            precision: .text(exact: "特征值分解与奇异值分解（SVD）在低秩自注意力层中的降维应用", prefix: nil, suffix: nil)
        )
        let sampleAnno = Annotation(
            id: "anno_seed_svd_attention",
            kind: .highlight,
            anchor: sampleAnchor,
            content: "核心考点：低秩分解在自注意力权重矩阵压缩中的应用机制",
            revision: 1
        )
        let annoFileURL = metadataFileURL(fileName: "annotations")
        let annosDict = [sampleAnno.id: sampleAnno]
        if let annoData = try? encoder.encode(annosDict) {
            try? annoData.write(to: annoFileURL, options: .atomic)
        }

        // 3. 示例笔记 (Note)
        let sampleNote = Note(
            id: "note_seed_svd_dl",
            documentID: docID,
            chapterID: nil,
            editableText: "【重点推导】SVD 与主成分分析（PCA）的对应关系：\\n1. 利用截断奇异值分解（Truncated SVD）将权重矩阵 W 逼近为低秩近似 W ≈ U_k * Σ_k * V_k^T；\\n2. 显著压缩 Transformer KV Cache 显存占用，同时保持注意力矩阵的谱范数上界与泛化能力。",
            imageRefs: [],
            sourceAnchors: [sampleAnchor],
            aiOrigin: AIOrigin(
                attemptID: "seed_attempt_linalg_01",
                profileID: "deepseek-r1",
                promptSnapshot: "解析 SVD 在自注意力矩阵压缩中的机制与考点",
                generatedAt: Date()
            ),
            revision: 1
        )
        let notesFileURL = metadataFileURL(fileName: "notes")
        let notesDict = [sampleNote.id: sampleNote]
        if let notesData = try? encoder.encode(notesDict) {
            try? notesData.write(to: notesFileURL, options: .atomic)
        }

        // 4. 阅读位置 (ReadingPosition)
        let samplePos = ReadingPosition(
            documentID: docID,
            documentRevision: 1,
            pageIndex0: 0,
            pagePoint: CodablePoint(x: 0, y: 45),
            zoomHint: 1.0
        )
        let posFileURL = metadataFileURL(fileName: "readingPositions")
        let posDict = [docID: samplePos]
        if let posData = try? encoder.encode(posDict) {
            try? posData.write(to: posFileURL, options: .atomic)
        }
    }
}
