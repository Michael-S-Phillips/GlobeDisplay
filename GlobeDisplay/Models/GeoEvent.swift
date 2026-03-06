import Foundation

enum GeoEventType: String, Codable, CaseIterable, Sendable {
    case earthquake, volcano, wildfire, storm, flood, seaIce, other
}

/// A normalized geospatial event from any DataFeedProvider.
/// All providers must map their native responses into this structure.
struct GeoEvent: Identifiable, Codable, Sendable {
    let id: String
    let type: GeoEventType
    let latitude: Double            // –90 to +90, north positive
    let longitude: Double           // –180 to +180, east positive
    let magnitude: Double?          // Richter for quakes; VEI for volcanoes
    let depth: Double?              // km, for earthquakes
    let timestamp: Date
    let title: String
    let description: String?
    let source: String
    let sourceURL: URL?
}
