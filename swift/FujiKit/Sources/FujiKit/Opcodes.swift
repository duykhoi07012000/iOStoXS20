import Foundation

// Wire property codes + value enums cho X-S20, giải mã từ capture thật & xác nhận
// bằng đọc-ngược trên máy. Đối chiếu docs/protocol-notes.md. Giá trị KHỚP enum SDK.

enum PTPOp: UInt16 {
    case getDeviceInfo      = 0x1001
    case openSession        = 0x1002
    case closeSession       = 0x1003
    case getDevicePropValue = 0x1015
    case setDevicePropValue = 0x1016
}

enum PTPContainerType: UInt16 {
    case command  = 1
    case data     = 2
    case response = 3
    case event    = 4
}

let PTP_RC_OK: UInt16 = 0x2001

// Property code wire (đã xác nhận đẩy [OK] + đọc-ngược khớp trên X-S20).
enum Prop: UInt16 {
    case filmSimulation   = 0xD001
    case grain            = 0xD023
    case colorChromeFX    = 0xD029   // Color Chrome Effect
    case colorChromeBlue  = 0xD030
    case noiseReduction   = 0xD01C
    case dynamicRange     = 0xD007
    case whiteBalance     = 0x5005
    case wbShiftRed       = 0xD00B
    case wbShiftBlue      = 0xD00C
    case highlightTone    = 0xD320
    case shadowTone       = 0xD321
    case color            = 0xD008
    case sharpness        = 0x5015
    case clarity          = 0xD032
}

// Kiểu dữ liệu value truyền qua PTP (khớp datatype máy trả trong GetDevicePropDesc).
public enum PropType { case u16, i16 }

public enum FilmSimulation: UInt16, Codable, CaseIterable {
    case provia = 1, velvia = 2, astia = 3, proNegHi = 4, proNegStd = 5
    case monochrome = 6, monochromeYe = 7, monochromeR = 8, monochromeG = 9
    case sepia = 10, classicChrome = 11
    case acros = 0x0C, acrosYe = 0x0D, acrosR = 0x0E, acrosG = 0x0F
    case eterna = 0x10, classicNeg = 0x11, eternaBleachBypass = 0x12
    case nostalgicNeg = 0x13, realaAce = 0x14
}

public enum GrainEffect: UInt16, Codable {
    case off = 1, weakSmall = 2, strongSmall = 3
    case weakLarge = 4, strongLarge = 5, offLarge = 7
}

public enum ColorChrome: UInt16, Codable {   // dùng chung Effect & Blue
    case off = 1, weak = 2, strong = 3
}

public enum NoiseReduction: UInt16, Codable {
    case p4 = 0x5000, p3 = 0x6000, p2 = 0x0000, p1 = 0x1000, std = 0x2000
    case m1 = 0x3000, m2 = 0x4000, m3 = 0x7000, m4 = 0x8000
}

public enum DynamicRange: UInt16, Codable {   // X-S20: không có DR800
    case auto = 0xFFFF, dr100 = 100, dr200 = 200, dr400 = 400
}

public enum WhiteBalance: UInt16, Codable {
    case auto = 0x0002, autoWhitePriority = 0x8020, autoAmbiencePriority = 0x8021
    case daylight = 0x0004, incandescent = 0x0006, underwater = 0x0008
    case fluorescent1 = 0x8001, fluorescent2 = 0x8002, fluorescent3 = 0x8003
    case shade = 0x8006, colorTemp = 0x8007
    case custom1 = 0x8008, custom2 = 0x8009, custom3 = 0x800A
}
