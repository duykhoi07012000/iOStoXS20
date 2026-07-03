import SwiftUI

/// Pill giá trị (icon + text mono) kiểu ảnh 1.
struct ValuePill: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13))
            Text(text).font(Theme.mono(14, .medium))
        }
        .foregroundColor(Theme.text)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.pill, in: Capsule())
    }
}

/// Segmented control kiểu Fuji (pill nâu cho mục chọn).
struct SegmentedChoice<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                let value = options[i].0
                let on = value == selection
                Text(options[i].1)
                    .font(Theme.mono(13, on ? .bold : .regular))
                    .foregroundColor(on ? Theme.bg : Theme.textSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(on ? Theme.active : .clear, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { selection = value }
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
    }
}

/// Card có slider + nhãn + giá trị kiểu ảnh 2.
struct LabeledSlider: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { v in v > 0 ? "+\(Int(v))" : "\(Int(v))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(Theme.mono(13, .semibold))
                Spacer()
                Text(format(value)).font(Theme.mono(14, .bold))
            }
            .foregroundColor(Theme.text)
            Slider(value: $value, in: range, step: step)
                .tint(Theme.active)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Bảng WB 2D: kéo để chỉnh Red (ngang) & Blue (dọc), mỗi trục -9..+9.
struct WBPad: View {
    @Binding var red: Int
    @Binding var blue: Int
    private let rangeF = 9.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cx = size / 2, cy = size / 2
            let px = cx + CGFloat(red) / rangeF * (size/2 - 12)
            let py = cy - CGFloat(blue) / rangeF * (size/2 - 12)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Theme.bg)
                RoundedRectangle(cornerRadius: 14).stroke(Theme.card, lineWidth: 2)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: cy)); p.addLine(to: CGPoint(x: size, y: cy))
                    p.move(to: CGPoint(x: cx, y: 0)); p.addLine(to: CGPoint(x: cx, y: size))
                }.stroke(Theme.card, lineWidth: 1)
                Text("R").font(Theme.mono(11, .bold)).foregroundColor(Theme.redShift)
                    .position(x: size - 12, y: cy)
                Text("B").font(Theme.mono(11, .bold)).foregroundColor(Theme.blueShift)
                    .position(x: 12, y: cy)
                Circle().fill(Theme.active).frame(width: 16, height: 16).position(x: px, y: py)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let nr = Int(((g.location.x - cx) / (size/2 - 12) * rangeF).rounded())
                let nb = Int((-(g.location.y - cy) / (size/2 - 12) * rangeF).rounded())
                red = min(9, max(-9, nr)); blue = min(9, max(-9, nb))
            })
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
