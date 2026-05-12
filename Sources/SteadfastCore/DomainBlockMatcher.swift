import Foundation

public struct DomainBlockMatcher: Sendable {
    private let blockedDomains: Set<String>

    public init(blockedDomains: [String]) {
        self.blockedDomains = Set(blockedDomains.compactMap { try? DomainNormalizer.normalize($0) })
    }

    public func matches(hostname rawHostname: String) -> Bool {
        let candidate = normalizedHost(rawHostname)
        guard let candidate else { return false }

        if blockedDomains.contains(candidate) {
            return true
        }

        return blockedDomains.contains { blocked in
            candidate.count > blocked.count &&
            candidate.hasSuffix("." + blocked)
        }
    }

    private func normalizedHost(_ rawHostname: String) -> String? {
        var hostname = rawHostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hostname.hasPrefix("[") && hostname.hasSuffix("]") {
            hostname.removeFirst()
            hostname.removeLast()
        }

        return try? DomainNormalizer.normalize(hostname)
    }
}
