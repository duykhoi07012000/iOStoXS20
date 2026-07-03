import SwiftUI
import FujiKit

struct LibraryView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.recipes) { recipe in
                        NavigationLink { RecipeDetailView(recipe: recipe) } label: { RecipeCard(recipe: recipe) }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .fujiBackground()
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showImport = true } label: { Label("Import từ text", systemImage: "doc.text") }
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
            HStack {
                Text(recipe.displayName).font(Theme.mono(17, .bold)).foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(Theme.textSoft)
            }
            if let f = recipe.filmSimulation {
                Text(f.display).font(Theme.mono(12, .medium)).foregroundColor(Theme.textSoft)
            }
            HStack(spacing: 6) {
                if let dr = recipe.dynamicRange { chip(dr.display) }
                if let g = recipe.grain { chip(g.display) }
                if recipe.author != nil { chip(recipe.author!) }
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
