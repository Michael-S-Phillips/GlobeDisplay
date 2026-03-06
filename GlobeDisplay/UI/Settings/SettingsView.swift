import SwiftUI

/// App settings: display calibration and data feed info.
struct SettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                dataFeedsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Display Calibration

    private var displaySection: some View {
        @Bindable var state = appState
        return Section {
            // Brightness
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Brightness", systemImage: "sun.max")
                    Spacer()
                    Text(String(format: "%.0f%%", appState.brightness * 100))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .monospacedDigit()
                }
                Slider(value: $state.brightness, in: 0.3...1.5, step: 0.05)
                    .onChange(of: appState.brightness) { _, v in
                        renderEngine?.brightness = v
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Brightness \(Int(appState.brightness * 100)) percent")

            // Horizontal flip
            Toggle(isOn: $state.flipHorizontal) {
                Label("Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .onChange(of: appState.flipHorizontal) { _, v in
                renderEngine?.flipHorizontal = v
            }

            // Vertical flip
            Toggle(isOn: $state.flipVertical) {
                Label("Flip Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
            }
            .onChange(of: appState.flipVertical) { _, v in
                renderEngine?.flipVertical = v
            }

            // Reset button
            Button(role: .destructive) {
                appState.brightness = 1.0
                appState.flipHorizontal = false
                appState.flipVertical = false
                renderEngine?.brightness = 1.0
                renderEngine?.flipHorizontal = false
                renderEngine?.flipVertical = false
            } label: {
                Label("Reset Display Calibration", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Display Calibration")
        } footer: {
            Text("Use Flip Horizontal if east and west appear reversed on the globe. Use Flip Vertical if north and south are swapped.")
        }
    }

    // MARK: - Data Feeds

    private var dataFeedsSection: some View {
        Section("Live Data Feeds") {
            feedRow(type: .earthquakes, source: "USGS Earthquake Hazards Program",
                    interval: "Every 5 minutes")
            feedRow(type: .volcanoes,   source: "Smithsonian Global Volcanism Program",
                    interval: "Every hour")
            feedRow(type: .wildfires,   source: "GDACS / Copernicus EMS",
                    interval: "Every 30 minutes")
        }
    }

    private func feedRow(type: DataFeedType, source: String, interval: String) -> some View {
        let status = appState.feedStatus[type]
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(type.displayName, systemImage: type.systemImage)
                    .font(.callout)
                Spacer()
                statusBadge(status)
            }
            Text(source)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Refresh: \(interval)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(_ status: FeedStatus?) -> some View {
        switch status {
        case .none:
            Text("Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .fetching:
            ProgressView()
                .scaleEffect(0.7)
        case .ok(let count, _):
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Build") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("License") {
                Text("MIT Open Source")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Planetary textures") {
                Text("NASA (public domain) · Solar System Scope (CC BY 4.0)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
