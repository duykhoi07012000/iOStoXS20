import Foundation
import Network

public enum FujiError: Error, CustomStringConvertible {
    case connectionClosed
    case discoveryFailed(String)
    case initFailed(UInt16)
    case ptp(String)
    case opFailed(UInt16, UInt16)   // (propcode, responsecode)

    public var description: String {
        switch self {
        case .connectionClosed: return "Kết nối đóng giữa chừng"
        case .discoveryFailed(let s): return "Discovery thất bại: \(s)"
        case .initFailed(let r): return String(format: "InitFail reason 0x%04X (GUID chưa pair? / máy bận?)", r)
        case .ptp(let s): return "PTP: \(s)"
        case let .opFailed(p, r): return String(format: "SetProp 0x%04X lỗi rc=0x%04X", p, r)
        }
    }
}

/// Cờ "chỉ kích 1 lần" an toàn luồng — để resume continuation đúng 1 lần từ các
/// callback @Sendable của Network.framework (tránh capture `var` trong closure).
final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

/// Bọc NWConnection theo kiểu async/await + đọc đúng số byte (cho framing PTP).
final class TCPConn: @unchecked Sendable {
    let conn: NWConnection
    private let queue = DispatchQueue(label: "fuji.tcp")

    init(host: String, port: UInt16) {
        conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .tcp)
    }
    init(adopting c: NWConnection) { conn = c }

    func start() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = OnceFlag()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: if once.fire() { cont.resume() }
                case .failed(let e): if once.fire() { cont.resume(throwing: e) }
                case .cancelled: if once.fire() { cont.resume(throwing: FujiError.connectionClosed) }
                default: break
                }
            }
            conn.start(queue: queue)
        }
        conn.stateUpdateHandler = nil
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { err in
                if let err = err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    /// Đọc CHÍNH XÁC n byte (dùng cho [len][payload] của PTP).
    func readExactly(_ n: Int) async throws -> Data {
        var buf = Data()
        while buf.count < n {
            let need = n - buf.count
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                conn.receive(minimumIncompleteLength: 1, maximumLength: need) { data, _, isDone, err in
                    if let err = err { cont.resume(throwing: err); return }
                    if let data = data, !data.isEmpty { cont.resume(returning: data); return }
                    cont.resume(throwing: FujiError.connectionClosed)
                }
            }
            buf.append(chunk)
        }
        return buf
    }

    /// Đọc vài byte có sẵn (dùng cho text NOTIFY độ dài không biết trước).
    func readSome(max: Int = 2048) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            conn.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, err in
                if let err = err { cont.resume(throwing: err); return }
                cont.resume(returning: data ?? Data())
            }
        }
    }

    /// Đọc 1 gói PTP: 4-byte length rồi (length-4) byte body.
    func readPacket() async throws -> Data {
        let lenData = try await readExactly(4)
        let b = [UInt8](lenData)
        let len = Int(UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24)
        guard len >= 4 else { throw FujiError.ptp("length bất thường \(len)") }
        return len > 4 ? try await readExactly(len - 4) : Data()
    }

    func cancel() { conn.cancel() }
}

/// Gửi 1 gói UDP tới host:port rồi đóng.
func sendUDP(_ data: Data, host: String, port: UInt16) async throws {
    let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .udp)
    let q = DispatchQueue(label: "fuji.udp")
    conn.start(queue: q)
    defer { conn.cancel() }
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        conn.send(content: data, completion: .contentProcessed { err in
            if let err = err { cont.resume(throwing: err) } else { cont.resume() }
        })
    }
}

/// IP IPv4 của thiết bị trên Wi-Fi (en0) — đưa vào HOST của DISCOVERY & clientIP của init.
func localIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let flags = Int32(ptr.pointee.ifa_flags)
        let addr = ptr.pointee.ifa_addr.pointee
        guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
              (flags & IFF_LOOPBACK) == 0,
              addr.sa_family == UInt8(AF_INET) else { continue }
        let name = String(cString: ptr.pointee.ifa_name)
        guard name == "en0" else { continue }        // Wi-Fi
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &host, socklen_t(host.count),
                       nil, 0, NI_NUMERICHOST) == 0 {
            address = String(cString: host)
        }
    }
    return address
}
