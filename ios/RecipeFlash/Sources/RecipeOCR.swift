import Foundation
import Vision
import UIKit
import ImageIO
import FujiKit

/// OCR ảnh recipe (screenshot Fuji X Weekly…) → text kiểu 2 dòng cho `RecipeParser`.
/// Vision on-device (miễn phí, offline). Dựng lại thứ tự đọc từ bounding box, và tách dòng
/// cột "HEADER value" thành 2 dòng để parser bắt được.
enum RecipeOCR {

    /// Nhận diện text trong ảnh, trả chuỗi nhiều dòng (rỗng nếu không đọc được gì).
    static func recognize(_ image: UIImage) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: run(image))
            }
        }
    }

    private static func run(_ image: UIImage) -> String {
        guard let cg = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false   // giữ nguyên token: DR400, 5200K, +2, -3
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cg,
                                            orientation: CGImagePropertyOrientation(image.imageOrientation),
                                            options: [:])
        do { try handler.perform([request]) } catch { return "" }

        // (text, bbox) — bbox chuẩn hoá, gốc DƯỚI-TRÁI (y tăng lên trên).
        let items: [(text: String, box: CGRect)] = (request.results ?? []).compactMap { o in
            guard let s = o.topCandidates(1).first?.string, !s.isEmpty else { return nil }
            return (s, o.boundingBox)
        }
        guard !items.isEmpty else { return "" }

        // Gom HÀNG: sắp theo midY giảm (trên→dưới); cùng hàng khi lệch midY < ~0.6× chiều cao chữ.
        var rows: [[(text: String, box: CGRect)]] = []
        for it in items.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - it.box.midY) < max(it.box.height, anchor.box.height) * 0.6 {
                rows[rows.count - 1].append(it)
            } else {
                rows.append([it])
            }
        }

        // Trong hàng: trái→phải (minX tăng). Mỗi item 1 dòng; dòng gộp "HEADER value" tách đôi.
        var lines: [String] = []
        for row in rows {
            for it in row.sorted(by: { $0.box.minX < $1.box.minX }) {
                if let (header, value) = RecipeParser.splitLeadingHeader(it.text) {
                    lines.append(header)
                    lines.append(value)
                } else {
                    lines.append(it.text)
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension CGImagePropertyOrientation {
    init(_ ui: UIImage.Orientation) {
        switch ui {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
