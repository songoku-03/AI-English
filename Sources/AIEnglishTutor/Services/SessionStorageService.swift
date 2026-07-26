import Foundation

public protocol SessionStorageServiceProtocol: Sendable {
    func saveSession(_ record: SessionRecord) async throws
    func loadAllSessions() async throws -> [SessionRecord]
    func deleteSession(id: UUID) async throws
}

public final class SessionStorageService: SessionStorageServiceProtocol, @unchecked Sendable {
    private let storageDirectory: URL
    private let fileManager = FileManager.default

    public init(storageDirectory: URL? = nil) {
        if let directory = storageDirectory {
            self.storageDirectory = directory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("AIEnglishTutor/Sessions", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    }

    public func saveSession(_ record: SessionRecord) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(record.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadAllSessions() async throws -> [SessionRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var sessions: [SessionRecord] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let record = try? decoder.decode(SessionRecord.self, from: data) {
                sessions.append(record)
            }
        }
        return sessions.sorted(by: { $0.date > $1.date })
    }

    public func deleteSession(id: UUID) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }
}
