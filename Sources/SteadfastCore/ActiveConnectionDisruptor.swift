import Darwin
import Foundation

public final class ActiveConnectionDisruptor {
    public init() {}

    public func remoteAddresses(forDomains domains: [String]) -> [String] {
        var addresses = Set<String>()
        for domain in domains {
            addresses.formUnion(remoteAddresses(for: domain))
        }
        return addresses.sorted()
    }

    public func remoteAddresses(for domain: String) -> [String] {
        var addresses = Set<String>()
        for hostname in DomainNormalizer.hostnamesToBlock(for: domain) {
            addresses.formUnion(resolve(hostname: hostname))
        }
        return addresses.sorted()
    }

    public func dropConnections(to remoteAddresses: [String]) {
        for arguments in Self.pfKillCommands(forRemoteAddresses: remoteAddresses) {
            _ = try? Shell.run("/sbin/pfctl", arguments: arguments, allowFailure: true)
        }
    }

    static func pfKillCommands(forRemoteAddresses remoteAddresses: [String]) -> [[String]] {
        uniqueRemoteAddresses(remoteAddresses).map { address in
            ["-k", sourceWildcard(forRemoteAddress: address), "-k", address]
        }
    }

    private static func sourceWildcard(forRemoteAddress address: String) -> String {
        address.contains(":") ? "::/0" : "0.0.0.0/0"
    }

    private static func uniqueRemoteAddresses(_ remoteAddresses: [String]) -> [String] {
        Array(Set(remoteAddresses)).sorted { lhs, rhs in
            let lhsIsIPv6 = lhs.contains(":")
            let rhsIsIPv6 = rhs.contains(":")
            if lhsIsIPv6 != rhsIsIPv6 {
                return !lhsIsIPv6
            }
            return lhs < rhs
        }
    }

    private func resolve(hostname: String) -> Set<String> {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: 0,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var resultPointer: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(hostname, nil, &hints, &resultPointer) == 0, let resultPointer else {
            return []
        }
        defer { freeaddrinfo(resultPointer) }

        var addresses = Set<String>()
        var cursor: UnsafeMutablePointer<addrinfo>? = resultPointer
        while let info = cursor?.pointee {
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                info.ai_addr,
                info.ai_addrlen,
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if status == 0 {
                let rawBytes = hostBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                let address = String(decoding: rawBytes, as: UTF8.self)
                if !address.isEmpty, address != "127.0.0.1", address != "::1" {
                    addresses.insert(address)
                }
            }

            cursor = info.ai_next
        }

        return addresses
    }
}
