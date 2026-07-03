import Foundation
import FujiKit

/// Lưu/đọc recipe vào JSON trong Documents. CRUD đơn giản (dùng từ main thread).
final class RecipeStore: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("recipes.json")
    }()

    init() {
        load()
        if recipes.isEmpty { recipes = Self.defaults; save() }
    }

    func add(_ r: Recipe) { recipes.insert(r, at: 0); save() }

    /// Thêm các recipe mẫu Fuji X Weekly chưa có (so theo tên).
    func addSamples() {
        for r in BundledRecipes.all where !recipes.contains(where: { $0.name == r.name }) {
            recipes.append(r)
        }
        save()
    }
    func update(_ r: Recipe) {
        if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r; save() }
    }
    func delete(_ r: Recipe) { recipes.removeAll { $0.id == r.id }; save() }
    func delete(at offsets: IndexSet) { recipes.remove(atOffsets: offsets); save() }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = list
    }
    private func save() {
        if let data = try? JSONEncoder().encode(recipes) { try? data.write(to: url) }
    }

    // Recipe nạp sẵn (Fuji X Weekly).
    static var defaults: [Recipe] { BundledRecipes.all }
}
