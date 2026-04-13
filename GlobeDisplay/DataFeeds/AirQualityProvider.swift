import Foundation

// MARK: - Response DTOs

private struct AirQualityResponse: Decodable {
    let current: Current

    struct Current: Decodable {
        let usAqi: Int?
        let pm25: Double?

        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
            case pm25  = "pm2_5"
        }
    }
}

// MARK: - City list

struct CityLocation: Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Provider

/// Fetches US AQI data for 60 major world cities from the Open-Meteo air quality API.
actor AirQualityProvider: DataFeedProvider {

    // MARK: DataFeedProvider

    nonisolated let feedType: DataFeedType = .airQuality

    var updateInterval: TimeInterval { feedType.updateInterval }   // 3600 s

    // MARK: City table (internal for testability)

    static let cities: [CityLocation] = [
        // North America (8)
        CityLocation(name: "New York",     latitude:  40.7128, longitude:  -74.0060),
        CityLocation(name: "Los Angeles",  latitude:  34.0522, longitude: -118.2437),
        CityLocation(name: "Chicago",      latitude:  41.8781, longitude:  -87.6298),
        CityLocation(name: "Houston",      latitude:  29.7604, longitude:  -95.3698),
        CityLocation(name: "Toronto",      latitude:  43.6510, longitude:  -79.3470),
        CityLocation(name: "Mexico City",  latitude:  19.4326, longitude:  -99.1332),
        CityLocation(name: "Vancouver",    latitude:  49.2827, longitude: -123.1207),
        CityLocation(name: "Atlanta",      latitude:  33.7490, longitude:  -84.3880),

        // South America (6)
        CityLocation(name: "São Paulo",    latitude: -23.5505, longitude:  -46.6333),
        CityLocation(name: "Buenos Aires", latitude: -34.6037, longitude:  -58.3816),
        CityLocation(name: "Lima",         latitude: -12.0464, longitude:  -77.0428),
        CityLocation(name: "Bogotá",       latitude:   4.7110, longitude:  -74.0721),
        CityLocation(name: "Santiago",     latitude: -33.4489, longitude:  -70.6693),
        CityLocation(name: "Caracas",      latitude:  10.4806, longitude:  -66.9036),

        // Europe (14)
        CityLocation(name: "London",       latitude:  51.5074, longitude:   -0.1278),
        CityLocation(name: "Paris",        latitude:  48.8566, longitude:    2.3522),
        CityLocation(name: "Berlin",       latitude:  52.5200, longitude:   13.4050),
        CityLocation(name: "Madrid",       latitude:  40.4168, longitude:   -3.7038),
        CityLocation(name: "Rome",         latitude:  41.9028, longitude:   12.4964),
        CityLocation(name: "Amsterdam",    latitude:  52.3676, longitude:    4.9041),
        CityLocation(name: "Vienna",       latitude:  48.2082, longitude:   16.3738),
        CityLocation(name: "Warsaw",       latitude:  52.2297, longitude:   21.0122),
        CityLocation(name: "Prague",       latitude:  50.0755, longitude:   14.4378),
        CityLocation(name: "Bucharest",    latitude:  44.4268, longitude:   26.1025),
        CityLocation(name: "Stockholm",    latitude:  59.3293, longitude:   18.0686),
        CityLocation(name: "Athens",       latitude:  37.9838, longitude:   23.7275),
        CityLocation(name: "Kyiv",         latitude:  50.4501, longitude:   30.5234),
        CityLocation(name: "Moscow",       latitude:  55.7558, longitude:   37.6173),

        // Middle East (5)
        CityLocation(name: "Dubai",        latitude:  25.2048, longitude:   55.2708),
        CityLocation(name: "Riyadh",       latitude:  24.7136, longitude:   46.6753),
        CityLocation(name: "Tehran",       latitude:  35.6892, longitude:   51.3890),
        CityLocation(name: "Istanbul",     latitude:  41.0082, longitude:   28.9784),
        CityLocation(name: "Cairo",        latitude:  30.0444, longitude:   31.2357),

        // Africa (7)
        CityLocation(name: "Lagos",        latitude:   6.5244, longitude:    3.3792),
        CityLocation(name: "Nairobi",      latitude:  -1.2921, longitude:   36.8219),
        CityLocation(name: "Johannesburg", latitude: -26.2041, longitude:   28.0473),
        CityLocation(name: "Casablanca",   latitude:  33.5731, longitude:   -7.5898),
        CityLocation(name: "Addis Ababa",  latitude:   9.0300, longitude:   38.7400),
        CityLocation(name: "Accra",        latitude:   5.6037, longitude:   -0.1870),
        CityLocation(name: "Kinshasa",     latitude:  -4.3217, longitude:   15.3222),

        // South/Southeast Asia (9)
        CityLocation(name: "Mumbai",       latitude:  19.0760, longitude:   72.8777),
        CityLocation(name: "Delhi",        latitude:  28.7041, longitude:   77.1025),
        CityLocation(name: "Dhaka",        latitude:  23.8103, longitude:   90.4125),
        CityLocation(name: "Karachi",      latitude:  24.8607, longitude:   67.0011),
        CityLocation(name: "Bangkok",      latitude:  13.7563, longitude:  100.5018),
        CityLocation(name: "Jakarta",      latitude:  -6.2088, longitude:  106.8456),
        CityLocation(name: "Manila",       latitude:  14.5995, longitude:  120.9842),
        CityLocation(name: "Kolkata",      latitude:  22.5726, longitude:   88.3639),
        CityLocation(name: "Lahore",       latitude:  31.5497, longitude:   74.3436),

        // East Asia (9)
        CityLocation(name: "Beijing",      latitude:  39.9042, longitude:  116.4074),
        CityLocation(name: "Shanghai",     latitude:  31.2304, longitude:  121.4737),
        CityLocation(name: "Tokyo",        latitude:  35.6762, longitude:  139.6503),
        CityLocation(name: "Seoul",        latitude:  37.5665, longitude:  126.9780),
        CityLocation(name: "Osaka",        latitude:  34.6937, longitude:  135.5023),
        CityLocation(name: "Chengdu",      latitude:  30.5728, longitude:  104.0668),
        CityLocation(name: "Guangzhou",    latitude:  23.1291, longitude:  113.2644),
        CityLocation(name: "Chongqing",    latitude:  29.5630, longitude:  106.5516),
        CityLocation(name: "Wuhan",        latitude:  30.5928, longitude:  114.3055),

        // Oceania (2)
        CityLocation(name: "Sydney",       latitude: -33.8688, longitude:  151.2093),
        CityLocation(name: "Melbourne",    latitude: -37.8136, longitude:  144.9631),
    ]

    // MARK: Fetch

    /// Fetches current US AQI for all 60 cities concurrently and returns one `GeoEvent` per city
    /// that reports a valid `us_aqi` value.
    func fetch() async throws -> [GeoEvent] {
        try await withThrowingTaskGroup(of: GeoEvent?.self) { group in
            for city in Self.cities {
                group.addTask {
                    try await self.fetchCity(city)
                }
            }

            var events: [GeoEvent] = []
            events.reserveCapacity(Self.cities.count)
            for try await event in group {
                if let event {
                    events.append(event)
                }
            }
            return events
        }
    }

    // MARK: Private helpers

    /// Fetches the AQI for a single city and maps it to a `GeoEvent`, or returns `nil`
    /// if `us_aqi` is absent from the response.
    private func fetchCity(_ city: CityLocation) async throws -> GeoEvent? {
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "air-quality-api.open-meteo.com"
        components.path   = "/v1/air-quality"
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current",   value: "us_aqi,pm2_5"),
        ]

        guard let url = components.url else {
            return nil
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataFeedError.badHTTPStatus
        }

        let decoded = try JSONDecoder().decode(AirQualityResponse.self, from: data)

        guard let aqi = decoded.current.usAqi else {
            return nil
        }

        let cityID = city.name.lowercased().replacingOccurrences(of: " ", with: "-")

        return GeoEvent(
            id:          "airquality-\(cityID)",
            type:        .airQuality,
            latitude:    city.latitude,
            longitude:   city.longitude,
            magnitude:   Double(aqi),
            depth:       nil,
            timestamp:   Date(),
            title:       "\(city.name) AQI: \(aqi)",
            description: nil,
            source:      "Open-Meteo",
            sourceURL:   nil
        )
    }
}
