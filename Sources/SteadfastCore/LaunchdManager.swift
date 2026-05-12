import Foundation

public final class LaunchdManager {
    private let paths: Paths
    private let store: BlocklistStore
    private let hostsManager: HostsManager
    private let publicStatusStore: PublicStatusStore
    private let resolverManager: ResolverDirectoryManager
    private let settings: RuntimeSettings

    public init(
        paths: Paths = Paths(),
        store: BlocklistStore? = nil,
        hostsManager: HostsManager? = nil,
        publicStatusStore: PublicStatusStore? = nil,
        resolverManager: ResolverDirectoryManager? = nil,
        settings: RuntimeSettings = RuntimeSettings()
    ) {
        self.paths = paths
        self.store = store ?? BlocklistStore(paths: paths)
        self.hostsManager = hostsManager ?? HostsManager(paths: paths)
        self.publicStatusStore = publicStatusStore ?? PublicStatusStore(paths: paths)
        self.resolverManager = resolverManager ?? ResolverDirectoryManager(
            paths: paths,
            stubAddress: settings.stubListenAddress,
            stubPort: settings.stubListenPort,
            includePrivateRelay: settings.includePrivateRelay
        )
        self.settings = settings
    }

    public func install(currentExecutablePath: String) throws {
        try store.ensureStateDirectory()
        try store.tightenOwnershipIfPossible()
        try publicStatusStore.ensurePublicDirectory()
        let state = try store.load()
        if !FileManager.default.fileExists(atPath: paths.blocklistFilePath) {
            try store.save(state)
            try store.tightenOwnershipIfPossible()
        }

        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: (paths.installedBinaryPath as NSString).deletingLastPathComponent),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: (paths.userFacingBinaryPath as NSString).deletingLastPathComponent),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: paths.logDirectoryPath),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )

        try replaceItem(atPath: paths.installedBinaryPath, withItemAtPath: currentExecutablePath)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: paths.installedBinaryPath)
        try tightenRootOwnership(atPath: paths.installedBinaryPath, mode: "755")

        if FileManager.default.fileExists(atPath: paths.userFacingBinaryPath) {
            try FileManager.default.removeItem(atPath: paths.userFacingBinaryPath)
        }
        try FileManager.default.createSymbolicLink(atPath: paths.userFacingBinaryPath, withDestinationPath: paths.installedBinaryPath)

        if FileManager.default.fileExists(atPath: paths.userFacingBlockmeBinaryPath) {
            try FileManager.default.removeItem(atPath: paths.userFacingBlockmeBinaryPath)
        }
        try FileManager.default.createSymbolicLink(atPath: paths.userFacingBlockmeBinaryPath, withDestinationPath: paths.installedBinaryPath)
        try tightenRootOwnership(atPath: (paths.userFacingBinaryPath as NSString).deletingLastPathComponent, mode: "755")

        let plist = renderLaunchDaemonPlist()
        try Data(plist.utf8).write(to: URL(fileURLWithPath: paths.launchDaemonPlistPath), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: paths.launchDaemonPlistPath)
        try tightenRootOwnership(atPath: paths.launchDaemonPlistPath, mode: "644")

        // Write the resolver files and hosts entries up front so blocking is
        // active even before the daemon binds the stub socket. Worst case if
        // the stub never binds: blocked lookups time out / return SERVFAIL.
        // Critically, NON-blocked lookups never touch our resolver files, so
        // they are unaffected.
        _ = try resolverManager.sync(blockedDomains: state.blockedDomains)
        _ = try hostsManager.sync(blockedDomains: state.blockedDomains)
        flushDNSCacheIfNeeded()

        try reloadDaemonIfNeeded()
    }

    public func uninstall() throws {
        _ = try? Shell.run("/bin/launchctl", arguments: ["bootout", "system", paths.launchDaemonPlistPath], allowFailure: true)

        // Clean up everything we wrote, in best-effort order. Each step is
        // independently safe — none of them depend on global DNS state.
        _ = try? resolverManager.removeAllManagedFiles()
        try? hostsManager.removeManagedSection()
        flushDNSCacheIfNeeded()

        if FileManager.default.fileExists(atPath: paths.launchDaemonPlistPath) {
            try FileManager.default.removeItem(atPath: paths.launchDaemonPlistPath)
        }
        if FileManager.default.fileExists(atPath: paths.userFacingBinaryPath) {
            try FileManager.default.removeItem(atPath: paths.userFacingBinaryPath)
        }
        if FileManager.default.fileExists(atPath: paths.userFacingBlockmeBinaryPath) {
            try FileManager.default.removeItem(atPath: paths.userFacingBlockmeBinaryPath)
        }
        if FileManager.default.fileExists(atPath: paths.installedBinaryPath) {
            try FileManager.default.removeItem(atPath: paths.installedBinaryPath)
        }
    }

    public func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: paths.launchDaemonPlistPath) &&
        FileManager.default.fileExists(atPath: paths.installedBinaryPath)
    }

    public func reloadDaemonIfNeeded() throws {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/bin/launchctl", arguments: ["bootout", "system", paths.launchDaemonPlistPath], allowFailure: true)
        _ = try Shell.run("/bin/launchctl", arguments: ["bootstrap", "system", paths.launchDaemonPlistPath])
        _ = try? Shell.run("/bin/launchctl", arguments: ["kickstart", "-k", "system/\(paths.launchDaemonLabel)"], allowFailure: true)
    }

    private func flushDNSCacheIfNeeded() {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/bin/dscacheutil", arguments: ["-flushcache"], allowFailure: true)
        _ = try? Shell.run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"], allowFailure: true)
    }

    private func renderLaunchDaemonPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(paths.launchDaemonLabel)</string>
            <key>KeepAlive</key>
            <true/>
            <key>ProgramArguments</key>
            <array>
                <string>\(paths.installedBinaryPath)</string>
                <string>daemon</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardErrorPath</key>
            <string>\(paths.logDirectoryPath)/daemon.log</string>
            <key>StandardOutPath</key>
            <string>\(paths.logDirectoryPath)/daemon.log</string>
            <key>WorkingDirectory</key>
            <string>\(paths.stateDirectoryPath)</string>
        </dict>
        </plist>
        """
    }

    private func replaceItem(atPath destinationPath: String, withItemAtPath sourcePath: String) throws {
        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(atPath: destinationPath)
        }
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
    }

    private func tightenRootOwnership(atPath path: String, mode: String) throws {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/sbin/chown", arguments: ["root:wheel", path], allowFailure: true)
        _ = try? Shell.run("/bin/chmod", arguments: [mode, path], allowFailure: true)
    }
}
