import XCTest
@testable import FujiKit

final class ParserTests: XCTestCase {

    let copenhagen = """
    FILM SIMULATION
    の
    Copenhagen Negative
    Classic
    Negative
    DYNAMIC RANGE
    DR400
    GRAIN EFFECT
    Strong Small
    COLOR CHROME EFFECT
    Weak
    COLOR CHROME EFFECT BLUE
    Strong
    WB
    5700K, t1 Red & +1 Blue
    HIGHLIGHT
    +2,5
    SHADOW
    -2
    COLOR
    +4
    SHARPNESS
    -2
    NOISE REDUCTION/HIGH ISO NR
    -4
    CLARITY
    -3
    ISO
    up to ISO 6400
    EXPOSURE COMPENSATION
    0 to -2/3
    """

    func testCopenhagenNegative() {
        let r = RecipeParser.parse(copenhagen)
        XCTAssertEqual(r.name, "Copenhagen Negative")
        XCTAssertEqual(r.filmSimulation, .classicNeg)
        XCTAssertEqual(r.dynamicRange, .dr400)
        XCTAssertEqual(r.grain, .strongSmall)
        XCTAssertEqual(r.colorChromeEffect, .weak)
        XCTAssertEqual(r.colorChromeBlue, .strong)
        XCTAssertEqual(r.whiteBalance, .colorTemp)
        XCTAssertEqual(r.wbKelvin, 5700)
        XCTAssertEqual(r.wbShiftRed, 1)
        XCTAssertEqual(r.wbShiftBlue, 1)
        XCTAssertEqual(r.highlightTone, 2.5)
        XCTAssertEqual(r.shadowTone, -2)
        XCTAssertEqual(r.color, 4)
        XCTAssertEqual(r.sharpness, -2)
        XCTAssertEqual(r.clarity, -3)
        XCTAssertEqual(r.noiseReduction, .m4)
        XCTAssertEqual(r.notes["iso"], "up to ISO 6400")
        XCTAssertEqual(r.notes["exposure_compensation"], "0 to -2/3")
    }

    func testCineStillVariants() {
        let text = """
        CineStill 800T
        Film Simulation
        Eterna / Cinema
        Grain Effect
        Large / Strong
        Color Chrome Effect
        Off
        Color Chrome FX Blue
        Strong
        White Balance
        Color Temperature, +2 Red, -4 Blue
        Dynamic Range
        DR200
        Highlight
        -1
        Shadow
        +2
        Sharpness
        -2
        Noise Reduction
        -4
        Clarity
        -3
        """
        let r = RecipeParser.parse(text)
        XCTAssertEqual(r.name, "CineStill 800T")
        XCTAssertEqual(r.filmSimulation, .eterna)
        XCTAssertEqual(r.grain, .strongLarge)
        XCTAssertEqual(r.colorChromeEffect, .off)
        XCTAssertEqual(r.colorChromeBlue, .strong)
        XCTAssertEqual(r.whiteBalance, .colorTemp)
        XCTAssertEqual(r.wbShiftRed, 2)
        XCTAssertEqual(r.wbShiftBlue, -4)
        XCTAssertEqual(r.dynamicRange, .dr200)
    }
}
