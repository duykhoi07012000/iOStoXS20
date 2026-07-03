import Foundation
import Network

// Discovery "PCSS/1.0" — BẮT BUỘC để máy mở cổng PTP (xem docs/protocol-notes.md).
// PC mở TCP listener 51560, gửi UDP DISCOVERY tới cam:51562, máy nối ngược gửi NOTIFY
// (kèm DSCPORT), PC trả 200 OK.
enum PCSS {
    static let cameraUDPPort: UInt16 = 51562
    static let listenTCPPort: UInt16 = 51560

    struct DiscoveryResult { let dscIP: String; let dscPort: UInt16 }

    /// target = nil → broadcast tự dò máy (dùng khi không biết IP, vd hotspot).
    static func discover(target: String?, localIP: String, timeout: TimeInterval = 8) async throws -> DiscoveryResult {
        let q = DispatchQueue(label: "fuji.pcss")
        let listener = try NWListener(using: .tcp, on: .init(rawValue: listenTCPPort)!)

        // Chờ kết nối NOTIFY từ máy, có timeout — một continuation, guard 'resumed' trên queue q.
        let incoming: TCPConn = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<TCPConn, Error>) in
            let once = OnceFlag()
            listener.newConnectionHandler = { c in
                if once.fire() { cont.resume(returning: TCPConn(adopting: c)) }
            }
            listener.stateUpdateHandler = { st in
                switch st {
                case .failed(let e):
                    if once.fire() { cont.resume(throwing: e) }
                case .ready:
                    // listener đã lên → gửi DISCOVERY (UDP unicast nếu biết IP, không thì broadcast)
                    Task {
                        let msg = "DISCOVERY * HTTP/1.1\r\nHOST: \(localIP)\r\nMX: 5\r\nSERVICE: PCSS/1.0\r\n\u{0}"
                        let payload = Data(msg.utf8)
                        if let t = target { try? await sendUDP(payload, host: t, port: cameraUDPPort) }
                        else { sendUDPBroadcast(payload, port: cameraUDPPort) }
                    }
                default: break
                }
            }
            q.asyncAfter(deadline: .now() + timeout) {
                if once.fire() {
                    cont.resume(throwing: FujiError.discoveryFailed(
                        "hết giờ chờ NOTIFY — máy ở tether standby (đèn cam)? Firewall cổng \(listenTCPPort)?"))
                }
            }
            listener.start(queue: q)
        }
        listener.cancel()

        try await incoming.start()
        let notify = String(data: try await incoming.readSome(), encoding: .ascii) ?? ""
        var dscIP = target ?? ""
        var dscPort: UInt16 = 15740
        for line in notify.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0].uppercased() {
            case "DSCPORT": if let p = UInt16(parts[1]) { dscPort = p }
            case "DSC": if !parts[1].isEmpty { dscIP = parts[1] }
            default: break
            }
        }
        try await incoming.send(Data("HTTP/1.1 200 OK\r\n".utf8))
        incoming.cancel()
        return DiscoveryResult(dscIP: dscIP, dscPort: dscPort)
    }
}
