import Darwin
import Foundation
import Testing
@testable import SteadfastCore

// MARK: - Domain normalization & matching

@Test func normalizesURLInput() throws {
    #expect(try DomainNormalizer.normalize("https://Instagram.com/reels") == "instagram.com")
    #expect(try DomainNormalizer.normalize("www.youtube.com") == "www.youtube.com")
}

@Test func rejectsInvalidHostnames() {
    #expect(throws: DomainNormalizationError.self) {
        try DomainNormalizer.normalize("not a domain")
    }
}

// MARK: - HostsManager (unchanged from prior version)

@Test func mergesManagedHostsSectionWithoutDuplicatingIt() {
    let paths = Paths(environment: ["STEADFAST_ROOT_PREFIX": "/tmp/steadfast-tests"])
    let initial = """
    127.0.0.1 localhost

    # user line
    10.0.0.1 internal.example
    """

    let once = HostsManager.mergedHostsContent(existingContent: initial, blockedDomains: ["instagram.com"], paths: paths)
    let twice = HostsManager.mergedHostsContent(existingContent: once, blockedDomains: ["instagram.com"], paths: paths)

    #expect(once == twice)
    #expect(once.contains("127.0.0.1 instagram.com"))
    #expect(once.contains("127.0.0.1 www.instagram.com"))
}

@Test func removingAllDomainsClearsManagedSection() {
    let paths = Paths(environment: ["STEADFAST_ROOT_PREFIX": "/tmp/steadfast-tests"])
    let initial = "127.0.0.1 localhost"

    let withManaged = HostsManager.mergedHostsContent(existingContent: initial, blockedDomains: ["instagram.com"], paths: paths)
    let cleared = HostsManager.mergedHostsContent(existingContent: withManaged, blockedDomains: [], paths: paths)

    #expect(!cleared.contains(paths.managedStartMarker))
    #expect(cleared.contains("127.0.0.1 localhost"))
}

// MARK: - Public status

@Test func publicStatusStoreRoundTrips() throws {
    let root = "/tmp/steadfast-tests-public-status"
    let paths = Paths(environment: ["STEADFAST_ROOT_PREFIX": root])
    let store = PublicStatusStore(paths: paths)
    let status = PublicStatus(
        blockedDomains: ["instagram.com"],
        lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        lastSuccessfulSyncAt: Date(timeIntervalSince1970: 1_700_000_001),
        lastHeartbeatAt: Date(timeIntervalSince1970: 1_700_000_002),
        lastErrorMessage: nil
    )

    try store.save(status)
    let loaded = try store.load()

    #expect(loaded.blockedDomains == ["instagram.com"])
    #expect(loaded.lastSuccessfulSyncAt == status.lastSuccessfulSyncAt)
    #expect(loaded.lastHeartbeatAt == status.lastHeartbeatAt)
}

// MARK: - ResolverDirectoryManager

@Test func resolverFileContentIsMarkedAndPointsAtStub() {
    let content = ResolverDirectoryManager.renderFileContent(stubAddress: "127.0.0.1", stubPort: 5454)
    #expect(content.hasPrefix(ResolverDirectoryManager.markerLine))
    #expect(content.contains("nameserver 127.0.0.1"))
    #expect(content.contains("port 5454"))
}

@Test func resolverManagerWritesAndRemovesFiles() throws {
    let root = "/tmp/steadfast-tests-resolver-\(UUID().uuidString)"
    let paths = Paths(environment: ["STEADFAST_ROOT_PREFIX": root])
    let manager = ResolverDirectoryManager(
        paths: paths,
        stubAddress: "127.0.0.1",
        stubPort: 5454,
        privateRelayHostnames: ["mask.icloud.com"],
        includePrivateRelay: true
    )

    let first = try manager.sync(blockedDomains: ["instagram.com", "linkedin.com"])
    #expect(Set(first.created) == ["instagram.com", "linkedin.com", "mask.icloud.com"])

    let expected = ResolverDirectoryManager.renderFileContent(stubAddress: "127.0.0.1", stubPort: 5454)
    let igPath = root + "/etc/resolver/instagram.com"
    let igContents = try String(contentsOfFile: igPath, encoding: .utf8)
    #expect(igContents == expected)

    // Re-sync with same set must be a no-op.
    let second = try manager.sync(blockedDomains: ["instagram.com", "linkedin.com"])
    #expect(!second.changed)

    // removeAllManagedFiles cleans only our files.
    let nonOursPath = root + "/etc/resolver/corporate.vpn"
    try Data("# someone else's config\nnameserver 10.0.0.1\n".utf8)
        .write(to: URL(fileURLWithPath: nonOursPath))

    let removed = try manager.removeAllManagedFiles()
    #expect(Set(removed) == ["instagram.com", "linkedin.com", "mask.icloud.com"])
    #expect(FileManager.default.fileExists(atPath: nonOursPath), "must not touch files without our marker")
    try? FileManager.default.removeItem(atPath: root)
}

@Test func resolverManagerSkipsPrivateRelayWhenDisabled() throws {
    let root = "/tmp/steadfast-tests-resolver-pr-\(UUID().uuidString)"
    let paths = Paths(environment: ["STEADFAST_ROOT_PREFIX": root])
    let manager = ResolverDirectoryManager(
        paths: paths,
        stubAddress: "127.0.0.1",
        stubPort: 5454,
        includePrivateRelay: false
    )

    let result = try manager.sync(blockedDomains: ["instagram.com"])
    #expect(result.created == ["instagram.com"])
    #expect(!FileManager.default.fileExists(atPath: root + "/etc/resolver/mask.icloud.com"))
    try? FileManager.default.removeItem(atPath: root)
}

// MARK: - NXDomainStub (live UDP)

@Test func nxDomainStubReturnsNXDOMAINOverRealUDP() throws {
    let port: UInt16 = 17_500
    let stub = NXDomainStub(listenAddress: "127.0.0.1", listenPort: port)
    try stub.start()
    defer { stub.stop() }
    Thread.sleep(forTimeInterval: 0.05)

    let queryPacket = makeDNSQuery(id: 0x4242, qname: "linkedin.com")
    let response = try sendUDPAndAwait(payload: queryPacket, host: "127.0.0.1", port: port, timeout: 1.5)

    let bytes = [UInt8](response)
    let id = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    let flags = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])

    #expect(id == 0x4242, "id must echo")
    #expect(flags & 0x000F == 3, "RCODE must be NXDOMAIN")
    #expect((flags >> 15) & 1 == 1, "QR bit must be set")
    #expect(bytes[6] == 0 && bytes[7] == 0, "no answer records")
}

@Test func flipToNXDomainSetsTheCorrectBits() {
    var bytes = [UInt8](makeDNSQuery(id: 0xCAFE, qname: "any.example"))
    NXDomainStub.flipToNXDomain(&bytes)
    let flags = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
    #expect((flags >> 15) & 1 == 1)
    #expect(flags & 0x000F == 3)
}

// MARK: - PF kill commands (kept; used for connection disruption on add)

@Test func pfKillCommandsTargetAllSourcesForEachRemoteAddress() {
    let commands = ActiveConnectionDisruptor.pfKillCommands(
        forRemoteAddresses: [
            "93.184.216.34",
            "2606:2800:220:1:248:1893:25c8:1946",
            "93.184.216.34",
        ]
    )

    #expect(commands == [
        ["-k", "0.0.0.0/0", "-k", "93.184.216.34"],
        ["-k", "::/0", "-k", "2606:2800:220:1:248:1893:25c8:1946"],
    ])
}

// MARK: - DNS test helpers

private struct UDPQueryError: Error, CustomStringConvertible {
    let description: String
}

private func sendUDPAndAwait(payload: Data, host: String, port: UInt16, timeout: TimeInterval) throws -> Data {
    let fd = socket(AF_INET, SOCK_DGRAM, 0)
    guard fd >= 0 else { throw UDPQueryError(description: "socket failed") }
    defer { close(fd) }

    var tv = timeval(
        tv_sec: Int(timeout.rounded(.down)),
        tv_usec: __darwin_suseconds_t((timeout - TimeInterval(Int(timeout))) * 1_000_000)
    )
    _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    var inAddr = in_addr()
    guard inet_pton(AF_INET, host, &inAddr) == 1 else {
        throw UDPQueryError(description: "inet_pton failed for \(host)")
    }
    addr.sin_addr = inAddr

    let sent = payload.withUnsafeBytes { rawBuf -> Int in
        withUnsafePointer(to: &addr) { addrPtr -> Int in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(fd, rawBuf.baseAddress, payload.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
    guard sent == payload.count else { throw UDPQueryError(description: "sendto returned \(sent)") }

    var buffer = [UInt8](repeating: 0, count: 4096)
    let n = buffer.withUnsafeMutableBufferPointer { bufPtr -> Int in
        recv(fd, bufPtr.baseAddress, bufPtr.count, 0)
    }
    guard n > 0 else { throw UDPQueryError(description: "recv timed out (n=\(n))") }
    return Data(buffer.prefix(n))
}

private func makeDNSQuery(id: UInt16, qname: String) -> Data {
    var bytes: [UInt8] = []
    bytes.append(UInt8((id >> 8) & 0xFF))
    bytes.append(UInt8(id & 0xFF))
    bytes.append(0x01)  // flags hi: standard query, RD=1
    bytes.append(0x00)  // flags lo
    bytes.append(0x00); bytes.append(0x01)  // QDCOUNT=1
    bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])  // counts=0
    for label in qname.split(separator: ".") {
        let ascii = Array(label.utf8)
        bytes.append(UInt8(ascii.count))
        bytes.append(contentsOf: ascii)
    }
    bytes.append(0x00)
    bytes.append(0x00); bytes.append(0x01)  // QTYPE=A
    bytes.append(0x00); bytes.append(0x01)  // QCLASS=IN
    return Data(bytes)
}
