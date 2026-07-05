import SwiftUI
import FujiKit

/// Màn xem recipe + Apply (giống docs_UI ảnh 1).
struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cameraIP") private var cameraIP = ""   // trống = tự dò máy (broadcast)

    @State private var status = ""
    @State private var results: [(label: String, ok: Bool)] = []
    @State private var isFlashing = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LinearGradient(colors: [Theme.pill, Theme.card], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 96).clipShape(RoundedRectangle(cornerRadius: 18))

                Text(recipe.displayName).font(Theme.title()).foregroundColor(Theme.text)

                ForEach(RecipeRows.primary(recipe)) { row in
                    HStack(alignment: .center) {
                        Text(row.label).font(Theme.mono(14)).foregroundColor(Theme.text)
                        Spacer(minLength: 12)
                        ValuePill(icon: row.icon, text: row.value)
                    }
                }

                ForEach(RecipeRows.pairs(recipe).indices, id: \.self) { i in
                    let pair = RecipeRows.pairs(recipe)[i]
                    HStack(spacing: 12) {
                        pairCell(pair.0); pairCell(pair.1)
                    }
                }

                if let iso = recipe.notes["iso"] { noteRow("ISO", iso) }
                if let ec = recipe.notes["exposure_compensation"] { noteRow("Exp. Compensation", ec) }

                if let a = recipe.author {
                    Text("MADE BY : \(a)").font(Theme.mono(13, .semibold)).foregroundColor(Theme.textSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Theme.card, lineWidth: 1.5))
                        .padding(.top, 6)
                }

                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(results.indices, id: \.self) { i in
                            Label(results[i].label, systemImage: results[i].ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(Theme.mono(13)).foregroundColor(results[i].ok ? .green : .red)
                        }
                    }
                }
                if !status.isEmpty { Text(status).font(Theme.mono(13)).foregroundColor(Theme.textSoft) }
            }
            .padding()
        }
        .fujiBackground()
        .navigationTitle(recipe.displayName).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { showEdit = true } label: { Label("Sửa", systemImage: "slider.horizontal.3") }
                Button(role: .destructive) { store.delete(recipe); dismiss() } label: { Label("Xoá recipe", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle").tint(Theme.text) }
        } }
        .safeAreaInset(edge: .bottom) { applyButton }
        .sheet(isPresented: $showEdit) {
            NavigationStack { RecipeEditView(recipe: recipe) { store.update($0) } }
        }
    }

    private func pairCell(_ row: DisplayRow?) -> some View {
        Group {
            if let row {
                HStack {
                    Text(row.label).font(Theme.mono(13)).foregroundColor(Theme.text)
                    Spacer()
                    ValuePill(icon: row.icon, text: row.value)
                }
            } else { Color.clear }
        }
        .frame(maxWidth: .infinity)
    }

    private func noteRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.mono(14)).foregroundColor(Theme.text)
            Spacer(minLength: 12)
            Text(value).font(Theme.mono(13)).foregroundColor(Theme.textSoft)
        }
    }

    private var applyButton: some View {
        Group {
            if isFlashing {
                ProgressView().tint(Theme.text).frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                HStack(spacing: 10) {
                    applyBtn("Ảnh", "camera.fill", .photo)
                    applyBtn("Video", "video.fill", .video)
                }
            }
        }
        .controlSize(.large)
        .padding()
        .background(Theme.bg)
    }

    private func applyBtn(_ title: String, _ icon: String, _ target: RecipeTarget) -> some View {
        Button { flash(target: target) } label: {
            Label(title, systemImage: icon).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundColor(Theme.text)
    }

    private func flash(target: RecipeTarget) {
        let ip = cameraIP.trimmingCharacters(in: .whitespaces)
        let mode = target == .video ? "video" : "ảnh"
        isFlashing = true; results = []
        status = (ip.isEmpty ? "Đang tìm máy trên mạng…" : "Đang kết nối \(ip)…") + " (\(mode))"
        Task { @MainActor in
            let cam = FujiCamera(cameraIP: ip.isEmpty ? nil : ip)
            do {
                try await cam.connect()
                status = "Đã kết nối, đang áp recipe (\(mode))…"
                results = try await cam.apply(recipe, target: target)
                await cam.close()
                status = results.allSatisfy { $0.ok } ? "Xong — đã áp \(results.count) thông số (\(mode)) ✅" : "Xong, có lỗi (\(mode)) ❌"
            } catch {
                await cam.close(); status = "Lỗi: \(error)"
            }
            isFlashing = false
        }
    }
}
