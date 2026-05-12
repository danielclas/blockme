import Foundation
import NetworkExtension

struct FilterSnapshot {
    let isEnabled: Bool
    let blockedDomains: [String]
}

@MainActor
final class FilterPreferenceStore {
    func loadSnapshot() async throws -> FilterSnapshot {
        let manager = try await loadedManager()
        let blockedDomains = BlockmeFilterConfiguration.blockedDomains(
            from: manager.providerConfiguration?.vendorConfiguration
        )

        return FilterSnapshot(
            isEnabled: manager.isEnabled,
            blockedDomains: blockedDomains
        )
    }

    func installOrUpdate(blockedDomains: [String]) async throws {
        let manager = try await loadedManager()
        let configuration = manager.providerConfiguration ?? NEFilterProviderConfiguration()
        configuration.filterSockets = true
        configuration.filterPackets = false
        configuration.filterDataProviderBundleIdentifier = BlockmeIdentifiers.filterBundleIdentifier
        configuration.vendorConfiguration = BlockmeFilterConfiguration.vendorConfiguration(for: blockedDomains)

        manager.localizedDescription = BlockmeFilterConfiguration.localizedDescription
        manager.providerConfiguration = configuration
        manager.isEnabled = true

        if #available(macOS 10.15, *) {
            manager.grade = .firewall
        }

        try await manager.saveToPreferences()
    }

    private func loadedManager() async throws -> NEFilterManager {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()
        return manager
    }
}
