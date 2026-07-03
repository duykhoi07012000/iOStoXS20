import Foundation

/// Client cấp cao đẩy film recipe xuống X-S20 (port trung thực từ prototype-python).
public final class FujiCamera {
    let cameraIP: String?      // nil → tự dò máy bằng broadcast (du lịch/hotspot)
    let guid: Data
    let clientName: String
    private var tcp: TCPConn?
    private var tid: UInt32 = 0

    /// - cameraIP: nil → broadcast tự tìm máy (không cần biết IP).
    /// - guidHex: GUID đã "pair" với máy (hex 32 ký tự). Hiện dùng identity Tether App;
    ///   pairing GUID riêng cho app = việc Phase 3.
    public init(cameraIP: String? = nil,
                guidHex: String = "f2e4538fada5485d87b27f0bd3d5ded0",
                clientName: String = "DESKTOP-SGP1R6M") {
        self.cameraIP = cameraIP
        self.guid = Data(hex: guidHex)
        self.clientName = clientName
    }

    public func connect() async throws {
        let localIP = localIPAddress() ?? "0.0.0.0"
        let res = try await PCSS.discover(target: cameraIP, localIP: localIP)

        let tcp = TCPConn(host: res.dscIP, port: res.dscPort)
        try await tcp.start()
        self.tcp = tcp

        // InitCommandRequest + retry (máy thường InitFail 0x2019 lần đầu → Ack lần sau)
        let initReq = PTPCodec.makeInitRequest(guid: guid, clientIP: localIP, name: clientName)
        var lastFail: UInt16 = 0
        var acked = false
        for _ in 0..<5 {
            try await tcp.send(initReq)
            let resp = try await tcp.readPacket()
            let type = PTPCodec.leadingU32(resp) ?? 0
            if type == PTPCodec.initCommandAck { acked = true; break }
            if type == PTPCodec.initFail {
                lastFail = UInt16(truncatingIfNeeded: PTPCodec.leadingU32(resp.suffix(from: resp.startIndex + 4)) ?? 0)
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
        guard acked else { await close(); throw FujiError.initFailed(lastFail) }
        try await openSession()
    }

    private func nextTID() -> UInt32 { tid += 1; return tid }

    @discardableResult
    private func transact(_ op: PTPOp, params: [UInt32] = [], dataOut: Data? = nil) async throws -> (rc: UInt16, data: Data) {
        guard let tcp = tcp else { throw FujiError.ptp("chưa kết nối") }
        let t = nextTID()
        var pbytes = Data(); for p in params { pbytes.append(PTPCodec.le32(p)) }
        try await tcp.send(PTPCodec.makeContainer(.command, code: op.rawValue, tid: t, data: pbytes))
        if let dataOut = dataOut {
            try await tcp.send(PTPCodec.makeContainer(.data, code: op.rawValue, tid: t, data: dataOut))
        }
        var inData = Data()
        for _ in 0..<50 {
            let body = try await tcp.readPacket()
            guard let c = PTPCodec.parseContainer(body) else { continue }
            if c.type == PTPContainerType.response.rawValue { return (c.code, inData) }
            if c.type == PTPContainerType.data.rawValue { inData.append(c.payload) }
            // event: bỏ qua
        }
        throw FujiError.ptp("không nhận được Response")
    }

    private func openSession() async throws {
        let (rc, _) = try await transact(.openSession, params: [1])
        guard rc == PTP_RC_OK || rc == 0x201E else { throw FujiError.ptp(String(format: "OpenSession rc=0x%04X", rc)) }
    }

    /// Ghi 1 property. Trả response code (0x2001 = OK).
    @discardableResult
    public func setProp(_ code: UInt16, value: Int, type: PropType) async throws -> UInt16 {
        let (rc, _) = try await transact(.setDevicePropValue, params: [UInt32(code)],
                                         dataOut: PTPCodec.encodeValue(value, type))
        return rc
    }

    /// Áp cả recipe. Trả danh sách (mô tả, thành công?).
    @discardableResult
    public func apply(_ recipe: Recipe) async throws -> [(label: String, ok: Bool)] {
        var results: [(String, Bool)] = []
        for w in try recipe.propertyWrites() {
            let rc = try await setProp(w.code, value: w.value, type: w.type)
            results.append((w.label, rc == PTP_RC_OK))
        }
        return results
    }

    public func close() async {
        if tcp != nil {
            _ = try? await transact(.closeSession)
            tcp?.cancel()
            tcp = nil
        }
    }
}

extension Data {
    init(hex: String) {
        var d = Data(capacity: hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex, let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) {
            if let b = UInt8(hex[idx..<next], radix: 16) { d.append(b) }
            idx = next
        }
        self = d
    }
}
