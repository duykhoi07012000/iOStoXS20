import SwiftUI
import PhotosUI
import FujiKit

/// Dán text recipe (kiểu Fuji X Weekly) HOẶC chọn ảnh screenshot → OCR → parse → xem trước → lưu.
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RecipeStore
    @State private var text = ""
    @State private var parsed: Recipe?
    @State private var pickerItem: PhotosPickerItem?
    @State private var ocrBusy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dán text recipe (kiểu Fuji X Weekly) hoặc chọn ảnh screenshot recipe, rồi bấm \"Đọc recipe\":")
                        .font(Theme.mono(13)).foregroundColor(Theme.textSoft)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(ocrBusy ? "Đang đọc ảnh…" : "Chọn ảnh recipe",
                              systemImage: ocrBusy ? "hourglass" : "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.accent).foregroundColor(Theme.text)
                    .disabled(ocrBusy)

                    TextEditor(text: $text)
                        .font(Theme.mono(13)).frame(minHeight: 220)
                        .padding(8).background(Theme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("FILM SIMULATION\nClassic Negative\n...").font(Theme.mono(13))
                                    .foregroundColor(Theme.textSoft.opacity(0.5)).padding(14).allowsHitTesting(false)
                            }
                        }

                    Button { parsed = RecipeParser.parse(text) } label: {
                        Label("Đọc recipe", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundColor(Theme.text)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ocrBusy)

                    if let p = parsed {
                        Text("Xem trước").font(Theme.mono(14, .bold)).foregroundColor(Theme.text)
                        RecipeCard(recipe: p)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(RecipeRows.primary(p)) { row in
                                Text("• \(row.label): \(row.value)").font(Theme.mono(12)).foregroundColor(Theme.textSoft)
                            }
                        }
                    }
                }
                .padding()
            }
            .fujiBackground()
            .navigationTitle("Import").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() }.tint(Theme.text) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { if let p = parsed { store.add(p); dismiss() } }
                        .tint(Theme.text).bold().disabled(parsed == nil)
                }
            }
            .onChange(of: pickerItem) { item in
                guard let item else { return }
                ocrBusy = true
                Task {
                    let ocr = await loadAndRecognize(item)
                    await MainActor.run {
                        if !ocr.isEmpty { text = ocr; parsed = nil }
                        ocrBusy = false
                    }
                }
            }
        }
    }

    private func loadAndRecognize(_ item: PhotosPickerItem) async -> String {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return "" }
        return await RecipeOCR.recognize(image)
    }
}
