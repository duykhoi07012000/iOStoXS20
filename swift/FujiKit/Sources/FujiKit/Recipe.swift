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
    func propertyWrites() throws -> [PropertyWrite] {
        var w: [PropertyWrite] = []
        func add(_ p: Prop, _ value: Int, _ t: PropType, _ label: String) {
            w.append(PropertyWrite(code: p.rawValue, value: value, type: t, label: label))
        }

        if let v = filmSimulation    { add(.filmSimulation, Int(v.rawValue), .u16, "FilmSim=\(v)") }
        if let v = grain             { add(.grain, Int(v.rawValue), .u16, "Grain=\(v)") }
        if let v = colorChromeEffect { add(.colorChromeFX, Int(v.rawValue), .u16, "ColorChromeFX=\(v)") }
        if let v = colorChromeBlue   { add(.colorChromeBlue, Int(v.rawValue), .u16, "ColorChromeBlue=\(v)") }
        if let v = noiseReduction    { add(.noiseReduction, Int(v.rawValue), .u16, "NR=\(v)") }
        if let v = dynamicRange      { add(.dynamicRange, Int(v.rawValue), .u16, "DR=\(v)") }
        if let v = whiteBalance {
            add(.whiteBalance, Int(v.rawValue), .u16, "WB=\(v)")
            // TODO: khi map được property code Kelvin, set wbKelvin ở đây (whiteBalance == .colorTemp).
        }

        if let v = highlightTone { add(.highlightTone, try clamp("highlightTone", Int((v*10).rounded()), -20...40), .i16, "Highlight=\(v)") }
        if let v = shadowTone    { add(.shadowTone,    try clamp("shadowTone",    Int((v*10).rounded()), -20...40), .i16, "Shadow=\(v)") }
        if let v = color         { add(.color,         try clamp("color",    v*10, -40...40), .i16, "Color=\(v)") }
        if let v = sharpness     { add(.sharpness,     try clamp("sharpness", v*10, -40...40), .i16, "Sharp=\(v)") }
        if let v = clarity       { add(.clarity,       try clamp("clarity",  v*10, -50...50), .i16, "Clarity=\(v)") }
        if let v = wbShiftRed    { add(.wbShiftRed,  try clamp("wbShiftRed",  v, -9...9), .i16, "WBShiftR=\(v)") }
        if let v = wbShiftBlue   { add(.wbShiftBlue, try clamp("wbShiftBlue", v, -9...9), .i16, "WBShiftB=\(v)") }

        return w
    }
}
