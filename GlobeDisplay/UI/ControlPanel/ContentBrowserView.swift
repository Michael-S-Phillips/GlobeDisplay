import SwiftUI

/// Displays the grid of available content bundles for a given category.
struct ContentBrowserView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    let bundles: [ContentBundle]

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(bundles) { bundle in
                    ContentCard(
                        bundle: bundle,
                        isSelected: appState.currentContent?.id == bundle.id
                    )
                    .onTapGesture { loadContent(bundle) }
                }
            }
            .padding()
        }
        .navigationTitle("Planets")
    }

    private func loadContent(_ bundle: ContentBundle) {
        appState.currentContent = bundle
        guard let engine = renderEngine else { return }
        Task {
            do {
                let image = try ContentManager.shared.loadCGImage(for: bundle)
                try await engine.loadTexture(from: image)
            } catch {
                // TODO: surface error to UI in Phase 2
                print("[ContentBrowser] Failed to load texture for '\(bundle.title)': \(error)")
            }
        }
    }
}
