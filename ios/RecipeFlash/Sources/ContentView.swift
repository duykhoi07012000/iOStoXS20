import SwiftUI
import FujiKit

struct ContentView: View {
    @State private var cameraIP = "192.168.1.50"
    @State private var selectedID: RecipeItem.ID? = SampleRecipes.all.first?.id
    @State private var status = ""
    @State private var results: [(label: String, ok: Bool)] = []
    @State private var isFlashing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Máy ảnh") {
                    TextField("IP máy ảnh", text: $cameraIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    Text("Máy ở WIRELESS TETHER SHOOTING FIXED (đèn cam chớp), iPhone cùng Wi-Fi router.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Recipe") {
                    ForEach(SampleRecipes.all) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            if item.id == selectedID {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = item.id }
                    }
                }

                if !results.isEmpty {
                    Section("Kết quả") {
                        ForEach(results.indices, id: \.self) { i in
                            Label(results[i].label,
                                  systemImage: results[i].ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(results[i].ok ? .green : .red)
                        }
                    }
                }

                if !status.isEmpty {
                    Section { Text(status).font(.callout) }
                }
            }
            .navigationTitle("Fuji Recipe Flash")
            .safeAreaInset(edge: .bottom) {
                Button(action: flash) {
                    Group {
                        if isFlashing { ProgressView() }
                        else { Text("Flash xuống máy").bold().frame(maxWidth: .infinity) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isFlashing || selectedID == nil)
                .padding()
            }
        }
    }

    private func flash() {
        guard let item = SampleRecipes.all.first(where: { $0.id == selectedID }) else { return }
        isFlashing = true
        results = []
        status = "Đang kết nối…"
        Task { @MainActor in
            let cam = FujiCamera(cameraIP: cameraIP)
            do {
                try await cam.connect()
                status = "Đã kết nối, đang áp recipe…"
                let res = try await cam.apply(item.recipe)
                await cam.close()
                results = res
                status = res.allSatisfy { $0.ok }
                    ? "Xong — đã áp \(res.count) thông số ✅"
                    : "Xong, có thông số lỗi ❌"
            } catch {
                await cam.close()
                status = "Lỗi: \(error)"
            }
            isFlashing = false
        }
    }
}

#Preview {
    ContentView()
}
