import Foundation

public struct BlocklistState: Codable {
    public var blockedDomains: [String]
    public var updatedAt: Date

    public init(blockedDomains: [String] = [], updatedAt: Date = Date()) {
        self.blockedDomains = blockedDomains
        self.updatedAt = updatedAt
    }
}

public final class BlocklistStore: @unchecked Sendable {
    private let paths: Paths

    public init(paths: Paths = Paths()) {
        self.paths = paths
    }

    public func load() throws -> BlocklistState {
        guard FileManager.default.fileExists(atPath: paths.blocklistFilePath) else {
            return BlocklistState()
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: paths.blocklistFilePath))
        return try JSONDecoder().decode(BlocklistState.self, from: data)
    }

    @discardableResult
    public func add(_ rawDomain: String) throws -> String {
        let normalized = try DomainNormalizer.normalize(rawDomain)
        var state = try load()
        if !state.blockedDomains.contains(normalized) {
            state.blockedDomains.append(normalized)
            state.blockedDomains.sort()
            state.updatedAt = Date()
            try save(state)
        }

        return normalized
    }

    public func save(_ state: BlocklistState) throws {
        try ensureStateDirectory()

        let normalized = BlocklistState(
            blockedDomains: Array(Set(state.blockedDomains)).sorted(),
            updatedAt: state.updatedAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalized)
        try data.write(to: URL(fileURLWithPath: paths.blocklistFilePath), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.blocklistFilePath)
    }

    public func ensureStateDirectory() throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: paths.stateDirectoryPath),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: paths.stateDirectoryPath)
    }

    public func tightenOwnershipIfPossible() throws {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/sbin/chown", arguments: ["root:wheel", paths.stateDirectoryPath], allowFailure: true)
        _ = try? Shell.run("/bin/chmod", arguments: ["700", paths.stateDirectoryPath], allowFailure: true)

        if FileManager.default.fileExists(atPath: paths.blocklistFilePath) {
            _ = try? Shell.run("/usr/sbin/chown", arguments: ["root:wheel", paths.blocklistFilePath], allowFailure: true)
            _ = try? Shell.run("/bin/chmod", arguments: ["600", paths.blocklistFilePath], allowFailure: true)
        }
    }
}
