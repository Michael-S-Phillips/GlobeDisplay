import Foundation
import SwiftUI

enum DataFeedType: String, Codable, CaseIterable, Sendable {
    case earthquakes, volcanoes, wildfires

    var displayName: String {
        switch self {
        case .earthquakes: "Earthquakes"
        case .volcanoes:   "Volcanoes"
        case .wildfires:   "Wildfires"
        }
    }

    var systemImage: String {
        switch self {
        case .earthquakes: "waveform.path.ecg"
        case .volcanoes:   "mountain.2.fill"
        case .wildfires:   "flame.fill"
        }
    }

    /// How often this feed should be refreshed.
    var updateInterval: TimeInterval {
        switch self {
        case .earthquakes: 5 * 60    // 5 minutes
        case .volcanoes:   60 * 60   // 1 hour
        case .wildfires:   30 * 60   // 30 minutes
        }
    }

    /// The color used for overlay markers on the globe.
    var overlayColor: Color {
        switch self {
        case .earthquakes: .red
        case .volcanoes:   .purple
        case .wildfires:   .orange
        }
    }

    /// The GeoEventType produced by this feed.
    var eventType: GeoEventType {
        switch self {
        case .earthquakes: .earthquake
        case .volcanoes:   .volcano
        case .wildfires:   .wildfire
        }
    }
}

// MARK: - Feed Status

enum FeedStatus: Sendable {
    case fetching
    case ok(eventCount: Int, updatedAt: Date)
    case error(message: String, lastUpdated: Date?)

    /// Short human-readable label for the toolbar.
    var shortLabel: String {
        switch self {
        case .fetching:
            return "Updating…"
        case .ok(let count, let date):
            let age = Int(-date.timeIntervalSinceNow / 60)
            let countStr = "\(count) event\(count == 1 ? "" : "s")"
            if age < 1 { return "\(countStr) · just now" }
            return "\(countStr) · \(age)m ago"
        case .error(_, let last):
            guard let last else { return "Fetch failed" }
            let age = Int(-last.timeIntervalSinceNow / 60)
            return "Error · \(age)m ago"
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var isFetching: Bool {
        if case .fetching = self { return true }
        return false
    }
}
