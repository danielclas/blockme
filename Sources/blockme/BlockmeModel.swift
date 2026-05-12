import Foundation
import SteadfastCore

@MainActor
final class BlockmeModel: ObservableObject {
    enum ViewMode {
        case install
        case active
        case empty
        case error
    }

    struct BannerData: Identifiable {
        enum Tone {
            case success
            case error
        }

        let id = UUID()
        let tone: Tone
        let text: String
    }

    @Published var publicStatus = PublicStatus()
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var isRetrying = false
    @Published var isRunningMutation = false
    @Published var isAddingDomain = false
    @Published private var optimisticDomains: [String]?
    @Published var banner: BannerData?
    @Published var addSheetPresented = false

    private let paths = Paths()
    private let publicStatusStore = PublicStatusStore()
    private var refreshTask: Task<Void, Never>?

    init() {
        refreshStatus()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.refreshStatus()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var mode: ViewMode {
        if !isInstalled {
            return .install
        }
        if hasServiceError {
            return .error
        }
        return domains.isEmpty ? .empty : .active
    }

    var domains: [String] {
        optimisticDomains ?? publicStatus.blockedDomains
    }

    var accentHex: String {
        switch mode {
        case .install:
            return "#0a84ff"
        case .active, .empty:
            return "#34c759"
        case .error:
            return "#ff3b30"
        }
    }

    var errorDetailLabel: String {
        if let lastError = publicStatus.lastErrorMessage, !lastError.isEmpty {
            return lastError
        }
        return "Last contact \(relativeTimeString(for: publicStatus.lastHeartbeatAt))"
    }

    func refreshStatus() {
        let fileManager = FileManager.default
        isInstalled = fileManager.fileExists(atPath: paths.launchDaemonPlistPath)
            && fileManager.fileExists(atPath: paths.installedBinaryPath)
        guard isInstalled else {
            publicStatus = PublicStatus()
            return
        }

        do {
            publicStatus = try publicStatusStore.load()
        } catch {
            publicStatus = PublicStatus(lastErrorMessage: nil)
        }
    }

    func dismissBanner() {
        banner = nil
    }

    func installProtection() {
        guard !isInstalling else { return }
        isInstalling = true

        Task {
            defer { isInstalling = false }

            do {
                try await runPrivilegedSelf(arguments: ["install"])
                optimisticDomains = nil
                refreshStatus()
                showBanner(.success, text: "Protection installed and active.")
            } catch {
                showBanner(.error, text: userFacingError(from: error))
            }
        }
    }

    func retryConnection() {
        guard !isRetrying else { return }
        isRetrying = true

        Task {
            defer { isRetrying = false }

            do {
                try await runPrivilegedSelf(arguments: ["reload-daemon"])
                refreshStatus()
                showBanner(.success, text: "Reconnected to background service.")
            } catch {
                showBanner(.error, text: userFacingError(from: error))
            }
        }
    }

    func reinstallProtection() {
        installProtection()
    }

    func addDomain(_ rawDomain: String) {
        guard !isRunningMutation else { return }

        do {
            let normalized = try DomainNormalizer.normalize(rawDomain)
            guard !domains.contains(normalized) else {
                showBanner(.error, text: "\(normalized) is already in your blocklist.")
                return
            }

            isRunningMutation = true
            isAddingDomain = true
            optimisticDomains = [normalized] + domains
            addSheetPresented = false
            Task {
                defer {
                    isRunningMutation = false
                    isAddingDomain = false
                }

                do {
                    try await runPrivilegedSelf(arguments: ["add", normalized])
                    optimisticDomains = nil
                    refreshStatus()
                    showBanner(.success, text: "Added \(normalized). Blocking is now in effect.")
                } catch {
                    optimisticDomains = nil
                    refreshStatus()
                    showBanner(.error, text: userFacingError(from: error))
                }
            }
        } catch {
            showBanner(.error, text: error.localizedDescription)
        }
    }

    private var hasServiceError: Bool {
        guard isInstalled else { return false }
        if let lastError = publicStatus.lastErrorMessage, !lastError.isEmpty {
            return true
        }
        guard let heartbeat = publicStatus.lastHeartbeatAt else {
            return true
        }
        return Date().timeIntervalSince(heartbeat) > 15
    }

    private func authenticateAdminSession() async throws {
        try await runAppleScriptPrivilegedCommand(command: "/usr/bin/true")
    }

    private func runPrivilegedSelf(arguments: [String]) async throws {
        let executablePath = resolvePrivilegedExecutablePath()
        guard let executablePath else {
            throw DesktopCommandError.missingExecutable
        }

        let command = ([Self.shellQuote(executablePath)] + arguments.map(Self.shellQuote)).joined(separator: " ")
        try await runAppleScriptPrivilegedCommand(command: command)
    }

    private func runAppleScriptPrivilegedCommand(command: String) async throws {
        let script = "do shell script \(Self.appleScriptLiteral(command)) with administrator privileges"
        _ = try await runDetached {
            try Shell.run("/usr/bin/osascript", arguments: ["-e", script])
        }
    }

    private func runDetached<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    private func relativeTimeString(for date: Date?) -> String {
        guard let date else { return "never" }
        let interval = max(0, Int(Date().timeIntervalSince(date)))
        if interval < 60 {
            return "\(interval)s ago"
        }
        if interval < 3600 {
            return "\(interval / 60)m ago"
        }
        if interval < 86_400 {
            return "\(interval / 3600)h ago"
        }
        return "\(interval / 86_400)d ago"
    }

    private func showBanner(_ tone: BannerData.Tone, text: String) {
        banner = BannerData(tone: tone, text: text)

        Task {
            try? await Task.sleep(for: .seconds(3))
            guard banner?.text == text else { return }
            banner = nil
        }
    }

    private func userFacingError(from error: Error) -> String {
        let rendered = error.localizedDescription
        if rendered.contains("User canceled") || rendered.contains("(-128)") {
            return "Authentication was cancelled."
        }
        return rendered
    }

    private static func shellQuote(_ raw: String) -> String {
        if raw.isEmpty {
            return "''"
        }
        return "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptLiteral(_ raw: String) -> String {
        "\"" + raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        + "\""
    }

    private func resolvePrivilegedExecutablePath() -> String? {
        if let bundledExecutable = Bundle.main.executableURL?.resolvingSymlinksInPath().path,
           FileManager.default.isExecutableFile(atPath: bundledExecutable) {
            return bundledExecutable
        }

        if FileManager.default.isExecutableFile(atPath: paths.installedBinaryPath) {
            return paths.installedBinaryPath
        }

        return nil
    }
}

enum DesktopCommandError: Error, LocalizedError {
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "The app executable could not be resolved."
        }
    }
}
