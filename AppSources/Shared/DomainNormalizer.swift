import Foundation

enum DomainNormalizationError: Error, LocalizedError {
    case empty
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The domain is empty."
        case .invalid(let value):
            return "\"\(value)\" is not a valid hostname."
        }
    }
}

enum DomainNormalizer {
    static func normalize(_ rawValue: String) throws -> String {
        var candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            throw DomainNormalizationError.empty
        }

        if let url = URL(string: candidate), let host = url.host, !host.isEmpty {
            candidate = host
        } else if !candidate.contains("://"),
                  candidate.contains("/"),
                  let url = URL(string: "https://\(candidate)"),
                  let host = url.host,
                  !host.isEmpty {
            candidate = host
        }

        candidate = candidate.lowercased()
        while candidate.hasPrefix("*.") || candidate.hasPrefix(".") {
            candidate.removeFirst()
        }
        while candidate.hasSuffix(".") {
            candidate.removeLast()
        }

        guard !candidate.isEmpty else {
            throw DomainNormalizationError.empty
        }

        let labels = candidate.split(separator: ".")
        guard !labels.isEmpty else {
            throw DomainNormalizationError.invalid(rawValue)
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard !label.isEmpty, !label.hasPrefix("-"), !label.hasSuffix("-") else {
                throw DomainNormalizationError.invalid(rawValue)
            }

            guard label.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                throw DomainNormalizationError.invalid(rawValue)
            }
        }

        return candidate
    }
}
