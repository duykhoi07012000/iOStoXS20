import Foundation
import FujiKit

/// Lưu/đọc recipe vào JSON trong Documents. CRUD đơn giản (dùng từ main thread).
final class RecipeStore: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("recipes.json")
    }()

    init() {
        load()
        if recipes.isEmpty { recipes = Self.defaults; save() }
    }

    func add(_ r: Recipe) { recipes.insert(r, at: 0); save() }
    func update(_ r: Recipe) {
        if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r; save() }
    }
    func delete(_ r: Recipe) { recipes.removeAll { $0.id == r.id }; save() }
    func delete(at offsets: IndexSet) { recipes.remove(atOffsets: offsets); save() }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = list
    }
    private func save() {
        if let data = try? JSONEncoder().encode(recipes) { try? data.write(to: url) }
    }

    // Recipe mẫu ban đầu.
    static var defaults: [Recipe] {
        var cn = Recipe(name: "Classic Negative")
        cn.author = "Fuji X Weekly"
        cn.filmSimulation = .classicNeg; cn.grain = .weakSmall
        cn.colorChromeEffect = .strong; cn.colorChromeBlue = .weak
        cn.dynamicRange = .dr400; cn.highlightTone = 1.5; cn.shadowTone = 2.0
        cn.color = 4; cn.sharpness = 0; cn.clarity = 0; cn.noiseReduction = .m4
        cn.whiteBalance = .auto; cn.wbShiftRed = 2; cn.wbShiftBlue = -5

        var cine = Recipe(name: "CineStill 800T")
        cine.author = "Fuji X Weekly"
        cine.filmSimulation = .eterna; cine.grain = .strongLarge
        cine.colorChromeEffect = .off; cine.colorChromeBlue = .strong
        cine.whiteBalance = .colorTemp; cine.wbKelvin = 3200; cine.wbShiftRed = 2; cine.wbShiftBlue = -4
        cine.dynamicRange = .dr200; cine.highlightTone = -1; cine.shadowTone = 2
        cine.color = 4; cine.sharpness = -2; cine.clarity = -3; cine.noiseReduction = .m4

        return [cn, cine]
    }
}
