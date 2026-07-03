import SwiftUI
import FujiKit

// Chuỗi hiển thị + icon cho từng giá trị enum (để vẽ pill trong Detail view).

extension FilmSimulation {
    var display: String {
        switch self {
        case .provia: return "PROVIA/STD"; case .velvia: return "VELVIA"; case .astia: return "ASTIA"
        case .proNegHi: return "PRO NEG HI"; case .proNegStd: return "PRO NEG STD"
        case .monochrome: return "MONOCHROME"; case .monochromeYe: return "MONOCHROME+Ye"
        case .monochromeR: return "MONOCHROME+R"; case .monochromeG: return "MONOCHROME+G"
        case .sepia: return "SEPIA"; case .classicChrome: return "CLASSIC CHROME"
        case .acros: return "ACROS"; case .acrosYe: return "ACROS+Ye"; case .acrosR: return "ACROS+R"
        case .acrosG: return "ACROS+G"; case .eterna: return "ETERNA"; case .classicNeg: return "CLASSIC NEG"
        case .eternaBleachBypass: return "BLEACH BYPASS"; case .nostalgicNeg: return "NOSTALGIC NEG"
        case .realaAce: return "REALA ACE"
        }
    }
}

extension GrainEffect {
    var display: String {
        switch self {
        case .off: return "OFF"; case .offLarge: return "OFF / LARGE"
        case .weakSmall: return "SMALL / WEAK"; case .strongSmall: return "SMALL / STRONG"
        case .weakLarge: return "LARGE / WEAK"; case .strongLarge: return "LARGE / STRONG"
        }
    }
}

extension ColorChrome {
    var display: String { self == .off ? "OFF" : (self == .weak ? "WEAK" : "STRONG") }
}

extension DynamicRange {
    var display: String {
        switch self { case .auto: return "AUTO"; case .dr100: return "DR100"
        case .dr200: return "DR200"; case .dr400: return "DR400" }
    }
}

extension NoiseReduction {
    var display: String {
        switch self { case .p4: return "+4"; case .p3: return "+3"; case .p2: return "+2"; case .p1: return "+1"
        case .std: return "0"; case .m1: return "-1"; case .m2: return "-2"; case .m3: return "-3"; case .m4: return "-4" }
    }
}

extension WhiteBalance {
    var display: String {
        switch self {
        case .auto: return "AUTO"; case .autoWhitePriority: return "AUTO WHITE"
        case .autoAmbiencePriority: return "AUTO AMBIENCE"; case .daylight: return "DAYLIGHT"
        case .incandescent: return "INCANDESCENT"; case .underwater: return "UNDERWATER"
        case .fluorescent1: return "FLUOR 1"; case .fluorescent2: return "FLUOR 2"; case .fluorescent3: return "FLUOR 3"
        case .shade: return "SHADE"; case .colorTemp: return "COLOR TEMP"
        case .custom1: return "CUSTOM 1"; case .custom2: return "CUSTOM 2"; case .custom3: return "CUSTOM 3"
        }
    }
}

/// Một dòng hiển thị trong Detail: nhãn + icon (SF Symbol) + text giá trị.
struct DisplayRow: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let value: String
}

enum RecipeRows {
    static func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }
    static func signed(_ v: Double) -> String {
        let s = (v == v.rounded()) ? String(format: "%.1f", v) : String(v)
        return v > 0 ? "+\(s)" : s
    }

    /// Danh sách các dòng chính (film sim, grain, chrome, WB, DR) — kiểu ảnh 1.
    static func primary(_ r: Recipe) -> [DisplayRow] {
        var rows: [DisplayRow] = []
        if let v = r.filmSimulation { rows.append(.init(label: "Film Simulation", icon: "camera.aperture", value: v.display)) }
        if let v = r.grain { rows.append(.init(label: "Grain Effect", icon: "circle.grid.3x3.fill", value: v.display)) }
        if let v = r.colorChromeEffect { rows.append(.init(label: "Color Chrome Effect", icon: "cloud.fill", value: v.display)) }
        if let v = r.colorChromeBlue { rows.append(.init(label: "Color Chrome FX Blue", icon: "circle.fill", value: v.display)) }
        if let wb = r.whiteBalance {
            var s = wb.display
            if wb == .colorTemp, let k = r.wbKelvin { s = "\(k)K" }
            if let rr = r.wbShiftRed { s += ", \(signed(rr)) R" }
            if let bb = r.wbShiftBlue { s += " \(signed(bb)) B" }
            rows.append(.init(label: "White Balance", icon: "sun.max.fill", value: s))
        }
        if let v = r.dynamicRange { rows.append(.init(label: "Dynamic Range", icon: "camera.filters", value: v.display)) }
        return rows
    }

    /// Các dòng số theo cặp (highlight/shadow, color/sharp, NR/clarity) — kiểu ảnh 1.
    static func pairs(_ r: Recipe) -> [(DisplayRow?, DisplayRow?)] {
        var out: [(DisplayRow?, DisplayRow?)] = []
        func row(_ label: String, _ icon: String, _ text: String?) -> DisplayRow? {
            text.map { DisplayRow(label: label, icon: icon, value: $0) }
        }
        out.append((row("Highlight", "circle.lefthalf.filled", r.highlightTone.map { signed($0) }),
                    row("Shadow", "circle.righthalf.filled", r.shadowTone.map { signed($0) })))
        out.append((row("Color", "paintpalette.fill", r.color.map { signed($0) }),
                    row("Sharpness", "triangle.fill", r.sharpness.map { signed($0) })))
        out.append((row("Noise Reduction", "circle.dotted", r.noiseReduction?.display),
                    row("Clarity", "triangle", r.clarity.map { signed($0) })))
        return out.filter { $0.0 != nil || $0.1 != nil }
    }
}
