import Foundation

/// Manages the per-domain `/etc/resolver/<domain>` files that route ONLY
/// blocked-domain queries to our local NXDOMAIN stub. Everything else is
/// served by the system's normal DNS path — we never touch it.
///
/// Each managed file has a marker comment so cleanup never removes a file
/// the daemon did not create (e.g. corporate VPN or other vendor configs).
public final class ResolverDirectoryManager {
    public struct SyncResult {
        public let created: [String]
        public let updated: [String]
        public let removed: [String]
        public var changed: Bool { !created.isEmpty || !updated.isEmpty || !removed.isEmpty }
    }

    private let paths: Paths
    private let stubPort: UInt16
    private let stubAddress: String
    private let privateRelayHostnames: [String]
    private let includePrivateRelay: Bool

    public init(
        paths: Paths = Paths(),
        stubAddress: String = "127.0.0.1",
        stubPort: UInt16 = 5454,
        privateRelayHostnames: [String] = ["mask.icloud.com", "mask-h2.icloud.com"],
        includePrivateRelay: Bool = true
    ) {
        self.paths = paths
        self.stubAddress = stubAddress
        self.stubPort = stubPort
        self.privateRelayHostnames = privateRelayHostnames
        self.includePrivateRelay = includePrivateRelay
    }

    /// Ensure that, for every domain in the desired set, a marker-tagged
    /// `/etc/resolver/<domain>` file exists pointing at our stub. Remove any
    /// previously-managed file that is no longer in the desired set. Files
    /// without our marker are left alone.
    @discardableResult
    public func sync(blockedDomains: [String]) throws -> SyncResult {
        let desired = expandedDesiredSet(blockedDomains: blockedDomains)

        try ensureResolverDirectory()

        var created: [String] = []
        var updated: [String] = []
        var removed: [String] = []

        let expectedContent = Self.renderFileContent(stubAddress: stubAddress, stubPort: stubPort)
        let expectedBytes = Data(expectedContent.utf8)

        for name in desired.sorted() {
            let path = filePath(for: name)
            if FileManager.default.fileExists(atPath: path) {
                let currentBytes = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
                if currentBytes != expectedBytes {
                    if currentBytes.starts(with: Data(Self.markerLine.utf8)) || !FileManager.default.fileExists(atPath: path) {
                        clearImmutable(at: path)
                        try expectedBytes.write(to: URL(fileURLWithPath: path), options: .atomic)
                        try tightenOwnership(path: path)
                        setImmutable(at: path)
                        updated.append(name)
                    }
                    // If the file exists without our marker, leave it alone.
                } else {
                    // Content is correct — ensure the flag is still on, in
                    // case something cleared it externally.
                    setImmutable(at: path)
                }
            } else {
                try expectedBytes.write(to: URL(fileURLWithPath: path), options: .atomic)
                try tightenOwnership(path: path)
                setImmutable(at: path)
                created.append(name)
            }
        }

        // Remove our own files that are no longer desired.
        let managed = try listManagedFileNames()
        for existing in managed where !desired.contains(existing) {
            let path = filePath(for: existing)
            if isOurFile(at: path) {
                clearImmutable(at: path)
                try? FileManager.default.removeItem(atPath: path)
                removed.append(existing)
            }
        }

        return SyncResult(created: created, updated: updated, removed: removed)
    }

    /// Remove every file we own. Files without our marker are not touched.
    @discardableResult
    public func removeAllManagedFiles() throws -> [String] {
        var removed: [String] = []
        let names = (try? listManagedFileNames()) ?? []
        for name in names {
            let path = filePath(for: name)
            if isOurFile(at: path) {
                clearImmutable(at: path)
                try? FileManager.default.removeItem(atPath: path)
                removed.append(name)
            }
        }
        return removed
    }

    public func managedDomains() -> [String] {
        (try? listManagedFileNames()) ?? []
    }

    public func expectedDomains(forBlocklist blockedDomains: [String]) -> [String] {
        expandedDesiredSet(blockedDomains: blockedDomains).sorted()
    }

    // MARK: - Helpers

    private func expandedDesiredSet(blockedDomains: [String]) -> Set<String> {
        var set = Set<String>()
        for raw in blockedDomains {
            guard let normalized = try? DomainNormalizer.normalize(raw) else { continue }
            set.insert(normalized)
        }
        if includePrivateRelay {
            for name in privateRelayHostnames {
                set.insert(name)
            }
        }
        return set
    }

    private func filePath(for domain: String) -> String {
        return paths.resolverDirectoryPath + "/" + domain
    }

    private func listManagedFileNames() throws -> [String] {
        guard FileManager.default.fileExists(atPath: paths.resolverDirectoryPath) else { return [] }
        let entries = try FileManager.default.contentsOfDirectory(atPath: paths.resolverDirectoryPath)
        return entries.filter { isOurFile(at: filePath(for: $0)) }
    }

    private func isOurFile(at path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }
        return text.hasPrefix(Self.markerLine)
    }

    private func ensureResolverDirectory() throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: paths.resolverDirectoryPath),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
    }

    private func tightenOwnership(path: String) throws {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/sbin/chown", arguments: ["root:wheel", path], allowFailure: true)
        _ = try? Shell.run("/bin/chmod", arguments: ["644", path], allowFailure: true)
    }

    private func clearImmutable(at path: String) {
        guard !paths.isRedirectedRoot, FileManager.default.fileExists(atPath: path) else { return }
        _ = try? Shell.run("/usr/bin/chflags", arguments: ["nouchg", path], allowFailure: true)
    }

    private func setImmutable(at path: String) {
        guard !paths.isRedirectedRoot, FileManager.default.fileExists(atPath: path) else { return }
        _ = try? Shell.run("/usr/bin/chflags", arguments: ["uchg", path], allowFailure: true)
    }

    // MARK: - Rendering (also used by tests)

    public static let markerLine = "# managed by steadfast"

    public static func renderFileContent(stubAddress: String, stubPort: UInt16) -> String {
        """
        \(markerLine) — do not edit; managed automatically
        nameserver \(stubAddress)
        port \(stubPort)
        """ + "\n"
    }
}
