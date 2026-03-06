import SwiftUI

/// Displays the grid of available content bundles for a given category.
struct ContentBrowserView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    let bundles: [ContentBundle]
    let title: String

    @State private var status: LoadStatus = .idle
    @State private var activeSequencer: AnimationSequencer?

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
        .navigationTitle(title)
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
        // If the bundle is a downloadable catalog entry not yet available locally,
        // prompt the user to download it rather than attempting to load.
        if bundle.assets.downloadURL != nil && !ContentManager.shared.isDownloaded(bundle.id) {
            status = .error("Tap the Download button on the card to download this dataset.")
            return
        }

        appState.currentContent = bundle

        guard let engine = renderEngine else {
            status = .error("No render engine in environment")
            return
        }

        // Stop any running animation before loading new content.
        activeSequencer?.stop()
        activeSequencer = nil
        appState.activeAnimationSequencer = nil
        engine.animationSequencer = nil

        status = .loading(bundle.title)

        switch bundle.contentType {
        case .imageSequence:
            guard let dirName = bundle.assets.sequenceDirectory else {
                status = .error("No sequence directory specified for \(bundle.title)")
                return
            }
            Task {
                do {
                    // Resolve the sequence directory:
                    // • Absolute paths (starting with "/") are used directly — these come from
                    //   downloaded content stored in Application Support.
                    // • Relative names are looked up in the app bundle, then Documents.
                    let directory: URL
                    if dirName.hasPrefix("/") {
                        directory = URL(fileURLWithPath: dirName, isDirectory: true)
                    } else if let bundleURL = Bundle.main.url(
                        forResource: dirName,
                        withExtension: nil
                    ) {
                        directory = bundleURL
                    } else {
                        directory = FileManager.default
                            .urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent(dirName, isDirectory: true)
                    }

                    let sequencer = AnimationSequencer()
                    let baseFPS = bundle.assets.framerate ?? 15.0
                    sequencer.framerate = baseFPS * appState.animationPlaybackRate
                    try await sequencer.load(from: directory)
                    sequencer.play(engine: engine)
                    activeSequencer = sequencer
                    appState.activeAnimationSequencer = sequencer
                    engine.animationSequencer = sequencer
                    status = .ready(bundle.title)
                } catch {
                    status = .error(error.localizedDescription)
                }
            }

        case .staticImage, .video:
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
}

private enum LoadStatus {
    case idle
    case loading(String)
    case ready(String)
    case error(String)
}
