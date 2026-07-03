import SwiftUI
import FujiKit

/// Màn chỉnh sửa recipe (giống docs_UI ảnh 2).
struct RecipeEditView: View {
    @Environment(\.dismiss) private var dismiss
    let original: Recipe
    let onSave: (Recipe) -> Void

    @State private var name: String
    @State private var film: FilmSimulation
    @State private var grainStrength: Int   // 0=off,1=weak,2=strong
    @State private var grainLarge: Bool
    @State private var ccEffect: ColorChrome
    @State private var ccBlue: ColorChrome
    @State private var wbType: WhiteBalance
    @State private var kelvin: Double
    @State private var wbRed: Int
    @State private var wbBlue: Int
    @State private var dr: DynamicRange
    @State private var highlight: Double
    @State private var shadow: Double
    @State private var colorV: Double
    @State private var sharp: Double
    @State private var clarity: Double
    @State private var nr: Double            // -4..+4

    private let nrMap: [Int: NoiseReduction] = [-4: .m4, -3: .m3, -2: .m2, -1: .m1, 0: .std, 1: .p1, 2: .p2, 3: .p3, 4: .p4]
    private let nrToInt: [NoiseReduction: Int] = [.m4: -4, .m3: -3, .m2: -2, .m1: -1, .std: 0, .p1: 1, .p2: 2, .p3: 3, .p4: 4]

    init(recipe: Recipe, onSave: @escaping (Recipe) -> Void) {
        self.original = recipe; self.onSave = onSave
        _name = State(initialValue: recipe.name)
        _film = State(initialValue: recipe.filmSimulation ?? .provia)
        let g = recipe.grain ?? .off
        _grainStrength = State(initialValue: [.off, .offLarge].contains(g) ? 0 : ([.weakSmall, .weakLarge].contains(g) ? 1 : 2))
        _grainLarge = State(initialValue: [.offLarge, .weakLarge, .strongLarge].contains(g))
        _ccEffect = State(initialValue: recipe.colorChromeEffect ?? .off)
        _ccBlue = State(initialValue: recipe.colorChromeBlue ?? .off)
        _wbType = State(initialValue: recipe.whiteBalance ?? .auto)
        _kelvin = State(initialValue: Double(recipe.wbKelvin ?? 5500))
        _wbRed = State(initialValue: recipe.wbShiftRed ?? 0)
        _wbBlue = State(initialValue: recipe.wbShiftBlue ?? 0)
        _dr = State(initialValue: recipe.dynamicRange ?? .auto)
        _highlight = State(initialValue: recipe.highlightTone ?? 0)
        _shadow = State(initialValue: recipe.shadowTone ?? 0)
        _colorV = State(initialValue: Double(recipe.color ?? 0))
        _sharp = State(initialValue: Double(recipe.sharpness ?? 0))
        _clarity = State(initialValue: Double(recipe.clarity ?? 0))
        _nr = State(initialValue: Double((recipe.noiseReduction.flatMap { [NoiseReduction.m4: -4, .m3: -3, .m2: -2, .m1: -1, .std: 0, .p1: 1, .p2: 2, .p3: 3, .p4: 4][$0] }) ?? 0))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TextField("Tên recipe", text: $name)
                    .font(Theme.mono(16, .bold)).foregroundColor(Theme.text)
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 16))

                card("FILM SIMULATION", "film") {
                    Menu {
                        ForEach(FilmSimulation.allCases, id: \.self) { f in
                            Button(f.display) { film = f }
                        }
                    } label: {
                        HStack { Text(film.display).font(Theme.mono(15, .semibold)); Spacer()
                            Image(systemName: "chevron.down") }
                        .foregroundColor(Theme.text).padding(.vertical, 6)
                    }
                }

                card("GRAIN EFFECT", "circle.grid.3x3.fill") {
                    SegmentedChoice(options: [(0, "OFF"), (1, "WEAK"), (2, "STRONG")], selection: $grainStrength)
                    SegmentedChoice(options: [(false, "SMALL"), (true, "LARGE")], selection: $grainLarge).padding(.top, 6)
                }

                HStack(spacing: 12) {
                    card("COLOR CHROME", "cloud.fill") {
                        SegmentedChoice(options: [(ColorChrome.off, "OFF"), (.weak, "WK"), (.strong, "ST")], selection: $ccEffect)
                    }
                    card("FX BLUE", "circle.fill") {
                        SegmentedChoice(options: [(ColorChrome.off, "OFF"), (.weak, "WK"), (.strong, "ST")], selection: $ccBlue)
                    }
                }

                card("WHITE BALANCE", "sun.max.fill") {
                    HStack(alignment: .top, spacing: 12) {
                        WBPad(red: $wbRed, blue: $wbBlue).frame(width: 150, height: 150)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("R:\(sign(wbRed))").foregroundColor(Theme.redShift)
                                Text("B:\(sign(wbBlue))").foregroundColor(Theme.blueShift) }
                                .font(Theme.mono(13, .bold))
                            Menu {
                                Button("Auto") { wbType = .auto }
                                Button("Daylight") { wbType = .daylight }
                                Button("Shade") { wbType = .shade }
                                Button("Incandescent") { wbType = .incandescent }
                                Button("Color temperature") { wbType = .colorTemp }
                            } label: {
                                HStack { Text(wbType.display).font(Theme.mono(13)); Image(systemName: "chevron.down") }
                                    .foregroundColor(Theme.text)
                            }
                            if wbType == .colorTemp {
                                Text("\(Int(kelvin))K").font(Theme.mono(14, .bold)).foregroundColor(Theme.text)
                                Slider(value: $kelvin, in: 2500...10000, step: 100).tint(Theme.active)
                            }
                        }
                    }
                }

                card("DYNAMIC RANGE", "camera.filters") {
                    SegmentedChoice(options: [(DynamicRange.auto, "AUTO"), (.dr100, "DR100"), (.dr200, "DR200"), (.dr400, "DR400")], selection: $dr)
                }

                HStack(spacing: 12) {
                    LabeledSlider(label: "HIGHLIGHT", icon: "circle.lefthalf.filled", value: $highlight, range: -2...4, step: 0.5) { fmt($0) }
                    LabeledSlider(label: "SHADOW", icon: "circle.righthalf.filled", value: $shadow, range: -2...4, step: 0.5) { fmt($0) }
                }
                HStack(spacing: 12) {
                    LabeledSlider(label: "COLOR", icon: "paintpalette.fill", value: $colorV, range: -4...4)
                    LabeledSlider(label: "SHARPNESS", icon: "triangle.fill", value: $sharp, range: -4...4)
                }
                HStack(spacing: 12) {
                    LabeledSlider(label: "CLARITY", icon: "triangle", value: $clarity, range: -5...5)
                    LabeledSlider(label: "NOISE REDUCTION", icon: "circle.dotted", value: $nr, range: -4...4)
                }
            }
            .padding()
        }
        .fujiBackground()
        .navigationTitle("Chỉnh sửa").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() }.tint(Theme.text) }
            ToolbarItem(placement: .confirmationAction) { Button("Lưu") { save() }.tint(Theme.text).bold() }
        }
    }

    private func sign(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }
    private func fmt(_ v: Double) -> String { (v > 0 ? "+" : "") + String(format: v == v.rounded() ? "%.1f" : "%.1f", v) }

    private func card<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { Image(systemName: icon); Text(title).font(Theme.mono(13, .bold)) }
                .foregroundColor(Theme.text)
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }

    private func save() {
        var r = original
        r.name = name.isEmpty ? "Untitled" : name
        r.filmSimulation = film
        let grainTable: [Int: GrainEffect] = grainLarge
            ? [0: .offLarge, 1: .weakLarge, 2: .strongLarge]
            : [0: .off, 1: .weakSmall, 2: .strongSmall]
        r.grain = grainTable[grainStrength]
        r.colorChromeEffect = ccEffect
        r.colorChromeBlue = ccBlue
        r.whiteBalance = wbType
        r.wbKelvin = wbType == .colorTemp ? Int(kelvin) : nil
        r.wbShiftRed = wbRed; r.wbShiftBlue = wbBlue
        r.dynamicRange = dr
        r.highlightTone = highlight; r.shadowTone = shadow
        r.color = Int(colorV); r.sharpness = Int(sharp); r.clarity = Int(clarity)
        r.noiseReduction = nrMap[Int(nr)]
        onSave(r)
        dismiss()
    }
}
