import Darwin
import Foundation

public enum ExitCode: Int32 {
    case success = 0
    case failure = 1
    case usage = 64
    case permissions = 77
}

public enum CLI {
    public static func run(arguments: [String]) -> ExitCode {
        let paths = Paths()
        let settings = RuntimeSettings()
        let store = BlocklistStore(paths: paths)
        let hostsManager = HostsManager(paths: paths, settings: settings)
        let publicStatusStore = PublicStatusStore(paths: paths)
        let resolverManager = ResolverDirectoryManager(
            paths: paths,
            stubAddress: settings.stubListenAddress,
            stubPort: settings.stubListenPort,
            includePrivateRelay: settings.includePrivateRelay
        )
        let launchdManager = LaunchdManager(
            paths: paths,
            store: store,
            hostsManager: hostsManager,
            publicStatusStore: publicStatusStore,
            resolverManager: resolverManager,
            settings: settings
        )
        let reporter = StatusReporter(blocklistStore: store, publicStatusStore: publicStatusStore)
        let connectionDisruptor = ActiveConnectionDisruptor()

        do {
            guard let command = arguments.dropFirst().first else {
                print(helpText())
                return .usage
            }

            switch command {
            case "help", "--help", "-h":
                print(helpText())
                return .success

            case "install":
                try requireRoot()
                let executablePath = try resolvedExecutablePath(from: arguments.first ?? CommandLine.arguments[0])
                try launchdManager.install(currentExecutablePath: executablePath)
                try reporter.writeHealthySnapshot()
                print("Installed Blockme. Use `sudo blockme add <domain>` to block a domain.")
                return .success

            case "uninstall":
                try requireRoot()
                try launchdManager.uninstall()
                try? reporter.deleteSnapshot()
                print("Removed Blockme and cleaned up all managed files.")
                return .success

            case "add":
                try requireRoot()
                let domains = Array(arguments.dropFirst(2))
                guard !domains.isEmpty else {
                    print("Missing domain.\n\n" + helpText())
                    return .usage
                }
                let normalizedDomains = try domains.map(DomainNormalizer.normalize)
                let liveRemoteAddresses = connectionDisruptor.remoteAddresses(forDomains: normalizedDomains)
                for normalized in normalizedDomains {
                    _ = try store.add(normalized)
                    print("Blocked \(normalized)")
                }
                let state = try store.load()
                _ = try resolverManager.sync(blockedDomains: state.blockedDomains)
                _ = try hostsManager.sync(blockedDomains: state.blockedDomains)
                flushDNSCacheIfNeeded(paths: paths)
                connectionDisruptor.dropConnections(to: liveRemoteAddresses)
                try reporter.writeHealthySnapshot()
                return .success

            case "list":
                try requireRoot()
                let state = try store.load()
                if state.blockedDomains.isEmpty {
                    print("No blocked domains.")
                } else {
                    for domain in state.blockedDomains {
                        print(domain)
                    }
                }
                return .success

            case "status":
                print("installed: \(launchdManager.isInstalled() ? "yes" : "no")")
                let publicStatus = try publicStatusStore.load()
                let blockedCount: Int
                if isRoot() {
                    blockedCount = try store.load().blockedDomains.count
                } else {
                    blockedCount = publicStatus.blockedDomains.count
                }
                print("blocked_domains: \(blockedCount)")
                printSnapshot(publicStatus)
                return .success

            case "sync":
                try requireRoot()
                let state = try store.load()
                _ = try resolverManager.sync(blockedDomains: state.blockedDomains)
                let hostsResult = try hostsManager.sync(blockedDomains: state.blockedDomains)
                flushDNSCacheIfNeeded(paths: paths)
                try reporter.writeHealthySnapshot()
                print(hostsResult.changed ? "Enforcement updated." : "Enforcement already in sync.")
                return .success

            case "reload-daemon":
                try requireRoot()
                try launchdManager.reloadDaemonIfNeeded()
                try reporter.writeHealthySnapshot()
                print("Background service restarted.")
                return .success

            case "daemon":
                try requireRoot()
                try runDaemonLoop(
                    paths: paths,
                    settings: settings,
                    store: store,
                    hostsManager: hostsManager,
                    resolverManager: resolverManager,
                    reporter: reporter
                )
                return .success

            default:
                print("Unknown command: \(command)\n\n" + helpText())
                return .usage
            }
        } catch CLIError.permissions(let message) {
            fputs(message + "\n", stderr)
            return .permissions
        } catch {
            fputs((error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription) + "\n", stderr)
            return .failure
        }
    }

    private static func runDaemonLoop(
        paths: Paths,
        settings: RuntimeSettings,
        store: BlocklistStore,
        hostsManager: HostsManager,
        resolverManager: ResolverDirectoryManager,
        reporter: StatusReporter
    ) throws {
        let stub = NXDomainStub(
            listenAddress: settings.stubListenAddress,
            listenPort: settings.stubListenPort
        )

        do {
            try stub.start()
        } catch {
            try? reporter.writeErrorSnapshot("stub failed to start: \(error.localizedDescription)")
            fputs("[steadfast daemon] stub failed to start: \(error.localizedDescription)\n", stderr)
            throw error
        }

        while true {
            do {
                let state = try store.load()
                _ = try resolverManager.sync(blockedDomains: state.blockedDomains)
                _ = try hostsManager.sync(blockedDomains: state.blockedDomains)

                if stub.isRunning {
                    try? reporter.writeHealthySnapshot()
                } else {
                    try? reporter.writeErrorSnapshot("stub stopped responding")
                }
            } catch {
                let message = renderedError(error)
                fputs("[steadfast daemon] \(message)\n", stderr)
                try? reporter.writeErrorSnapshot(message)
            }

            Thread.sleep(forTimeInterval: settings.daemonIntervalSeconds)
        }
    }

    private static func printSnapshot(_ publicStatus: PublicStatus) {
        if let heartbeat = publicStatus.lastHeartbeatAt {
            print("last_heartbeat_at: \(heartbeat.ISO8601Format())")
        }
        if let syncAt = publicStatus.lastSuccessfulSyncAt {
            print("last_successful_sync_at: \(syncAt.ISO8601Format())")
        }
        if let lastError = publicStatus.lastErrorMessage {
            print("last_error: \(lastError)")
        }
    }

    private static func flushDNSCacheIfNeeded(paths: Paths) {
        guard !paths.isRedirectedRoot else { return }
        _ = try? Shell.run("/usr/bin/dscacheutil", arguments: ["-flushcache"], allowFailure: true)
        _ = try? Shell.run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"], allowFailure: true)
    }

    private static func renderedError(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? String(describing: error) : message
    }

    private static func helpText() -> String {
        """
        blockme — a macOS domain blocker that is structurally fail-safe.

        Usage:
          blockme install
          blockme uninstall
          blockme add <domain> [domain...]
          blockme list
          blockme status
          blockme sync
          blockme reload-daemon

        Aliases:
          steadfast <command> ...

        Notes:
          - Append-only by design. The only way to unblock a domain is
            `sudo blockme uninstall`, which removes the entire installation.
          - Use sudo for install, add, list, sync, and reload-daemon.
          - Input can be a hostname or URL like https://instagram.com/reels.
          - Adding a domain blocks all of its subdomains automatically.
        """
    }

    private static func resolvedExecutablePath(from rawPath: String) throws -> String {
        let url = URL(fileURLWithPath: rawPath)
        return url.resolvingSymlinksInPath().path
    }

    private static func requireRoot() throws {
        guard isRoot() else {
            throw CLIError.permissions("This command needs admin privileges. Re-run it with sudo.")
        }
    }

    private static func isRoot() -> Bool {
        geteuid() == 0
    }
}

public enum CLIError: Error, LocalizedError {
    case permissions(String)

    public var errorDescription: String? {
        switch self {
        case .permissions(let message):
            return message
        }
    }
}
