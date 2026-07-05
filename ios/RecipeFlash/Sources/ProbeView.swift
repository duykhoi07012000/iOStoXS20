import SwiftUI
import UIKit
import FujiKit

/// Công cụ dò property code (để tìm code miền VIDEO — xem docs/protocol-notes.md).
/// Quy trình: Chụp A → đổi TAY 1 thông số trên máy (Movie mode) → Chụp B → Diff ra code vừa đổi.
struct ProbeView: View {
    @AppStorage("cameraIP") private var cameraIP = ""
    @State private var snapA: [UInt16: String] = [:]
    @State private var snapB: [UInt16: String] = [:]
    @State private var status = "Bấm \"Chụp A\", rồi đổi TAY 1 thông số trên máy (đang ở Movie mode), rồi bấm \"Chụp B\"."
    @State private var busy = false

    // Dải code quét: 0xD000–0xD3FF (vendor Fuji) + 0x5005–0x501F (chuẩn PTP hay dùng).
    private var candidates: [UInt16] {
        Array(UInt16(0xD000)...UInt16(0xD3FF)) + Array(UInt16(0x5000)...UInt16(0x501F))
    }

    private struct DiffRow: Identifiable {
        let id: UInt16
        let before: String
        let after: String
        var code: UInt16 { id }
    }

    private var diff: [DiffRow] {
        snapB.keys.compactMap { c -> DiffRow? in
            let after = snapB[c] ?? ""
            let before = snapA[c] ?? "—"
            return before != after ? DiffRow(id: c, before: before, after: after) : nil
        }
        .sorted { $0.id < $1.id }
    }

    private var diffText: String {
        diff.map { String(format: "0x%04X: %@ -> %@", $0.code, $0.before, $0.after) }
            .joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(status).font(Theme.mono(13)).foregroundColor(Theme.textSoft)

                HStack(spacing: 10) {
                    Button { snapshot(slotA: true) } label: {
                        Label("Chụp A", systemImage: "1.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    Button { snapshot(slotA: false) } label: {
                        Label("Chụp B", systemImage: "2.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.accent).disabled(snapA.isEmpty)
                }
                .foregroundColor(Theme.text).disabled(busy)

                if busy { ProgressView().tint(Theme.text).frame(maxWidth: .infinity) }

                if !snapA.isEmpty {
                    Text("A: \(snapA.count) code · B: \(snapB.count) code · Khác: \(diff.count)")
                        .font(Theme.mono(12)).foregroundColor(Theme.textSoft)
                }

                if !diff.isEmpty {
                    Text("Code đã đổi (nghi là của thông số bạn vừa chỉnh):")
                        .font(Theme.mono(13, .bold)).foregroundColor(Theme.text)
                    ForEach(diff) { d in
                        Text(String(format: "0x%04X:  %@  →  %@", d.code, d.before, d.after))
                            .font(Theme.mono(12)).foregroundColor(.green)
                    }
                    Button { UIPasteboard.general.string = diffText } label: {
                        Label("Copy kết quả", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered).tint(Theme.accent).foregroundColor(Theme.text)
                }
            }
            .padding()
        }
        .fujiBackground()
        .navigationTitle("Dò giao thức video").navigationBarTitleDisplayMode(.inline)
    }

    private func snapshot(slotA: Bool) {
        let ip = cameraIP.trimmingCharacters(in: .whitespaces)
        busy = true
        status = "Đang kết nối + đọc property… (có thể mất chút)"
        Task { @MainActor in
            let cam = FujiCamera(cameraIP: ip.isEmpty ? nil : ip)
            do {
                try await cam.connect()
                // A quét toàn dải; B chỉ quét lại đúng các code A đọc được (nhanh hơn).
                let codes = slotA ? candidates : Array(snapA.keys)
                let result = await cam.dump(codes)
                await cam.close()
                if slotA {
                    snapA = result; snapB = [:]
                    status = "Chụp A xong: \(result.count) code. Giờ ĐỔI TAY 1 thông số trên máy (Movie mode) rồi bấm Chụp B."
                } else {
                    snapB = result
                    status = "Chụp B xong. So sánh thấy \(diff.count) code đổi — xem bên dưới."
                }
            } catch {
                await cam.close(); status = "Lỗi: \(error)"
            }
            busy = false
        }
    }
}
