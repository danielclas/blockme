import Foundation
import SwiftUI

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

    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var isRetrying = false
    @Published var isRunningMutation = false
    @Published var isAddingDomain = false
    @Published var banner: BannerData?
    @Published var addSheetPresented = false

    @Published private var blockedDomains: [String] = []
    @Published private var optimisticDomains: [String]?
    @Published private(set) var errorMessage: String?

    private let filterStore = FilterPreferenceStore()
    private let systemExtensionManager = SystemExtensionManager()
    private var refreshTask: Task<Void, Never>?

    init() {
        Task { await refreshStatus() }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.refreshStatus()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var mode: ViewMode {
        if let errorMessage, !errorMessage.isEmpty {
            return .error
        }
        if !isInstalled {
            return .install
        }
        return domains.isEmpty ? .empty : .active
    }

    var domains: [String] {
        optimisticDomains ?? blockedDomains
    }

    var errorDetailLabel: String {
        errorMessage ?? "The network filter is not active."
    }

    func refreshStatus() async {
        let extensionSnapshot = await systemExtensionManager.loadProperties(identifier: BlockmeIdentifiers.filterBundleIdentifier)

        do {
            let snapshot = try await filterStore.loadSnapshot()
            blockedDomains = snapshot.blockedDomains

            if let extensionSnapshot {
                if extensionSnapshot.isAwaitingApproval {
                    isInstalled = false
                    errorMessage = "Approve Blockme in System Settings > Privacy & Security to finish installing the network filter."
                    return
                }

                if extensionSnapshot.isUninstalling {
                    isInstalled = false
                    errorMessage = "The network filter is being removed by macOS."
                    return
                }

                if snapshot.isEnabled && extensionSnapshot.isEnabled {
                    isInstalled = true
                    errorMessage = nil
                } else if snapshot.isEnabled {
                    isInstalled = false
                    errorMessage = "The network filter is configured, but the system extension is not active yet."
                } else {
                    isInstalled = false
                    errorMessage = nil
                }
                return
            }

            isInstalled = false
            errorMessage = snapshot.isEnabled
                ? "The network filter is configured, but the system extension is not active."
                : nil
        } catch {
            isInstalled = false
            errorMessage = userFacingError(from: error)
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
                switch try await systemExtensionManager.activateExtension(identifier: BlockmeIdentifiers.filterBundleIdentifier) {
                case .activated:
                    try await filterStore.installOrUpdate(blockedDomains: domains)
                    await refreshStatus()
                    showBanner(.success, text: "Protection installed. The network filter is active.")

                case .needsApproval:
                    errorMessage = "Approve Blockme in System Settings > Privacy & Security, then click Install Protection again."
                    showBanner(.error, text: errorMessage ?? "System approval is required.")

                case .needsReboot:
                    errorMessage = "macOS will finish activating the network filter after a restart."
                    showBanner(.error, text: errorMessage ?? "A restart is required.")
                }
            } catch {
                errorMessage = userFacingError(from: error)
                showBanner(.error, text: errorMessage ?? "Installation failed.")
            }
        }
    }

    func retryConnection() {
        guard !isRetrying else { return }
        isRetrying = true

        Task {
            defer { isRetrying = false }
            await refreshStatus()
            if errorMessage == nil {
                showBanner(.success, text: "The network filter is active.")
            } else {
                showBanner(.error, text: errorMessage ?? "The network filter is still unavailable.")
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

            let updatedDomains = ([normalized] + domains).sorted()
            isRunningMutation = true
            isAddingDomain = true
            optimisticDomains = updatedDomains
            addSheetPresented = false

            Task {
                defer {
                    isRunningMutation = false
                    isAddingDomain = false
                }

                do {
                    try await filterStore.installOrUpdate(blockedDomains: updatedDomains)
                    optimisticDomains = nil
                    blockedDomains = updatedDomains
                    await refreshStatus()
                    showBanner(.success, text: "Added \(normalized). New requests will be blocked immediately.")
                } catch {
                    optimisticDomains = nil
                    await refreshStatus()
                    showBanner(.error, text: userFacingError(from: error))
                }
            }
        } catch {
            showBanner(.error, text: error.localizedDescription)
        }
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
            return "The system request was cancelled."
        }
        return rendered
    }
}
