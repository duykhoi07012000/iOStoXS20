import Foundation
import Network

// Discovery "PCSS/1.0" — BẮT BUỘC để máy mở cổng PTP (xem docs/protocol-notes.md).
// PC mở TCP listener 51560, gửi UDP DISCOVERY tới cam:51562, máy nối ngược gửi NOTIFY
// (kèm DSCPORT), PC trả 200 OK.
enum PCSS {
    static let cameraUDPPort: UInt16 = 51562
    static let listenTCPPort: UInt16 = 51560

    struct DiscoveryResult { let dscIP: String; let dscPort: UInt16 }

    static func discover(cameraIP: String, localIP: String, timeout: TimeInterval = 8) async throws -> DiscoveryResult {
        let q = DispatchQueue(label: "fuji.pcss")
        let listener = try NWListener(using: .tcp, on: .init(rawValue: listenTCPPort)!)

        // Chờ kết nối NOTIFY từ máy, có timeout — một continuation, guard 'resumed' trên queue q.
        let incoming: TCPConn = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<TCPConn, Error>) in
            var resumed = false
            func finish(_ result: Result<TCPConn, Error>) {
                if resumed { return }
                resumed = true
                switch result {
                case .success(let c): cont.resume(returning: c)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
            listener.newConnectionHandler = { c in q.async { finish(.success(TCPConn(adopting: c))) } }
            listener.stateUpdateHandler = { st in
                if case .failed(let e) = st { q.async { finish(.failure(e)) } }
                if case .ready = st {
                    // listener đã lên → gửi DISCOVERY (UDP)
                    Task {
                        let msg = "DISCOVERY * HTTP/1.1\r\nHOST: \(localIP)\r\nMX: 5\r\nSERVICE: PCSS/1.0\r\n\u{0}"
                        try? await sendUDP(Data(msg.utf8), host: cameraIP, port: cameraUDPPort)
                    }
                }
            }
            q.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(FujiError.discoveryFailed(
                    "hết giờ chờ NOTIFY — máy ở tether standby (đèn cam)? Firewall cổng \(listenTCPPort)?")))
            }
            listener.start(queue: q)
        }
        listener.cancel()

        try await incoming.start()
        let notify = String(data: try await incoming.readSome(), encoding: .ascii) ?? ""
        var dscIP = cameraIP
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
