import Foundation
import FujiKit

/// Recipe nạp sẵn (từ Fuji X Weekly, X-Trans IV — đúng cho X-S20). Giá trị đã chạy
/// qua RecipeParser để chuẩn hoá. Nguồn: fujixweekly.com.
enum BundledRecipes {
    static let all: [Recipe] = [
        make("Kodachrome 64", .classicChrome, dr: .dr200, hl: 0, sh: 0, color: 2, sharp: 1,
             clarity: 3, nr: .m4, grain: .weakSmall, ccFx: .strong, ccBlue: .weak, wb: .daylight, r: 2, b: -5),
        make("Kodak Portra 400", .classicChrome, dr: .auto, hl: -1, sh: -2, color: 2, sharp: -2,
             clarity: 2, nr: .m4, grain: .strongSmall, ccFx: .strong, ccBlue: .weak, wb: .daylight, r: 3, b: -5),
        make("Classic Negative", .classicNeg, dr: .dr200, hl: 1, sh: 0, color: 3, sharp: 0,
             clarity: 2, nr: .m4, grain: .weakLarge, ccFx: .weak, ccBlue: .weak, wb: .auto, r: 4, b: -4),
        make("Kodak Tri-X 400", .acros, dr: .dr200, hl: 0, sh: 3, color: nil, sharp: 1,
             clarity: 4, nr: .m4, grain: .strongLarge, ccFx: .strong, ccBlue: .off, wb: .daylight, r: 9, b: -9),
        make("Nostalgic Negative", .classicChrome, dr: .dr200, hl: -1, sh: 0, color: 4, sharp: 0,
             clarity: -5, nr: .m4, grain: .weakLarge, ccFx: .strong, ccBlue: .strong, wb: .auto, r: 3, b: -5),
        make("Fujicolor Superia 100", .classicNeg, dr: .auto, hl: -1, sh: -2, color: 1, sharp: -2,
             clarity: -2, nr: .m4, grain: .weakSmall, ccFx: .strong, ccBlue: .weak, wb: .daylight, r: 0, b: -1),
        make("CineStill 800T", .eterna, dr: .dr200, hl: -1, sh: 2, color: 4, sharp: -2,
             clarity: -3, nr: .m4, grain: .strongLarge, ccFx: .off, ccBlue: .strong, wb: .colorTemp, r: 2, b: -4, kelvin: 3200),
    ]

    static func make(_ name: String, _ film: FilmSimulation,
                     dr: DynamicRange? = nil, hl: Double? = nil, sh: Double? = nil,
                     color: Int? = nil, sharp: Int? = nil, clarity: Int? = nil,
                     nr: NoiseReduction? = nil, grain: GrainEffect? = nil,
                     ccFx: ColorChrome? = nil, ccBlue: ColorChrome? = nil,
                     wb: WhiteBalance? = nil, r: Int? = nil, b: Int? = nil, kelvin: Int? = nil) -> Recipe {
        var x = Recipe(name: name)
        x.author = "Fuji X Weekly"
        x.filmSimulation = film
        x.dynamicRange = dr
        x.highlightTone = hl; x.shadowTone = sh
        x.color = color; x.sharpness = sharp; x.clarity = clarity
        x.noiseReduction = nr; x.grain = grain
        x.colorChromeEffect = ccFx; x.colorChromeBlue = ccBlue
        x.whiteBalance = wb; x.wbShiftRed = r; x.wbShiftBlue = b; x.wbKelvin = kelvin
        x.notes["iso"] = "Auto, up to ISO 6400"
        return x
    }
}
