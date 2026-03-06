import SwiftUI

/// Plays a guided story: loads each step's content to the globe and
/// shows the narrative text with Prev/Next navigation.
struct StoryPlayerView: View {

    let story: Story

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    @State private var currentIndex = 0
    @State private var loadStatus: StepLoadStatus = .idle
    @State private var loadTask: Task<Void, Never>?
    @State private var autoAdvanceTask: Task<Void, Never>?

    private var currentStep: StoryStep {
        let safeIndex = min(currentIndex, story.steps.count - 1)
        return story.steps[max(0, safeIndex)]
    }
    private var isFirst: Bool { currentIndex == 0 }
    private var isLast:  Bool { currentIndex == story.steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step counter
                    Text("Step \(currentIndex + 1) of \(story.steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    // Narrative
                    Text(currentStep.narrative)
                        .font(.body)
                        .lineSpacing(4)
                        .animation(.easeInOut, value: currentIndex)
                        .id(currentIndex)   // force re-render on step change

                    // Load status
                    statusView
                }
                .padding()
            }
        }
        .navigationTitle("Step \(currentIndex + 1) of \(story.steps.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    advance(by: -1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(isFirst || loadStatus == .loading)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    advance(by: 1)
                } label: {
                    Label(isLast ? "Finish" : "Next",
                          systemImage: isLast ? "checkmark" : "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(loadStatus == .loading)
            }
        }
        .onChange(of: story.id) {
            // Synchronous reset so the next render uses a valid index
            // before .task(id:) fires asynchronously.
            currentIndex = 0
            loadStatus = .idle
        }
        .task(id: story.id) {
            loadTask?.cancel()
            autoAdvanceTask?.cancel()
            currentIndex = 0
            loadStatus = .idle
            loadStep(at: 0)
        }
        .onDisappear {
            loadTask?.cancel()
            autoAdvanceTask?.cancel()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(story.steps.count))
                    .animation(.easeInOut, value: currentIndex)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        switch loadStatus {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .ready(let title):
            Label("Displaying: \(title)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Step Loading

    private func advance(by delta: Int) {
        loadTask?.cancel()
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        let next = currentIndex + delta
        guard next >= 0, next < story.steps.count else { return }
        currentIndex = next
        loadStep(at: next)
    }

    private func loadStep(at index: Int) {
        // Cancel any in-flight load before starting a new one.
        loadTask?.cancel()
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil

        let step = story.steps[index]
        guard let bundle = ContentManager.shared.allContent().first(where: { $0.id == step.contentBundleID }) else {
            loadStatus = .error("Content not found")
            return
        }

        appState.currentContent = bundle
        guard let engine = renderEngine else {
            loadStatus = .error("No render engine")
            return
        }

        engine.animationSequencer = nil
        loadStatus = .loading

        loadTask = Task {
            do {
                // Capture shared instance on MainActor before detaching.
                let manager = ContentManager.shared
                // Decode image off the main thread to avoid blocking UI.
                let image = try await Task.detached(priority: .userInitiated) {
                    try manager.loadCGImage(for: bundle)
                }.value

                guard !Task.isCancelled else { return }
                try await engine.loadTexture(from: image)
                guard !Task.isCancelled else { return }
                loadStatus = .ready(bundle.title)

                // Schedule auto-advance if configured.
                if let seconds = step.autoAdvanceSeconds, index < story.steps.count - 1 {
                    autoAdvanceTask = Task {
                        try? await Task.sleep(for: .seconds(seconds))
                        guard !Task.isCancelled else { return }
                        await MainActor.run { advance(by: 1) }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    loadStatus = .error(error.localizedDescription)
                }
            }
        }
    }
}

private enum StepLoadStatus: Equatable {
    case idle
    case loading
    case ready(String)
    case error(String)
}
