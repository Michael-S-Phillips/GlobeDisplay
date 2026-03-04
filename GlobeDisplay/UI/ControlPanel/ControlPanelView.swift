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
        ContentManager.shared.bundledContent()
    }

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: ContentBrowserView(bundles: allContent)) {
                    Label("Planets", systemImage: "globe")
                }
            }
            .navigationTitle("GlobeDisplay")
            .listStyle(.sidebar)
        } detail: {
            ContentBrowserView(bundles: allContent)
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

    var body: some View {
        HStack(spacing: 20) {
            displayStatus

            Divider()
                .frame(height: 32)

            rotationSlider
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var displayStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.displayConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(appState.displayConnected ? "Globe connected" : "No display")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            appState.displayConnected ? "Globe connected" : "No display detected"
        )
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
