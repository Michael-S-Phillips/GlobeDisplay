import Foundation
import Observation

/// Observes `AppState` overlay flags and event arrays, then drives the
/// `OverlayCompositor` → `RenderEngine` pipeline whenever the relevant
/// state changes.
///
/// The `withObservationTracking` loop re-registers for change notifications
/// after each sleep cycle, providing a lightweight polling-with-notification
/// hybrid that avoids Combine while staying within Swift 6 strict-concurrency rules.
@MainActor
final class OverlayController {

    private weak var appState: AppState?
    private weak var renderEngine: RenderEngine?
    private var isRunning = false

    // MARK: - Lifecycle

    /// Begins observing `appState` and routing overlay renders to `renderEngine`.
    func start(appState: AppState, renderEngine: RenderEngine) {
        self.appState = appState
        self.renderEngine = renderEngine
        isRunning = true
        observeStep()
    }

    /// Stops the observation loop. Safe to call multiple times.
    func stop() {
        isRunning = false
    }

    // MARK: - Observation Loop

    /// Registers one round of observation tracking.  `onChange` fires at most once
    /// per call, then immediately re-registers — so no state change is ever missed.
    private func observeStep() {
        guard isRunning, let appState else { return }

        withObservationTracking {
            _ = appState.earthquakeEvents
            _ = appState.volcanoEvents
            _ = appState.wildfireEvents
            _ = appState.earthquakeOverlayEnabled
            _ = appState.volcanoOverlayEnabled
            _ = appState.wildfireOverlayEnabled
        } onChange: {
            Task { @MainActor [weak self] in
                self?.rerender()
                self?.observeStep()   // re-register immediately after each change
            }
        }
    }

    // MARK: - Rendering

    private func rerender() {
        guard let appState, let renderEngine else { return }

        let earthquakes = appState.earthquakeOverlayEnabled ? appState.earthquakeEvents : []
        let volcanoes   = appState.volcanoOverlayEnabled   ? appState.volcanoEvents   : []
        let wildfires   = appState.wildfireOverlayEnabled  ? appState.wildfireEvents  : []

        if let image = OverlayCompositor.shared.renderOverlay(
            earthquakes: earthquakes,
            volcanoes: volcanoes,
            wildfires: wildfires
        ) {
            do {
                try renderEngine.updateOverlayTexture(from: image)
            } catch {
                // Non-fatal: the previous overlay (or none) stays on screen.
                print("[OverlayController] updateOverlayTexture failed: \(error)")
            }
        } else {
            // All overlays are disabled or have no events — clear the texture.
            renderEngine.overlayTexture = nil
        }
    }
}
