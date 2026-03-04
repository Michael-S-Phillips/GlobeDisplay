import Foundation
import Observation
import CoreGraphics

/// Global application state shared across the control UI and rendering pipeline.
/// Injected as an environment object at the app root.
@Observable
@MainActor
final class AppState {
    var currentContent: ContentBundle?
    var rotationOffset: Double = 0.0        // degrees, 0–360
    var displayConnected: Bool = false
    var displayResolution: CGSize = CGSize(width: 2048, height: 1024)
}
