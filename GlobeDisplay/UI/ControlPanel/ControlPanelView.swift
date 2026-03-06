import SwiftUI

/// The root control interface displayed on the iPad's built-in screen.
/// Uses a NavigationSplitView: sidebar for categories, detail for content grid.
struct ControlPanelView: View {

    var body: some View {
        SplitLayoutView()
            .preferredColorScheme(.dark)
    }
}

// Separate view so the environment reads happen inside the body where AppState is available.
private struct SplitLayoutView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    private var allContent: [ContentBundle] {
        ContentManager.shared.allContent()
    }

    /// Categories that have at least one content bundle.
    private var populatedCategories: [ContentCategory] {
        let usedCategories = Set(allContent.map(\.category))
        return ContentCategory.allCases.filter { usedCategories.contains($0) }
    }

    @State private var showSettings = false

    private var stories: [Story] { StoryLibrary.allStories() }

    var body: some View {
        NavigationSplitView {
            List {
                Section("Content") {
                    NavigationLink(destination: ContentBrowserView(category: nil, title: "All Content")) {
                        Label("All Content", systemImage: "square.grid.2x2")
                    }
                    ForEach(populatedCategories, id: \.self) { cat in
                        NavigationLink(destination: ContentBrowserView(category: cat, title: cat.displayName)) {
                            Label(cat.displayName, systemImage: cat.systemImage)
                        }
                    }
                }

                Section("Guided Stories") {
                    ForEach(stories) { story in
                        NavigationLink(destination: StoryPlayerView(story: story)) {
                            Label(story.title, systemImage: story.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("GlobeDisplay")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(appState)
                    .environment(\.renderEngine, renderEngine)
            }
        } detail: {
            ContentBrowserView(category: nil, title: "All Content")
        }
        .safeAreaInset(edge: .bottom) {
            BottomToolbar()
        }
    }
}

/// The persistent bottom toolbar with rotation slider and display status.
private struct BottomToolbar: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    @State private var showLegend = false

    var body: some View {
        HStack(spacing: 20) {
            displayStatus

            Divider()
                .frame(height: 32)

            rotationSlider

            Divider()
                .frame(height: 32)

            projectionSlider

            Divider()
                .frame(height: 32)

            radiusSlider

            Divider()
                .frame(height: 32)

            if appState.currentContent?.contentType == .imageSequence {
                Divider()
                    .frame(height: 32)

                animationSpeedSlider
            }

            overlayToggles

            if anyOverlayEnabled {
                Button {
                    showLegend = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Overlay legend")
                .popover(isPresented: $showLegend) {
                    DataLegendView(
                        earthquakesEnabled: appState.earthquakeOverlayEnabled,
                        volcanoesEnabled:   appState.volcanoOverlayEnabled,
                        wildfiresEnabled:   appState.wildfireOverlayEnabled
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .onChange(of: appState.animationPlaybackRate) { _, newRate in
            guard let sequencer = appState.activeAnimationSequencer,
                  let engine = renderEngine,
                  let baseFPS = appState.currentContent?.assets.framerate else { return }
            sequencer.framerate = baseFPS * newRate
            sequencer.play(engine: engine)
        }
    }

    private var anyOverlayEnabled: Bool {
        appState.earthquakeOverlayEnabled ||
        appState.volcanoOverlayEnabled ||
        appState.wildfireOverlayEnabled
    }

    private var displayStatus: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.displayConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(appState.displayConnected ? "Globe connected" : "No display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !appState.isNetworkAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 9))
                    Text("Offline — live data unavailable")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            appState.displayConnected ? "Globe connected" : "No display detected"
        )
    }

    private var projectionSlider: some View {
        @Bindable var state = appState
        return HStack {
            Image(systemName: "circle.and.line.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Slider(
                value: $state.projectionGamma,
                in: 1.0...4.0,
                step: 0.1
            ) {
                Text("Projection")
            } minimumValueLabel: {
                Text("1").font(.caption2)
            } maximumValueLabel: {
                Text("4").font(.caption2)
            }
            .onChange(of: appState.projectionGamma) { _, newValue in
                renderEngine?.projectionGamma = newValue
            }
            .accessibilityLabel("Projection correction")
            .accessibilityValue(String(format: "%.1f", appState.projectionGamma))
        }
    }

    private var radiusSlider: some View {
        @Bindable var state = appState
        return HStack {
            Image(systemName: "arrow.up.and.down.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Slider(
                value: $state.projectionRadius,
                in: 0.3...0.7,
                step: 0.01
            ) {
                Text("South pole radius")
            } minimumValueLabel: {
                Text("0.3").font(.caption2)
            } maximumValueLabel: {
                Text("0.7").font(.caption2)
            }
            .onChange(of: appState.projectionRadius) { _, newValue in
                renderEngine?.projectionRadius = newValue
            }
            .accessibilityLabel("South pole radius")
            .accessibilityValue(String(format: "%.2f", appState.projectionRadius))
        }
    }

    private var overlayToggles: some View {
        HStack(spacing: 8) {
            overlayButton(
                label: "Quakes",
                icon: DataFeedType.earthquakes.systemImage,
                color: .red,
                isOn: appState.earthquakeOverlayEnabled,
                feedType: .earthquakes
            )
            overlayButton(
                label: "Volcanoes",
                icon: DataFeedType.volcanoes.systemImage,
                color: .purple,
                isOn: appState.volcanoOverlayEnabled,
                feedType: .volcanoes
            )
            overlayButton(
                label: "Fires",
                icon: DataFeedType.wildfires.systemImage,
                color: .orange,
                isOn: appState.wildfireOverlayEnabled,
                feedType: .wildfires
            )
        }
    }

    private func overlayButton(
        label: String,
        icon: String,
        color: Color,
        isOn: Bool,
        feedType: DataFeedType
    ) -> some View {
        let status = appState.feedStatus[feedType]
        return VStack(spacing: 2) {
            Button {
                let newValue = !isOn
                switch feedType {
                case .earthquakes: appState.earthquakeOverlayEnabled = newValue
                case .volcanoes:   appState.volcanoOverlayEnabled    = newValue
                case .wildfires:   appState.wildfireOverlayEnabled   = newValue
                }
                if newValue {
                    DataFeedService.shared.startFeed(feedType, appState: appState)
                } else {
                    DataFeedService.shared.stopFeed(feedType, appState: appState)
                }
            } label: {
                Label(label, systemImage: icon)
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(isOn ? color : nil)
            .controlSize(.small)
            .accessibilityLabel("\(label) overlay \(isOn ? "on" : "off")")

            if isOn, let status {
                Text(status.shortLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(status.isError ? .red : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var animationSpeedSlider: some View {
        @Bindable var state = appState
        return HStack {
            Image(systemName: "play.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Slider(
                value: $state.animationPlaybackRate,
                in: 0.25...4.0,
                step: 0.25
            ) {
                Text("Speed")
            } minimumValueLabel: {
                Text("¼×").font(.caption2)
            } maximumValueLabel: {
                Text("4×").font(.caption2)
            }
            .accessibilityLabel("Animation speed")
            .accessibilityValue(String(format: "%.2f×", appState.animationPlaybackRate))
        }
    }

    private var rotationSlider: some View {
        @Bindable var state = appState
        return HStack {
            Image(systemName: "rotate.3d")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Slider(
                value: $state.rotationOffset,
                in: 0...360,
                step: 1
            ) {
                Text("Longitude offset")
            } minimumValueLabel: {
                Text("0°").font(.caption2)
            } maximumValueLabel: {
                Text("360°").font(.caption2)
            }
            .onChange(of: appState.rotationOffset) { _, newValue in
                renderEngine?.rotationOffset = newValue
            }
            .accessibilityLabel("Longitude offset")
            .accessibilityValue("\(Int(appState.rotationOffset)) degrees")
        }
    }
}
