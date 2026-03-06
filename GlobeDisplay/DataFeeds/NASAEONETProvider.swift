import Foundation

// MARK: - GVP Volcano Provider

/// Fetches active volcanic events from the Smithsonian Global Volcanism Program
/// Weekly Volcanic Activity RSS feed (GeoRSS).
actor GVPVolcanoProvider: DataFeedProvider {

    let feedType: DataFeedType = .volcanoes
    var updateInterval: TimeInterval { feedType.updateInterval }

    private let feedURL = URL(string: "https://volcano.si.edu/news/WeeklyVolcanoRSS.xml")!

    func fetch() async throws -> [GeoEvent] {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataFeedError.badHTTPStatus
        }
        let parser = GVPRSSParser()
        return parser.parse(data)
    }
}

/// SAX parser for the Smithsonian GVP RSS feed (ISO-8859-1, GeoRSS georss:point).
private final class GVPRSSParser: NSObject, XMLParserDelegate {

    private var events:         [GeoEvent] = []
    private var inItem          = false
    private var currentText     = ""
    private var itemTitle       = ""
    private var itemPoint       = ""   // "lat lon" space-separated
    private var itemPubDate     = ""
    private var itemLink        = ""

    func parse(_ data: Data) -> [GeoEvent] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false   // keep qualified names (georss:point)
        parser.parse()
        return events
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentText = ""
        if (qName ?? elementName) == "item" {
            inItem = true
            itemTitle = ""; itemPoint = ""; itemPubDate = ""; itemLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        guard inItem else { currentText = ""; return }
        let name = qName ?? elementName
        switch name {
        case "title":        itemTitle   = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "georss:point": itemPoint   = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "pubDate":      itemPubDate = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "link":         itemLink    = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        case "item":
            if let event = buildEvent() { events.append(event) }
            inItem = false
        default: break
        }
        currentText = ""
    }

    private func buildEvent() -> GeoEvent? {
        let parts = itemPoint.split(separator: " ")
        guard parts.count >= 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let timestamp = formatter.date(from: itemPubDate) ?? Date()

        // Stable ID derived from title (avoids duplicates across refreshes).
        let safeTitle = itemTitle.filter { $0.isLetter || $0.isNumber }.prefix(40)
        let id = "gvp-\(safeTitle)"

        return GeoEvent(
            id:          id,
            type:        .volcano,
            latitude:    lat,
            longitude:   lon,
            magnitude:   nil,
            depth:       nil,
            timestamp:   timestamp,
            title:       itemTitle,
            description: nil,
            source:      "Smithsonian GVP",
            sourceURL:   URL(string: itemLink)
        )
    }
}

// MARK: - GDACS Wildfire Provider

/// Fetches active wildfire events from the GDACS GeoJSON API.
actor GDACSWildfireProvider: DataFeedProvider {

    let feedType: DataFeedType = .wildfires
    var updateInterval: TimeInterval { feedType.updateInterval }

    private let feedURL = URL(string: "https://www.gdacs.org/gdacsapi/api/events/geteventlist/MAP?eventtype=WF")!

    // MARK: Codable DTOs

    private struct GDACSResponse: Decodable {
        let features: [GDACSFeature]
    }

    private struct GDACSFeature: Decodable {
        let geometry: GDACSGeometry
        let properties: GDACSProperties
    }

    private struct GDACSGeometry: Decodable {
        let type: String
        /// Only populated for Point geometries; nil for Polygon/LineString/etc.
        let coordinates: [Double]?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            // Polygon/LineString coordinates are nested arrays — ignore them.
            coordinates = try? c.decode([Double].self, forKey: .coordinates)
        }

        enum CodingKeys: String, CodingKey { case type, coordinates }
    }

    private struct GDACSProperties: Decodable {
        let eventtype:  String
        let eventid:    Int
        let name:       String
        let fromdate:   String?
        let alertlevel: String?
    }

    // MARK: DataFeedProvider

    func fetch() async throws -> [GeoEvent] {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataFeedError.badHTTPStatus
        }

        let gdacsResponse = try JSONDecoder().decode(GDACSResponse.self, from: data)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        return gdacsResponse.features.compactMap { feature -> GeoEvent? in
            guard feature.properties.eventtype == "WF",
                  feature.geometry.type == "Point",
                  let coords = feature.geometry.coordinates,
                  coords.count >= 2 else { return nil }

            let longitude = coords[0]
            let latitude  = coords[1]
            let timestamp = feature.properties.fromdate.flatMap { formatter.date(from: $0) } ?? Date()

            return GeoEvent(
                id:          "gdacs-wf-\(feature.properties.eventid)",
                type:        .wildfire,
                latitude:    latitude,
                longitude:   longitude,
                magnitude:   nil,
                depth:       nil,
                timestamp:   timestamp,
                title:       feature.properties.name,
                description: nil,
                source:      "GDACS",
                sourceURL:   nil
            )
        }
    }
}
