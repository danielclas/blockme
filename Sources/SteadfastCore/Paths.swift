import Foundation

public struct Paths: Sendable {
    public let rootPrefix: String

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let configured = environment["STEADFAST_ROOT_PREFIX"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if configured == "/" {
            self.rootPrefix = ""
        } else {
            self.rootPrefix = configured.hasSuffix("/") ? String(configured.dropLast()) : configured
        }
    }

    public var isRedirectedRoot: Bool {
        !rootPrefix.isEmpty
    }

    public var launchDaemonLabel: String {
        "com.steadfast.daemon"
    }

    public var managedStartMarker: String {
        "# >>> steadfast managed blocklist >>>"
    }

    public var managedEndMarker: String {
        "# <<< steadfast managed blocklist <<<"
    }

    public var stateDirectoryPath: String {
        path("/Library/Application Support/Steadfast")
    }

    public var blocklistFilePath: String {
        path("/Library/Application Support/Steadfast/blocklist.json")
    }

    public var publicStatusDirectoryPath: String {
        path("/Library/Application Support/Blockme")
    }

    public var publicStatusFilePath: String {
        path("/Library/Application Support/Blockme/status.json")
    }

    public var resolverDirectoryPath: String {
        path("/etc/resolver")
    }

    public var launchDaemonPlistPath: String {
        path("/Library/LaunchDaemons/\(launchDaemonLabel).plist")
    }

    public var installedBinaryPath: String {
        path("/usr/local/libexec/steadfast/steadfast")
    }

    public var userFacingBinaryPath: String {
        path("/usr/local/bin/steadfast")
    }

    public var userFacingBlockmeBinaryPath: String {
        path("/usr/local/bin/blockme")
    }

    public var hostsFilePath: String {
        path("/etc/hosts")
    }

    public var logDirectoryPath: String {
        path("/Library/Logs/Steadfast")
    }

    private func path(_ absolutePath: String) -> String {
        guard !rootPrefix.isEmpty else { return absolutePath }
        return rootPrefix + absolutePath
    }
}

public struct RuntimeSettings: Sendable {
    public let useImmutableHosts: Bool
    public let daemonIntervalSeconds: TimeInterval
    public let stubListenAddress: String
    public let stubListenPort: UInt16
    public let includePrivateRelay: Bool

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        // Hardening is always on; there is no runtime switch to weaken it.
        self.useImmutableHosts = true
        self.includePrivateRelay = true

        if let value = environment["STEADFAST_DAEMON_INTERVAL_SECONDS"], let parsed = TimeInterval(value), parsed > 0 {
            self.daemonIntervalSeconds = parsed
        } else {
            self.daemonIntervalSeconds = 5
        }

        self.stubListenAddress = environment["STEADFAST_SERVICE_BIND_ADDRESS"] ?? "127.0.0.1"

        if let value = environment["STEADFAST_SERVICE_BIND_PORT"], let parsed = UInt16(value), parsed > 0 {
            self.stubListenPort = parsed
        } else {
            self.stubListenPort = 5454
        }
    }
}
