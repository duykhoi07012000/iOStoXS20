import Foundation
import FujiKit

/// Recipe nạp sẵn: đọc từ `recipes_bundled.json` (cào từ fujixweekly.com bằng
/// scrape_recipes.py, X-Trans IV — đúng cho X-S20). Nếu thiếu file thì dùng fallback 7 cái.
enum BundledRecipes {
    static let all: [Recipe] = loadFromBundle() ?? fallback

    private static func loadFromBundle() -> [Recipe]? {
        guard let url = Bundle.main.url(forResource: "recipes_bundled", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([RecipeSeed].self, from: data),
              !seeds.isEmpty else { return nil }
        return seeds.compactMap { $0.toRecipe() }
    }

    // Fallback (nếu chưa có JSON).
    private static var fallback: [Recipe] {
        [
            make("Kodachrome 64", .classicChrome, dr: .dr200, hl: 0, sh: 0, color: 2, sharp: 1,
                 clarity: 3, nr: .m4, grain: .weakSmall, ccFx: .strong, ccBlue: .weak, wb: .daylight, r: 2, b: -5),
            make("Classic Negative", .classicNeg, dr: .dr200, hl: 1, sh: 0, color: 3, sharp: 0,
                 clarity: 2, nr: .m4, grain: .weakLarge, ccFx: .weak, ccBlue: .weak, wb: .auto, r: 4, b: -4),
            make("CineStill 800T", .eterna, dr: .dr200, hl: -1, sh: 2, color: 4, sharp: -2,
                 clarity: -3, nr: .m4, grain: .strongLarge, ccFx: .off, ccBlue: .strong, wb: .colorTemp, r: 2, b: -4, kelvin: 3200),
        ]
    }

    static func make(_ name: String, _ film: FilmSimulation,
                     dr: DynamicRange? = nil, hl: Double? = nil, sh: Double? = nil,
                     color: Int? = nil, sharp: Int? = nil, clarity: Int? = nil,
                     nr: NoiseReduction? = nil, grain: GrainEffect? = nil,
                     ccFx: ColorChrome? = nil, ccBlue: ColorChrome? = nil,
                     wb: WhiteBalance? = nil, r: Int? = nil, b: Int? = nil, kelvin: Int? = nil) -> Recipe {
        var x = Recipe(name: name)
        x.author = "Fuji X Weekly"
        x.filmSimulation = film; x.dynamicRange = dr
        x.highlightTone = hl; x.shadowTone = sh
        x.color = color; x.sharpness = sharp; x.clarity = clarity
        x.noiseReduction = nr; x.grain = grain
        x.colorChromeEffect = ccFx; x.colorChromeBlue = ccBlue
        x.whiteBalance = wb; x.wbShiftRed = r; x.wbShiftBlue = b; x.wbKelvin = kelvin
        return x
    }
}

/// DTO khớp JSON cào (snake_case, enum là tên case dạng chuỗi).
private struct RecipeSeed: Decodable {
    var name: String?
    var author: String?
    var notes: [String: String]?
    var film_simulation: String?
    var grain: String?
    var color_chrome_effect: String?
    var color_chrome_blue: String?
    var noise_reduction: String?
    var dynamic_range: String?
    var white_balance: String?
    var wb_kelvin: Int?
    var highlight_tone: Double?
    var shadow_tone: Double?
    var color: Int?
    var sharpness: Int?
    var clarity: Int?
    var wb_shift_red: Int?
    var wb_shift_blue: Int?
    var sample_image: String?

    func toRecipe() -> Recipe? {
        guard let name, !name.isEmpty else { return nil }
        var r = Recipe(name: name)
        r.author = author
        r.notes = notes ?? [:]
        r.filmSimulation = byName(film_simulation)
        r.grain = byName(grain)
        r.colorChromeEffect = byName(color_chrome_effect)
        r.colorChromeBlue = byName(color_chrome_blue)
        r.noiseReduction = byName(noise_reduction)
        r.dynamicRange = byName(dynamic_range)
        r.whiteBalance = byName(white_balance)
        r.wbKelvin = wb_kelvin
        r.highlightTone = highlight_tone; r.shadowTone = shadow_tone
        r.color = color; r.sharpness = sharpness; r.clarity = clarity
        r.wbShiftRed = wb_shift_red; r.wbShiftBlue = wb_shift_blue
        r.sampleImageURL = sample_image
        return r
    }
}

/// Map tên case (chuỗi) → giá trị enum.
private func byName<T: CaseIterable>(_ name: String?) -> T? {
    guard let name else { return nil }
    return T.allCases.first { "\($0)" == name }
}
