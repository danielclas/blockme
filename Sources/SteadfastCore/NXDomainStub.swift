import Darwin
import Foundation

/// A stateless UDP DNS server that returns NXDOMAIN for every query.
///
/// This is the *only* listener in the product. macOS's `/etc/resolver/<domain>`
/// files route only queries for blocked domains to it. Queries for any other
/// name never reach this code — they use the system's normal DNS path,
/// completely untouched. That structural isolation is the safety guarantee:
/// if this process crashes, only blocked-domain lookups are affected.
public final class NXDomainStub: @unchecked Sendable {
    public enum StubError: Error, LocalizedError {
        case socketCreationFailed(String)
        case bindFailed(String)

        public var errorDescription: String? {
            switch self {
            case .socketCreationFailed(let detail): return "stub socket() failed: \(detail)"
            case .bindFailed(let detail): return "stub bind() failed: \(detail)"
            }
        }
    }

    private let listenAddress: String
    private let listenPort: UInt16
    private let stateLock = NSLock()
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var running = false
    private let queue = DispatchQueue(label: "com.steadfast.stub", qos: .userInitiated)

    public init(listenAddress: String = "127.0.0.1", listenPort: UInt16 = 5454) {
        self.listenAddress = listenAddress
        self.listenPort = listenPort
    }

    public var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    public func start() throws {
        stateLock.lock()
        guard !running else { stateLock.unlock(); return }
        stateLock.unlock()

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else {
            throw StubError.socketCreationFailed(String(cString: strerror(errno)))
        }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = listenPort.bigEndian
        var inAddr = in_addr()
        guard inet_pton(AF_INET, listenAddress, &inAddr) == 1 else {
            close(fd)
            throw StubError.bindFailed("invalid address \(listenAddress)")
        }
        addr.sin_addr = inAddr

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            let detail = String(cString: strerror(errno))
            close(fd)
            throw StubError.bindFailed("\(listenAddress):\(listenPort) — \(detail)")
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.handleOne() }
        source.setCancelHandler { close(fd) }
        source.resume()

        stateLock.lock()
        socketFD = fd
        readSource = source
        running = true
        stateLock.unlock()
    }

    public func stop() {
        stateLock.lock()
        let source = readSource
        readSource = nil
        socketFD = -1
        running = false
        stateLock.unlock()
        source?.cancel()
    }

    private func handleOne() {
        stateLock.lock()
        let fd = socketFD
        stateLock.unlock()
        guard fd >= 0 else { return }

        var buffer = [UInt8](repeating: 0, count: 1500)
        var client = sockaddr_in()
        var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let n = withUnsafeMutablePointer(to: &client) { addrPtr -> Int in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                buffer.withUnsafeMutableBufferPointer { buf -> Int in
                    recvfrom(fd, buf.baseAddress, buf.count, 0, sa, &clientLen)
                }
            }
        }
        guard n >= 12 else { return }

        var response = [UInt8](buffer.prefix(n))
        Self.flipToNXDomain(&response)

        let savedClient = client
        let savedLen = clientLen
        _ = response.withUnsafeBufferPointer { buf -> Int in
            withUnsafePointer(to: savedClient) { addrPtr -> Int in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, buf.baseAddress, buf.count, 0, sa, savedLen)
                }
            }
        }
    }

    /// Mutates the DNS message header to convert a query into an NXDOMAIN
    /// response with no answer/authority/additional records. The question
    /// section is preserved verbatim, which is what RFC 1035 requires.
    public static func flipToNXDomain(_ bytes: inout [UInt8]) {
        guard bytes.count >= 12 else { return }
        let originalFlags = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        let opcode = originalFlags & 0x7800
        let rd = originalFlags & 0x0100
        let qrBit: UInt16 = 1 << 15
        let raBit: UInt16 = 1 << 7
        let rcodeNX: UInt16 = 3
        let newFlags = qrBit | opcode | rd | raBit | rcodeNX
        bytes[2] = UInt8((newFlags >> 8) & 0xFF)
        bytes[3] = UInt8(newFlags & 0xFF)
        bytes[6] = 0; bytes[7] = 0
        bytes[8] = 0; bytes[9] = 0
        bytes[10] = 0; bytes[11] = 0
    }
}
