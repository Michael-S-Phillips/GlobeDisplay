import SwiftUI

/// Displays the grid of available content bundles for a given category.
struct ContentBrowserView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    let bundles: [ContentBundle]

    @State private var status: LoadStatus = .idle

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
        .safeAreaInset(edge: .top) {
            statusBanner
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading(let title):
            Label("Loading \(title)…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
        case .ready(let title):
            Label("Displaying: \(title)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
        }
    }

    private func loadContent(_ bundle: ContentBundle) {
        appState.currentContent = bundle
        guard let engine = renderEngine else {
            status = .error("No render engine in environment")
            return
        }
        status = .loading(bundle.title)
        Task {
            do {
                let image = try ContentManager.shared.loadCGImage(for: bundle)
                try await engine.loadTexture(from: image)
                status = .ready(bundle.title)
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }
}

private enum LoadStatus {
    case idle
    case loading(String)
    case ready(String)
    case error(String)
}
