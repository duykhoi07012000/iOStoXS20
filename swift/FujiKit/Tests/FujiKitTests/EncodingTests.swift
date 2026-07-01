import XCTest
@testable import FujiKit

// Đối chiếu byte với prototype-python đã chạy THẬT trên X-S20.
// Hex kỳ vọng lấy từ Python (docs/protocol-notes.md).
final class EncodingTests: XCTestCase {

    private func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    func testContainerOpenSession() {
        let d = PTPCodec.makeContainer(.command, code: 0x1002, tid: 1, data: PTPCodec.le32(1))
        XCTAssertEqual(hex(d), "10000000010002100100000001000000")
    }

    func testSetFilmSimCommandAndData() {
        let cmd = PTPCodec.makeContainer(.command, code: 0x1016, tid: 7, data: PTPCodec.le32(0xD001))
        XCTAssertEqual(hex(cmd), "10000000010016100700000001d00000")
        let data = PTPCodec.makeContainer(.data, code: 0x1016, tid: 7, data: PTPCodec.encodeValue(17, .u16))
        XCTAssertEqual(hex(data), "0e00000002001610070000001100")
    }

    func testValueEncoding() {
        XCTAssertEqual(hex(PTPCodec.encodeValue(0xD001, .u16)), "01d0")
        XCTAssertEqual(hex(PTPCodec.encodeValue(-5, .i16)), "fbff")
        XCTAssertEqual(hex(PTPCodec.encodeValue(20, .i16)), "1400")
    }

    func testClientIPField() {
        XCTAssertEqual(hex(PTPCodec.clientIPField("192.168.1.6")), "0601a8c0")
    }

    func testInitRequestMatchesCapture() {
        let guid = Data(hex: "f2e4538fada5485d87b27f0bd3d5ded0")
        let d = PTPCodec.makeInitRequest(guid: guid, clientIP: "192.168.1.6", name: "DESKTOP-SGP1R6M")
        XCTAssertEqual(d.count, 82)   // 4 len + 78 body
        XCTAssertEqual(hex(d),
          "5200000001000000f2e4538fada5485d87b27f0bd3d5ded00601a8c0" +
          "4400450053004b0054004f0050002d005300470050003100520036004d00" +
          "000000000000000000000000000000000000000000000000")
    }

    func testRecipeProducesExpectedWrites() throws {
        var r = Recipe()
        r.filmSimulation = .classicNeg
        r.noiseReduction = .m4
        r.dynamicRange = .dr400
        r.highlightTone = 1.5
        r.shadowTone = 2.0
        r.color = 4
        r.whiteBalance = .auto
        r.wbShiftRed = 2
        r.wbShiftBlue = -5
        let w = try r.propertyWrites()
        func find(_ code: UInt16) -> PropertyWrite? { w.first { $0.code == code } }

        XCTAssertEqual(find(0xD001)?.value, 17)      // Classic Neg
        XCTAssertEqual(find(0xD01C)?.value, 0x8000)  // NR -4
        XCTAssertEqual(find(0xD007)?.value, 400)     // DR400
        XCTAssertEqual(find(0xD320)?.value, 15)      // Highlight +1.5 (×10)
        XCTAssertEqual(find(0xD321)?.value, 20)      // Shadow +2.0
        XCTAssertEqual(find(0xD008)?.value, 40)      // Color +4
        XCTAssertEqual(find(0x5005)?.value, 2)       // WB Auto
        XCTAssertEqual(find(0xD00B)?.value, 2)       // WB shift R
        XCTAssertEqual(find(0xD00C)?.value, -5)      // WB shift B
        XCTAssertEqual(find(0xD00C)?.type, .i16)
    }

    func testRecipeRejectsOutOfRange() {
        var r = Recipe(); r.clarity = 99
        XCTAssertThrowsError(try r.propertyWrites())
    }
}
