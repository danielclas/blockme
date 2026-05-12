import Foundation

public struct PublicStatus: Codable, Sendable {
    public var blockedDomains: [String]
    public var lastUpdatedAt: Date
    public var lastSuccessfulSyncAt: Date?
    public var lastHeartbeatAt: Date?
    public var lastErrorMessage: String?

    public init(
        blockedDomains: [String] = [],
        lastUpdatedAt: Date = Date(),
        lastSuccessfulSyncAt: Date? = nil,
        lastHeartbeatAt: Date? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.blockedDomains = blockedDomains
        self.lastUpdatedAt = lastUpdatedAt
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.lastHeartbeatAt = lastHeartbeatAt
        self.lastErrorMessage = lastErrorMessage
    }
}

public final class PublicStatusStore: @unchecked Sendable {
    private let paths: Paths

    public init(paths: Paths = Paths()) {
        self.paths = paths
    }

    public func load() throws -> PublicStatus {
        guard FileManager.default.fileExists(atPath: paths.publicStatusFilePath) else {
            return PublicStatus()
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: paths.publicStatusFilePath))
        return try JSONDecoder().decode(PublicStatus.self, from: data)
    }

    public func save(_ status: PublicStatus) throws {
        try ensurePublicDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(status)
        try data.write(to: URL(fileURLWithPath: paths.publicStatusFilePath), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: paths.publicStatusFilePath)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: paths.publicStatusFilePath) else {
            return
        }

        try FileManager.default.removeItem(atPath: paths.publicStatusFilePath)
    }

    public func ensurePublicDirectory() throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: paths.publicStatusDirectoryPath),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: paths.publicStatusDirectoryPath)

        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/sbin/chown", arguments: ["root:wheel", paths.publicStatusDirectoryPath], allowFailure: true)
    }
}

public final class StatusReporter {
    private let blocklistStore: BlocklistStore
    private let publicStatusStore: PublicStatusStore

    public init(
        blocklistStore: BlocklistStore,
        publicStatusStore: PublicStatusStore
    ) {
        self.blocklistStore = blocklistStore
        self.publicStatusStore = publicStatusStore
    }

    public func writeHealthySnapshot(syncAt: Date = Date(), heartbeatAt: Date = Date()) throws {
        var snapshot = try publicStatusStore.load()
        snapshot.blockedDomains = (try? blocklistStore.load().blockedDomains) ?? []
        snapshot.lastUpdatedAt = Date()
        snapshot.lastSuccessfulSyncAt = syncAt
        snapshot.lastHeartbeatAt = heartbeatAt
        snapshot.lastErrorMessage = nil
        try publicStatusStore.save(snapshot)
    }

    public func writeErrorSnapshot(_ message: String, heartbeatAt: Date = Date()) throws {
        var snapshot = try publicStatusStore.load()
        snapshot.blockedDomains = (try? blocklistStore.load().blockedDomains) ?? []
        snapshot.lastUpdatedAt = Date()
        snapshot.lastHeartbeatAt = heartbeatAt
        snapshot.lastErrorMessage = message
        try publicStatusStore.save(snapshot)
    }

    public func deleteSnapshot() throws {
        try publicStatusStore.delete()
    }
}
