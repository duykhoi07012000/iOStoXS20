import Foundation

/// Parse text recipe kiểu Fuji X Weekly → Recipe. Port trung thực từ
/// prototype-python/fuji_xs20/recipe_parser.py (đã test 2 ca). Chịu được: tên recipe
/// trước film sim hoặc ở tiêu đề, film sim xuống dòng, decimal "+2,5", OCR "t1 Red"=+1,
/// nhiễu ký tự lạ, header ghép "NOISE REDUCTION/HIGH ISO NR".
public enum RecipeParser {

    // (alias CHÍNH XÁC sau chuẩn hoá, field). Thứ tự: cụ thể → chung.
    private static let headers: [([String], String)] = [
        (["FILM SIMULATION", "FILM SIM"], "film"),
        (["DYNAMIC RANGE", "D RANGE", "DR"], "dr"),
        (["GRAIN EFFECT", "GRAIN"], "grain"),
        (["COLOR CHROME EFFECT BLUE", "COLOR CHROME FX BLUE", "COLOR CHROME BLUE", "COLOUR CHROME FX BLUE"], "cc_blue"),
        (["COLOR CHROME EFFECT", "COLOR CHROME FX", "COLOR CHROME", "COLOUR CHROME"], "cc_effect"),
        (["WHITE BALANCE", "WB"], "wb"),
        (["HIGHLIGHT TONE", "HIGHLIGHT", "HIGH LIGHT"], "highlight"),
        (["SHADOW TONE", "SHADOW"], "shadow"),
        (["SHARPNESS", "SHARPENING"], "sharpness"),
        (["NOISE REDUCTION/HIGH ISO NR", "NOISE REDUCTION", "HIGH ISO NR", "NR"], "nr"),
        (["CLARITY"], "clarity"),
        (["COLOR", "COLOUR"], "color"),
        (["ISO"], "iso"),
        (["EXPOSURE COMPENSATION", "EXP COMPENSATION", "EXP. COMPENSATION", "EXP COMP", "EV"], "exp_comp"),
    ]

    private static let films: [(String, FilmSimulation)] = [
        ("ETERNA BLEACH BYPASS", .eternaBleachBypass), ("BLEACH BYPASS", .eternaBleachBypass),
        ("ETERNA CINEMA", .eterna), ("ETERNA", .eterna),
        ("CLASSIC NEGATIVE", .classicNeg), ("CLASSIC NEG", .classicNeg),
        ("NOSTALGIC NEGATIVE", .nostalgicNeg), ("NOSTALGIC NEG", .nostalgicNeg),
        ("CLASSIC CHROME", .classicChrome),
        ("PRO NEG HI", .proNegHi), ("PRO NEG. HI", .proNegHi), ("PRONEG HI", .proNegHi),
        ("PRO NEG STD", .proNegStd), ("PRO NEG. STD", .proNegStd),
        ("REALA ACE", .realaAce), ("REALA", .realaAce),
        ("ACROS+YE", .acrosYe), ("ACROS+R", .acrosR), ("ACROS+G", .acrosG), ("ACROS", .acros),
        ("MONOCHROME+YE", .monochromeYe), ("MONOCHROME+R", .monochromeR),
        ("MONOCHROME+G", .monochromeG), ("MONOCHROME", .monochrome),
        ("PROVIA/STANDARD", .provia), ("PROVIA", .provia), ("STANDARD", .provia),
        ("VELVIA/VIVID", .velvia), ("VELVIA", .velvia),
        ("ASTIA/SOFT", .astia), ("ASTIA", .astia),
        ("SEPIA", .sepia),
    ]

    private static let wbModes: [(String, WhiteBalance)] = [
        ("COLOR TEMPERATURE", .colorTemp), ("COLOUR TEMPERATURE", .colorTemp), ("KELVIN", .colorTemp),
        ("AUTO WHITE PRIORITY", .autoWhitePriority), ("WHITE PRIORITY", .autoWhitePriority),
        ("AUTO AMBIENCE", .autoAmbiencePriority), ("AMBIENCE", .autoAmbiencePriority),
        ("DAYLIGHT", .daylight), ("SHADE", .shade),
        ("INCANDESCENT", .incandescent), ("UNDERWATER", .underwater),
        ("FLUORESCENT 1", .fluorescent1), ("FLUORESCENT 2", .fluorescent2), ("FLUORESCENT 3", .fluorescent3),
        ("AUTO", .auto),
    ]

    private static let nrMap: [Int: NoiseReduction] = [
        -4: .m4, -3: .m3, -2: .m2, -1: .m1, 0: .std, 1: .p1, 2: .p2, 3: .p3, 4: .p4,
    ]

    // ---- helpers ----
    private static func norm(_ s: String) -> String {
        var t = s.precomposedStringWithCanonicalMapping.uppercased()
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix(":") || t.hasSuffix("：") { t.removeLast() }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func number(_ s: String) -> Double? {
        guard let m = firstMatch("[+-]?\\d+(?:[.,]\\d+)?", s) else { return nil }
        return Double(m.replacingOccurrences(of: ",", with: "."))
    }

    private static func firstMatch(_ pattern: String, _ s: String, group: Int = 0,
                                   caseInsensitive: Bool = false) -> String? {
        let opts: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return nil }
        let ns = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: ns), m.numberOfRanges > group,
              let r = Range(m.range(at: group), in: s) else { return nil }
        return String(s[r])
    }

    private static func matchHeader(_ line: String) -> String? {
        let n = norm(line)
        for (aliases, key) in headers where aliases.contains(n) { return key }
        return nil
    }

    /// Alias phẳng, sắp DÀI NHẤT trước (để "COLOR CHROME EFFECT BLUE" không bị "COLOR CHROME
    /// EFFECT" nuốt khi so tiền tố).
    private static let aliasesLongestFirst: [String] =
        headers.flatMap { $0.0 }.sorted { $0.count > $1.count }

    /// Dòng OCR kiểu CỘT "FILM SIMULATION Reala Ace" (nhãn + giá trị cùng dòng, KHÔNG dấu ':')
    /// → (header, value). Trả nil nếu dòng không mở đầu bằng header đã biết + theo sau là giá trị
    /// (vd "DR400" không có khoảng trắng → nil; "FILM SIMULATION" trơ trọi → nil để giữ format 2 dòng).
    public static func splitLeadingHeader(_ line: String) -> (header: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let n = norm(trimmed)
        for alias in aliasesLongestFirst {
            guard n != alias, n.hasPrefix(alias + " ") else { continue }
            let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            let headWords = alias.split(separator: " ").count
            guard words.count > headWords else { return nil }
            let value = words.dropFirst(headWords).joined(separator: " ")
            guard !value.isEmpty else { return nil }
            return (words.prefix(headWords).joined(separator: " "), value)
        }
        return nil
    }

    private static func cleanName(_ s: String) -> String {
        let ascii = String(s.unicodeScalars.filter { $0.isASCII || $0 == " " })
        return ascii.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–—:·"))
    }

    /// Tìm film sim trong 1 chuỗi (ưu tiên xuất hiện cuối). Trả (film, alias).
    private static func findFilm(_ text: String) -> (FilmSimulation, String)? {
        let n = norm(text)
        var best = -1
        var result: (FilmSimulation, String)?
        for (alias, film) in films {
            if let rng = n.range(of: alias, options: .backwards) {
                let pos = n.distance(from: n.startIndex, to: rng.lowerBound)
                if pos >= best { best = pos; result = (film, alias) }
            }
        }
        return result
    }

    /// Vị trí bắt đầu của lần khớp CUỐI của alias (whitespace linh hoạt) trong orig.
    private static func lastAliasStart(_ alias: String, in orig: String) -> String.Index? {
        let pat = alias.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
        guard let re = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return nil }
        let ns = NSRange(orig.startIndex..., in: orig)
        guard let last = re.matches(in: orig, range: ns).last, let rr = Range(last.range, in: orig) else { return nil }
        return rr.lowerBound
    }

    // ---- main ----
    public static func parse(_ text: String) -> Recipe {
        var sections: [String: [String]] = [:]
        var preamble: [String] = []
        var current: String?
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            // "Header: value" cùng dòng
            if let colon = line.firstIndex(of: ":") {
                let left = String(line[..<colon])
                let right = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if let k = matchHeader(left) {
                    if sections[k] == nil { sections[k] = [] }
                    if !right.isEmpty { sections[k]?.append(right) }
                    current = k
                    continue
                }
            }
            if let key = matchHeader(line) { current = key; sections[key] = sections[key] ?? [] }
            else if let c = current { sections[c, default: []].append(line) }
            else { preamble.append(line) }
        }

        var r = Recipe()

        // FILM + tên: thử section (format cũ), rồi preamble (format mới: tên + film sim đứng riêng)
        if let lines = sections["film"], let (film, alias) = findFilm(lines.joined(separator: " ")) {
            r.filmSimulation = film
            let orig = lines.joined(separator: " ")
            if let start = lastAliasStart(alias, in: orig) {
                let nm = cleanName(String(orig[orig.startIndex..<start]))
                if !nm.isEmpty { r.name = nm }
            }
        }
        if r.filmSimulation == nil, !preamble.isEmpty,
           let (film, alias) = findFilm(preamble.joined(separator: " ")) {
            r.filmSimulation = film
            let words = alias.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
            let nameLines = preamble.filter { firstMatch(words, $0, caseInsensitive: true) == nil }
            let nm = cleanName(nameLines.joined(separator: " "))
            if !nm.isEmpty { r.name = nm }
        }
        if r.name == "Untitled", !preamble.isEmpty {
            let nm = cleanName(preamble.joined(separator: " "))
            if !nm.isEmpty { r.name = nm }
        }

        // DR
        if let l = sections["dr"] {
            let t = norm(l.joined(separator: " "))
            if t.contains("AUTO") { r.dynamicRange = .auto }
            else if let d = number(t).map({ Int($0) }) {
                r.dynamicRange = [100: .dr100, 200: .dr200, 400: .dr400][d]
            }
        }
        // GRAIN
        if let l = sections["grain"] {
            let t = norm(l.joined(separator: " "))
            if t.contains("OFF") { r.grain = t.contains("LARGE") ? .offLarge : .off }
            else {
                let strong = t.contains("STRONG"), large = t.contains("LARGE")
                r.grain = strong ? (large ? .strongLarge : .strongSmall) : (large ? .weakLarge : .weakSmall)
            }
        }
        // COLOR CHROME
        func chrome(_ ls: [String]) -> ColorChrome {
            let t = norm(ls.joined(separator: " "))
            if t.contains("STRONG") { return .strong }
            if t.contains("WEAK") { return .weak }
            return .off
        }
        if let l = sections["cc_effect"] { r.colorChromeEffect = chrome(l) }
        if let l = sections["cc_blue"] { r.colorChromeBlue = chrome(l) }

        // WB
        if let l = sections["wb"] {
            let t = norm(l.joined(separator: " "))
            if let kStr = firstMatch("(\\d{4,5})\\s*K", t, group: 1), let k = Int(kStr) {
                r.wbKelvin = k; r.whiteBalance = .colorTemp
            } else {
                for (alias, mode) in wbModes where t.contains(alias) { r.whiteBalance = mode; break }
            }
            if let rs = firstMatch("([+-]?\\d+)\\s*RED", t, group: 1) ?? firstMatch("RED\\s*([+-]?\\d+)", t, group: 1) {
                r.wbShiftRed = Int(rs)
            }
            if let bs = firstMatch("([+-]?\\d+)\\s*BLUE", t, group: 1) ?? firstMatch("BLUE\\s*([+-]?\\d+)", t, group: 1) {
                r.wbShiftBlue = Int(bs)
            }
        }

        // tones / color / sharp / clarity
        if let l = sections["highlight"] { r.highlightTone = number(l.joined(separator: " ")) }
        if let l = sections["shadow"] { r.shadowTone = number(l.joined(separator: " ")) }
        if let l = sections["color"], let v = number(l.joined(separator: " ")) { r.color = Int(v) }
        if let l = sections["sharpness"], let v = number(l.joined(separator: " ")) { r.sharpness = Int(v) }
        if let l = sections["clarity"], let v = number(l.joined(separator: " ")) { r.clarity = Int(v) }

        // NR
        if let l = sections["nr"], let v = number(l.joined(separator: " ")) {
            r.noiseReduction = nrMap[Int(v)]
        }

        // notes
        if let l = sections["iso"] { r.notes["iso"] = l.joined(separator: " ") }
        if let l = sections["exp_comp"] { r.notes["exposure_compensation"] = l.joined(separator: " ") }

        return r
    }
}
