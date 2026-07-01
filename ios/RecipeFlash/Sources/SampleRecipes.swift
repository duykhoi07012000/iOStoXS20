import Foundation
import FujiKit

/// Recipe kèm id để hiển thị trong danh sách.
struct RecipeItem: Identifiable {
    let id = UUID()
    var recipe: Recipe
    var name: String { recipe.name }
}

enum SampleRecipes {
    static let all: [RecipeItem] = [classicNeg, kodakGold, acrosBW]

    static var classicNeg: RecipeItem {
        var r = Recipe(); r.name = "Classic Negative"
        r.filmSimulation = .classicNeg
        r.grain = .weakSmall
        r.colorChromeEffect = .strong
        r.colorChromeBlue = .weak
        r.dynamicRange = .dr400
        r.highlightTone = 1.5; r.shadowTone = 2.0
        r.color = 4; r.sharpness = 0; r.clarity = 0
        r.noiseReduction = .m4
        r.whiteBalance = .auto; r.wbShiftRed = 2; r.wbShiftBlue = -5
        return RecipeItem(recipe: r)
    }

    static var kodakGold: RecipeItem {
        var r = Recipe(); r.name = "Kodak Gold-ish"
        r.filmSimulation = .classicChrome
        r.grain = .weakSmall
        r.dynamicRange = .dr200
        r.highlightTone = 0.5; r.shadowTone = 1.0
        r.color = 2; r.sharpness = -1; r.clarity = -2
        r.noiseReduction = .m4
        r.whiteBalance = .daylight; r.wbShiftRed = 3; r.wbShiftBlue = -4
        return RecipeItem(recipe: r)
    }

    static var acrosBW: RecipeItem {
        var r = Recipe(); r.name = "ACROS B&W"
        r.filmSimulation = .acros
        r.grain = .strongLarge
        r.dynamicRange = .dr400
        r.highlightTone = 1.0; r.shadowTone = 2.0
        r.sharpness = 1; r.clarity = 3
        r.noiseReduction = .m2
        r.whiteBalance = .auto
        return RecipeItem(recipe: r)
    }
}
