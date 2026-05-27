import SwiftUI

/// Motion + transport controls: continuous spin, play/pause, scrub timeline,
/// loop-mode, and animation speed. Sections appear contextually by content type.
struct PlaybackControlsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    var body: some View {
        HStack(spacing: 16) {
            spinControls

            if appState.currentContent?.contentType == .imageSequence {
                Divider().frame(height: 32)
                sequenceTransport
            }
        }
    }

    private var spinControls: some View {
        @Bindable var state = appState
        return HStack(spacing: 8) {
            Button {
                state.autoRotationEnabled.toggle()
                applySpin()
            } label: {
                Image(systemName: appState.autoRotationEnabled ? "stop.circle" : "arrow.clockwise.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appState.autoRotationEnabled ? "Stop spin" : "Start spin")

            if appState.autoRotationEnabled {
                Slider(value: $state.autoRotationSpeed, in: 1...30, step: 1) {
                    Text("Spin speed")
                } minimumValueLabel: {
                    Image(systemName: "tortoise").font(.caption2)
                } maximumValueLabel: {
                    Image(systemName: "hare").font(.caption2)
                }
                .frame(width: 110)
                .onChange(of: appState.autoRotationSpeed) { _, _ in applySpin() }
                .accessibilityLabel("Spin speed")
            }
        }
    }

    private var sequenceTransport: some View {
        @Bindable var state = appState
        return HStack(spacing: 12) {
            Button {
                guard let seq = appState.activeAnimationSequencer, let engine = renderEngine else { return }
                if seq.isPlaying { seq.pause() } else { seq.play(engine: engine) }
            } label: {
                Image(systemName: (appState.activeAnimationSequencer?.isPlaying ?? false) ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play or pause animation")

            Slider(
                value: Binding(
                    get: { appState.activeAnimationSequencer?.progress ?? 0 },
                    set: { appState.activeAnimationSequencer?.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            .frame(width: 150)
            .accessibilityLabel("Animation timeline")

            Picker("Loop mode", selection: Binding(
                get: { appState.activeAnimationSequencer?.playbackMode ?? .loop },
                set: { appState.activeAnimationSequencer?.playbackMode = $0 }
            )) {
                Image(systemName: "repeat").tag(PlaybackMode.loop)
                Image(systemName: "1.circle").tag(PlaybackMode.once)
                Image(systemName: "arrow.left.arrow.right").tag(PlaybackMode.pingPong)
            }
            .pickerStyle(.segmented)
            .frame(width: 130)

            Slider(value: $state.animationPlaybackRate, in: 0.25...4.0, step: 0.25) {
                Text("Speed")
            } minimumValueLabel: {
                Text("¼×").font(.caption2)
            } maximumValueLabel: {
                Text("4×").font(.caption2)
            }
            .frame(width: 110)
            .accessibilityLabel("Animation speed")
        }
    }

    private func applySpin() {
        guard let engine = renderEngine else { return }
        if appState.autoRotationEnabled {
            engine.autoRotationSpeed = appState.autoRotationSpeed
        } else {
            engine.autoRotationSpeed = 0
            appState.rotationOffset = engine.rotationOffset   // resume slider from current position
        }
    }
}
