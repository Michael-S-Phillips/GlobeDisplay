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
    var projectionGamma: Double = 1.0       // fisheye correction: 1=equidistant, 2=equisolid
    var projectionRadius: Double = 0.7      // cs-space radius where south pole appears
    var brightness: Double = 1.0            // output brightness multiplier 0.5–1.5
    var flipHorizontal: Bool = false        // mirror east/west
    var flipVertical: Bool = false          // flip north/south
    var displayConnected: Bool = false
    var displayResolution: CGSize = CGSize(width: 2048, height: 1024)

    // MARK: - Overlay state
    var earthquakeOverlayEnabled: Bool = false
    var volcanoOverlayEnabled: Bool = false
    var wildfireOverlayEnabled: Bool = false

    var earthquakeEvents: [GeoEvent] = []
    var volcanoEvents: [GeoEvent] = []
    var wildfireEvents: [GeoEvent] = []

    // MARK: - Feed status
    var feedStatus: [DataFeedType: FeedStatus] = [:]

    // MARK: - Network
    var isNetworkAvailable: Bool = true

    // MARK: - Animation playback
    var animationPlaybackRate: Double = 1.0
    var activeAnimationSequencer: AnimationSequencer?
}
