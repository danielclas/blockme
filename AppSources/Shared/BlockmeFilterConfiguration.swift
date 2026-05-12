import Foundation

enum BlockmeIdentifiers {
    static let appBundleIdentifier = "local.steadfast.blockme"
    static let filterBundleIdentifier = "local.steadfast.blockme.filter"
    static let appGroupIdentifier = "$(TeamIdentifierPrefix)local.steadfast.blockme"
}

enum BlockmeFilterConfiguration {
    static let localizedDescription = "Blockme website filter"

    private static let schemaVersionKey = "schemaVersion"
    private static let blockedDomainsKey = "blockedDomains"
    private static let schemaVersion = 1

    static func vendorConfiguration(for domains: [String]) -> [String: Any] {
        [
            schemaVersionKey: schemaVersion,
            blockedDomainsKey: normalizedDomains(from: domains),
        ]
    }

    static func blockedDomains(from vendorConfiguration: [String: Any]?) -> [String] {
        guard let blockedDomains = vendorConfiguration?[blockedDomainsKey] as? [String] else {
            return []
        }

        return normalizedDomains(from: blockedDomains)
    }

    static func matches(host rawHost: String, blockedDomains: [String]) -> Bool {
        let host = normalizedHost(rawHost)
        guard !host.isEmpty else { return false }

        return blockedDomains.contains { blockedDomain in
            host == blockedDomain || host.hasSuffix(".\(blockedDomain)")
        }
    }

    private static func normalizedDomains(from rawDomains: [String]) -> [String] {
        Array(
            Set(
                rawDomains.compactMap {
                    try? DomainNormalizer.normalize($0)
                }
            )
        ).sorted()
    }

    private static func normalizedHost(_ rawHost: String) -> String {
        if let normalized = try? DomainNormalizer.normalize(rawHost) {
            return normalized
        }

        return rawHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
