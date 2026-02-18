import Foundation

actor PendingImportManager {
    static let shared = PendingImportManager()

    func loadAll() async -> [PendingVideoImport] {
        guard let importsURL = SharedConstants.pendingImportsURL else { return [] }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: importsURL, includingPropertiesForKeys: nil)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return files.compactMap { url -> PendingVideoImport? in
                guard url.pathExtension == "json" else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(PendingVideoImport.self, from: data)
            }
        } catch {
            return []
        }
    }

    func load(id: UUID) async -> PendingVideoImport? {
        guard let importsURL = SharedConstants.pendingImportsURL else { return nil }
        let fileURL = importsURL.appendingPathComponent("\(id.uuidString).json")

        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingVideoImport.self, from: data)
    }

    /// Atomically load and delete a pending import file.
    /// First caller wins; second caller gets `nil` since the file is already removed.
    func loadAndDelete(id: UUID) async -> PendingVideoImport? {
        guard let importsURL = SharedConstants.pendingImportsURL else { return nil }
        let fileURL = importsURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            return nil  // Already claimed by another handler
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingVideoImport.self, from: data)
    }

    func delete(id: UUID) async {
        guard let importsURL = SharedConstants.pendingImportsURL else { return }
        let fileURL = importsURL.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func cleanupOldImports(olderThan interval: TimeInterval) async {
        let imports = await loadAll()
        let cutoff = Date().addingTimeInterval(-interval)

        for pendingImport in imports where pendingImport.createdAt < cutoff {
            await delete(id: pendingImport.id)
            if let videoURL = pendingImport.localVideoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
    }
}
