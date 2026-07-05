import Foundation

/// Một lệnh SetDevicePropValue đã sẵn sàng gửi.
struct PropertyWrite {
    let code: UInt16
    let value: Int
    let type: PropType
    let label: String
}

public enum RecipeError: Error, CustomStringConvertible {
    case outOfRange(String, Int, ClosedRange<Int>)
    public var description: String {
        switch self {
        case let .outOfRange(name, v, r): return "\(name)=\(v) ngoài dải \(r.lowerBound)...\(r.upperBound)"
        }
    }
}

/// Film recipe. Chỉ trường được set (khác nil) mới sinh lệnh ghi → áp một phần được.
/// Codable + Identifiable để lưu vào máy và hiển thị danh sách.
public struct Recipe: Codable, Identifiable {
    public var id = UUID()
    public var name: String = "Untitled"
    public var author: String?
    /// Ghi chú hiển thị (ISO, exposure compensation…) — KHÔNG flash xuống máy.
    public var notes: [String: String] = [:]
    /// URL ảnh mẫu (Fuji X Weekly) để xem trước — app tải lazy, KHÔNG nhúng vào .ipa.
    public var sampleImageURL: String?

    public var filmSimulation: FilmSimulation?
    public var grain: GrainEffect?
    public var colorChromeEffect: ColorChrome?
    public var colorChromeBlue: ColorChrome?
    public var noiseReduction: NoiseReduction?
    public var dynamicRange: DynamicRange?
    public var whiteBalance: WhiteBalance?
    public var wbKelvin: Int?             // khi whiteBalance == .colorTemp

    public var highlightTone: Double?     // -2.0 ... +4.0 (bước 0.5)
    public var shadowTone: Double?
    public var color: Int?                // -4 ... +4
    public var sharpness: Int?            // -4 ... +4 (X-S20)
    public var clarity: Int?              // -5 ... +5
    public var wbShiftRed: Int?           // -9 ... +9
    public var wbShiftBlue: Int?

    public init(name: String = "Untitled") { self.name = name }

    public var displayName: String {
        if name != "Untitled", !name.isEmpty { return name }
        if let f = filmSimulation { return "\(f)" }
        return "Untitled"
    }

    private func clamp(_ n: String, _ v: Int, _ r: ClosedRange<Int>) throws -> Int {
        guard r.contains(v) else { throw RecipeError.outOfRange(n, v, r) }
        return v
    }

    /// Chuỗi lệnh ghi theo thứ tự an toàn. Ném lỗi nếu giá trị ngoài dải.
    /// - fullReset: field == nil sẽ được ghi giá trị TRUNG TÍNH (0/OFF/Auto) để không "dính"
    ///   thông số recipe áp trước đó (máy X-S20 sticky). Film Sim không có "off" nên nil thì bỏ qua.
    /// - target: áp cho ẢNH hay VIDEO (video dùng property code riêng; field video không có sẽ bị bỏ).
    func propertyWrites(fullReset: Bool = false, target: RecipeTarget = .photo) throws -> [PropertyWrite] {
        var w: [PropertyWrite] = []
        func add(_ p: Prop, _ value: Int, _ t: PropType, _ label: String) {
            guard let c = p.code(for: target) else { return }   // video không có field này → bỏ
            w.append(PropertyWrite(code: c, value: value, type: t, label: label))
        }

        if let v = filmSimulation    { add(.filmSimulation, Int(v.rawValue), .u16, "FilmSim=\(v)") }
        // Film Sim: không có giá trị "off" → nil thì bỏ qua, kể cả khi fullReset.

        if let v = grain             { add(.grain, Int(v.rawValue), .u16, "Grain=\(v)") }
        else if fullReset            { add(.grain, Int(GrainEffect.off.rawValue), .u16, "Grain=off↺") }
        if let v = colorChromeEffect { add(.colorChromeFX, Int(v.rawValue), .u16, "ColorChromeFX=\(v)") }
        else if fullReset            { add(.colorChromeFX, Int(ColorChrome.off.rawValue), .u16, "ColorChromeFX=off↺") }
        if let v = colorChromeBlue   { add(.colorChromeBlue, Int(v.rawValue), .u16, "ColorChromeBlue=\(v)") }
        else if fullReset            { add(.colorChromeBlue, Int(ColorChrome.off.rawValue), .u16, "ColorChromeBlue=off↺") }
        if let v = noiseReduction    { add(.noiseReduction, Int(v.rawValue), .u16, "NR=\(v)") }
        else if fullReset            { add(.noiseReduction, Int(NoiseReduction.std.rawValue), .u16, "NR=std↺") }
        if let v = dynamicRange {
            if !(target == .video && v == .auto) {              // video KHÔNG set được DR-Auto
                add(.dynamicRange, Int(v.rawValue), .u16, "DR=\(v)")
            }
        } else if fullReset, target == .photo {                 // video không có DR trung tính → bỏ
            add(.dynamicRange, Int(DynamicRange.auto.rawValue), .u16, "DR=auto↺")
        }
        if let v = whiteBalance {
            add(.whiteBalance, Int(v.rawValue), .u16, "WB=\(v)")
            if v == .colorTemp, let k = wbKelvin {
                add(.wbKelvin, k, .u16, "Kelvin=\(k)K")
            }
        } else if fullReset {
            add(.whiteBalance, Int(WhiteBalance.auto.rawValue), .u16, "WB=auto↺")
        }

        if let v = highlightTone { add(.highlightTone, try clamp("highlightTone", Int((v*10).rounded()), -20...40), .i16, "Highlight=\(v)") }
        else if fullReset        { add(.highlightTone, 0, .i16, "Highlight=0↺") }
        if let v = shadowTone    { add(.shadowTone,    try clamp("shadowTone",    Int((v*10).rounded()), -20...40), .i16, "Shadow=\(v)") }
        else if fullReset        { add(.shadowTone, 0, .i16, "Shadow=0↺") }
        if let v = color         { add(.color,         try clamp("color",    v*10, -40...40), .i16, "Color=\(v)") }
        else if fullReset        { add(.color, 0, .i16, "Color=0↺") }
        if let v = sharpness     { add(.sharpness,     try clamp("sharpness", v*10, -40...40), .i16, "Sharp=\(v)") }
        else if fullReset        { add(.sharpness, 0, .i16, "Sharp=0↺") }
        if let v = clarity       { add(.clarity,       try clamp("clarity",  v*10, -50...50), .i16, "Clarity=\(v)") }
        else if fullReset        { add(.clarity, 0, .i16, "Clarity=0↺") }
        if let v = wbShiftRed    { add(.wbShiftRed,  try clamp("wbShiftRed",  v, -9...9), .i16, "WBShiftR=\(v)") }
        else if fullReset        { add(.wbShiftRed, 0, .i16, "WBShiftR=0↺") }
        if let v = wbShiftBlue   { add(.wbShiftBlue, try clamp("wbShiftBlue", v, -9...9), .i16, "WBShiftB=\(v)") }
        else if fullReset        { add(.wbShiftBlue, 0, .i16, "WBShiftB=0↺") }

        return w
    }
}
