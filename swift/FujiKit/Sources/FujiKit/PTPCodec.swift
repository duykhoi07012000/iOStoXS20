import Foundation

// Đóng/mở gói PTP theo đúng byte layout đã kiểm chứng trên X-S20 (xem docs/protocol-notes.md).
// Khung gửi: [len u32 LE][payload], len = 4 + payload.count.
//  - Init (8-byte header): payload = [type u32][...]
//  - Container PTP-USB (12-byte header): payload = [type u16][code u16][tid u32][data]

enum PTPCodec {

    static let initCommandRequest: UInt32 = 0x0000_0001
    static let initCommandAck: UInt32     = 0x0000_0002
    static let initFail: UInt32           = 0x0000_0005

    // ---- little-endian appenders ----
    static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    /// Bọc payload bằng 4-byte length (bao gồm cả 4 byte length).
    static func framed(_ payload: Data) -> Data {
        le32(UInt32(4 + payload.count)) + payload
    }

    /// Giá trị property → 2 byte LE (u16 hoặc i16).
    static func encodeValue(_ value: Int, _ type: PropType) -> Data {
        switch type {
        case .u16: return le16(UInt16(truncatingIfNeeded: value))
        case .i16: return le16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)))
        }
    }

    /// 4 byte IP client (đảo octet — inet_aton đảo ngược), khớp capture (`0601a8c0`=192.168.1.6).
    static func clientIPField(_ ip: String) -> Data {
        let octets = ip.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return Data([0, 0, 0, 0]) }
        return Data(octets.reversed())
    }

    /// InitCommandRequest — body 78 byte:
    /// [type u32=1][GUID 16][clientIP 4][vùng-tên 54B = name UTF16LE NUL + đệm 0].
    static func makeInitRequest(guid: Data, clientIP: String, name: String) -> Data {
        var nameRegion = Data()
        nameRegion.append(name.data(using: .utf16LittleEndian) ?? Data())
        nameRegion.append(contentsOf: [0, 0])            // NUL terminator
        if nameRegion.count < 54 { nameRegion.append(Data(count: 54 - nameRegion.count)) }
        nameRegion = nameRegion.prefix(54)

        var body = le32(initCommandRequest)
        body.append(guid.prefix(16))
        body.append(clientIPField(clientIP))
        body.append(nameRegion)
        return framed(body)
    }

    /// Container PTP-USB (Command/Data/Response/Event).
    static func makeContainer(_ type: PTPContainerType, code: UInt16, tid: UInt32, data: Data = Data()) -> Data {
        var body = le16(type.rawValue)
        body.append(le16(code))
        body.append(le32(tid))
        body.append(data)
        return framed(body)
    }

    // ---- parse ----
    struct Container { let type: UInt16; let code: UInt16; let tid: UInt32; let payload: Data }

    /// Phân tích 1 body (đã bỏ 4-byte length) theo khung PTP-USB.
    static func parseContainer(_ body: Data) -> Container? {
        guard body.count >= 8 else { return nil }
        let b = [UInt8](body)
        let type = UInt16(b[0]) | UInt16(b[1]) << 8
        let code = UInt16(b[2]) | UInt16(b[3]) << 8
        let tid  = UInt32(b[4]) | UInt32(b[5]) << 8 | UInt32(b[6]) << 16 | UInt32(b[7]) << 24
        return Container(type: type, code: code, tid: tid, payload: body.count > 8 ? body.suffix(from: body.startIndex + 8) : Data())
    }

    /// Đọc u32 LE ở đầu body (dùng để phân biệt gói init: 1/2/5).
    static func leadingU32(_ body: Data) -> UInt32? {
        guard body.count >= 4 else { return nil }
        let b = [UInt8](body.prefix(4))
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }
}
