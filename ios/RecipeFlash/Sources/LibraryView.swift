import SwiftUI
import FujiKit

struct LibraryView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.recipes) { recipe in
                    NavigationLink { RecipeDetailView(recipe: recipe) } label: { RecipeCard(recipe: recipe) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.delete(recipe) } label: {
                                Label("Xoá", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .fujiBackground()
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showImport = true } label: { Label("Import (text hoặc ảnh)", systemImage: "doc.text.viewfinder") }
                        Button { store.add(Recipe(name: "New Recipe")) } label: { Label("Recipe trống", systemImage: "plus") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showImport) { ImportView() }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.displayName).font(Theme.mono(17, .bold)).foregroundColor(Theme.text)
            if let f = recipe.filmSimulation {
                Text(f.display).font(Theme.mono(12, .medium)).foregroundColor(Theme.textSoft)
            }
            HStack(spacing: 6) {
                if let dr = recipe.dynamicRange { chip(dr.display) }
                if let g = recipe.grain { chip(g.display) }
                if let a = recipe.author { chip(a) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }
    private func chip(_ s: String) -> some View {
        Text(s).font(Theme.mono(10, .semibold)).foregroundColor(Theme.text)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.pill, in: Capsule())
    }
}
