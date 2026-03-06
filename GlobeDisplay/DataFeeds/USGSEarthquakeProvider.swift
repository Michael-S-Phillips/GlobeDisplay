import Foundation

// MARK: - Codable DTOs

private struct USGSFeatureCollection: Decodable {
    let features: [USGSFeature]
}

private struct USGSFeature: Decodable {
    let id: String
    let properties: USGSProperties
    let geometry: USGSGeometry
}

private struct USGSProperties: Decodable {
    let mag: Double?
    let place: String?
    let time: Double          // milliseconds since Unix epoch
    let title: String?
    let url: String?
}

private struct USGSGeometry: Decodable {
    /// [longitude, latitude, depth_km]
    let coordinates: [Double]
}

// MARK: - Provider

/// Fetches all earthquakes from the past 24 hours using the USGS GeoJSON feed.
actor USGSEarthquakeProvider: DataFeedProvider {

    // MARK: DataFeedProvider

    let feedType: DataFeedType = .earthquakes

    var updateInterval: TimeInterval { feedType.updateInterval }   // 300 s

    private static let feedURL = URL(
        string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson"
    )!

    func fetch() async throws -> [GeoEvent] {
        let (data, response) = try await URLSession.shared.data(from: Self.feedURL)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataFeedError.badHTTPStatus
        }

        let decoder = JSONDecoder()
        let collection = try decoder.decode(USGSFeatureCollection.self, from: data)

        return collection.features.compactMap { feature -> GeoEvent? in
            let coords = feature.geometry.coordinates
            guard coords.count >= 2 else { return nil }

            let longitude = coords[0]
            let latitude  = coords[1]
            let depth     = coords.count >= 3 ? coords[2] : nil

            let timestamp = Date(timeIntervalSince1970: feature.properties.time / 1_000)

            let sourceURL: URL? = feature.properties.url.flatMap { URL(string: $0) }

            return GeoEvent(
                id:          feature.id,
                type:        .earthquake,
                latitude:    latitude,
                longitude:   longitude,
                magnitude:   feature.properties.mag,
                depth:       depth,
                timestamp:   timestamp,
                title:       feature.properties.title ?? "Earthquake",
                description: feature.properties.place,
                source:      "USGS",
                sourceURL:   sourceURL
            )
        }
    }
}
