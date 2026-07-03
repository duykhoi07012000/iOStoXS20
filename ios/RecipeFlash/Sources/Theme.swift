import SwiftUI

/// Bảng màu + font kiểu Fuji X Weekly (nền kem, pill amber, nút cam, chữ nâu).
enum Theme {
    static let bg        = Color(red: 0.98, green: 0.95, blue: 0.89)   // nền kem
    static let card      = Color(red: 0.97, green: 0.90, blue: 0.75)   // card/pill amber nhạt
    static let pill      = Color(red: 0.96, green: 0.86, blue: 0.63)   // pill giá trị
    static let active    = Color(red: 0.42, green: 0.30, blue: 0.12)   // nâu đậm (chọn)
    static let accent    = Color(red: 0.95, green: 0.64, blue: 0.19)   // nút cam
    static let text      = Color(red: 0.24, green: 0.17, blue: 0.08)   // chữ nâu đậm
    static let textSoft  = Color(red: 0.47, green: 0.37, blue: 0.24)
    static let redShift  = Color(red: 0.82, green: 0.31, blue: 0.28)
    static let blueShift = Color(red: 0.27, green: 0.55, blue: 0.85)

    static func mono(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func title(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
}

extension View {
    /// Nền kem toàn màn.
    func fujiBackground() -> some View {
        self.background(Theme.bg.ignoresSafeArea())
    }
}
