# Shahnab Visualization Additions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three visual enhancements — Open-Meteo air quality feed (60 cities, AQI-colored dots), depth-scaled earthquake markers, and a pre-rendered rivers static overlay — within the existing `DataFeedProvider` / `OverlayCompositor` / `RenderEngine` architecture.

**Architecture:** New `AirQualityProvider` actor conforms to the existing `DataFeedProvider` protocol. `StaticOverlayLayer` enum keeps rivers separate from live event feeds. Metal shader gains a third texture slot for rivers composited between the base map and event overlay. `OverlayController` wires all state changes together.

**Tech Stack:** Swift 6 / SwiftUI, Metal, MetalKit, CoreGraphics, Open-Meteo API (free, no key), XCTest, Python + cartopy (dev-time only, for generating rivers PNG)

---

### Task 1: Add `.airQuality` to `GeoEventType` and `DataFeedType`

**Files:**
- Modify: `GlobeDisplay/Models/GeoEvent.swift`
- Modify: `GlobeDisplay/Models/DataFeed.swift`
- Create: `GlobeDisplayTests/DataFeedModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `GlobeDisplayTests/DataFeedModelTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class DataFeedModelTests: XCTestCase {

    func test_geoEventType_airQuality_rawValue() {
        XCTAssertEqual(GeoEventType.airQuality.rawValue, "airQuality")
    }

    func test_dataFeedType_airQuality_displayName() {
        XCTAssertEqual(DataFeedType.airQuality.displayName, "Air Quality")
    }

    func test_dataFeedType_airQuality_updateInterval() {
        XCTAssertEqual(DataFeedType.airQuality.updateInterval, 3600)
    }

    func test_dataFeedType_airQuality_eventType() {
        XCTAssertEqual(DataFeedType.airQuality.eventType, .airQuality)
    }

    func test_dataFeedType_airQuality_systemImage_isNonEmpty() {
        XCTAssertFalse(DataFeedType.airQuality.systemImage.isEmpty)
    }
}
```

Add `DataFeedModelTests.swift` to the `GlobeDisplayTests` target in Xcode.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/DataFeedModelTests 2>&1 | tail -20
```
Expected: build error — `GeoEventType.airQuality` does not exist.

- [ ] **Step 3: Add `.airQuality` to `GeoEventType` in `GlobeDisplay/Models/GeoEvent.swift`**

Change the enum declaration to:

```swift
enum GeoEventType: String, Codable, CaseIterable, Sendable {
    case earthquake, volcano, wildfire, storm, flood, seaIce, other, airQuality
}
```

- [ ] **Step 4: Add `.airQuality` to `DataFeedType` in `GlobeDisplay/Models/DataFeed.swift`**

Enum declaration:

```swift
enum DataFeedType: String, Codable, CaseIterable, Sendable {
    case earthquakes, volcanoes, wildfires, airQuality
```

`displayName` switch — add:
```swift
case .airQuality: "Air Quality"
```

`systemImage` switch — add:
```swift
case .airQuality: "aqi.medium"
```

`updateInterval` switch — add:
```swift
case .airQuality: 60 * 60   // 1 hour
```

`overlayColor` switch — add:
```swift
case .airQuality: .cyan
```

`eventType` switch — add:
```swift
case .airQuality: .airQuality
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/DataFeedModelTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/Models/GeoEvent.swift \
        GlobeDisplay/Models/DataFeed.swift \
        GlobeDisplayTests/DataFeedModelTests.swift
git commit -m "feat: add .airQuality case to GeoEventType and DataFeedType"
```

---

### Task 2: Create `StaticOverlayLayer.swift`

**Files:**
- Create: `GlobeDisplay/Rendering/StaticOverlayLayer.swift`
- Create: `GlobeDisplayTests/StaticOverlayLayerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `GlobeDisplayTests/StaticOverlayLayerTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class StaticOverlayLayerTests: XCTestCase {

    func test_rivers_displayName_isNonEmpty() {
        XCTAssertFalse(StaticOverlayLayer.rivers.displayName.isEmpty)
    }

    func test_rivers_systemImage_isNonEmpty() {
        XCTAssertFalse(StaticOverlayLayer.rivers.systemImage.isEmpty)
    }

    func test_rivers_bundledAssetName_isNonEmpty() {
        XCTAssertFalse(StaticOverlayLayer.rivers.bundledAssetName.isEmpty)
    }

    func test_isHashable_canBeUsedInSet() {
        var layers = Set<StaticOverlayLayer>()
        layers.insert(.rivers)
        XCTAssertTrue(layers.contains(.rivers))
        layers.remove(.rivers)
        XCTAssertFalse(layers.contains(.rivers))
    }
}
```

Add `StaticOverlayLayerTests.swift` to the `GlobeDisplayTests` target in Xcode.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/StaticOverlayLayerTests 2>&1 | tail -20
```
Expected: build error — `StaticOverlayLayer` does not exist.

- [ ] **Step 3: Create `GlobeDisplay/Rendering/StaticOverlayLayer.swift`**

```swift
import Foundation

/// A bundled raster overlay composited between the base map and live event markers.
/// Unlike `DataFeedType` overlays, these have no update cadence — loaded once from
/// the app bundle and toggled on/off by the user.
enum StaticOverlayLayer: String, CaseIterable, Hashable, Sendable {
    case rivers

    var displayName: String {
        switch self {
        case .rivers: "Rivers"
        }
    }

    var systemImage: String {
        switch self {
        case .rivers: "water.waves"
        }
    }

    /// PNG asset name (without extension) in `Resources/BundledContent/`.
    var bundledAssetName: String {
        switch self {
        case .rivers: "rivers_2048x1024"
        }
    }
}
```

Add `StaticOverlayLayer.swift` to the `GlobeDisplay` target in Xcode.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/StaticOverlayLayerTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add GlobeDisplay/Rendering/StaticOverlayLayer.swift \
        GlobeDisplayTests/StaticOverlayLayerTests.swift
git commit -m "feat: add StaticOverlayLayer enum for bundled raster overlays"
```

---

### Task 3: Update `AppState`

**Files:**
- Modify: `GlobeDisplay/App/AppState.swift`

No unit tests — `@Observable @MainActor` class requires a full app environment. Build verifies correctness.

- [ ] **Step 1: Add new properties to `AppState`**

In `GlobeDisplay/App/AppState.swift`, add `airQualityOverlayEnabled` after `wildfireOverlayEnabled`:

```swift
var airQualityOverlayEnabled: Bool = false
```

Add `airQualityEvents` after `wildfireEvents`:

```swift
var airQualityEvents: [GeoEvent] = []
```

Add a new section after the `feedStatus` property:

```swift
// MARK: - Static overlay state
var activeStaticOverlays: Set<StaticOverlayLayer> = []
```

- [ ] **Step 2: Verify build succeeds**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GlobeDisplay/App/AppState.swift
git commit -m "feat: add airQualityEvents, airQualityOverlayEnabled, activeStaticOverlays to AppState"
```

---

### Task 4: Create `AirQualityProvider.swift`

**Files:**
- Create: `GlobeDisplay/DataFeeds/AirQualityProvider.swift`
- Create: `GlobeDisplayTests/AirQualityProviderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `GlobeDisplayTests/AirQualityProviderTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class AirQualityProviderTests: XCTestCase {

    func test_cities_count_is60() {
        XCTAssertEqual(AirQualityProvider.cities.count, 60)
    }

    func test_cities_allHaveValidLatitudes() {
        for city in AirQualityProvider.cities {
            XCTAssertGreaterThanOrEqual(city.latitude, -90.0,
                "\(city.name) has invalid latitude \(city.latitude)")
            XCTAssertLessThanOrEqual(city.latitude, 90.0,
                "\(city.name) has invalid latitude \(city.latitude)")
        }
    }

    func test_cities_allHaveValidLongitudes() {
        for city in AirQualityProvider.cities {
            XCTAssertGreaterThanOrEqual(city.longitude, -180.0,
                "\(city.name) has invalid longitude \(city.longitude)")
            XCTAssertLessThanOrEqual(city.longitude, 180.0,
                "\(city.name) has invalid longitude \(city.longitude)")
        }
    }

    func test_cities_allHaveNonEmptyNames() {
        for city in AirQualityProvider.cities {
            XCTAssertFalse(city.name.isEmpty, "City has empty name")
        }
    }

    func test_cities_noDuplicateNames() {
        let names = AirQualityProvider.cities.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate city names found")
    }

    func test_feedType_isAirQuality() {
        let provider = AirQualityProvider()
        XCTAssertEqual(provider.feedType, .airQuality)
    }

    func test_updateInterval_is3600() {
        let provider = AirQualityProvider()
        XCTAssertEqual(provider.updateInterval, 3600)
    }
}
```

Add `AirQualityProviderTests.swift` to the `GlobeDisplayTests` target in Xcode.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/AirQualityProviderTests 2>&1 | tail -20
```
Expected: build error — `AirQualityProvider` does not exist.

- [ ] **Step 3: Create `GlobeDisplay/DataFeeds/AirQualityProvider.swift`**

```swift
import Foundation

// MARK: - City location

struct CityLocation: Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Codable DTOs

private struct AirQualityResponse: Decodable {
    struct Current: Decodable {
        let usAqi: Int?
        let pm25: Double?

        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
            case pm25  = "pm2_5"
        }
    }
    let current: Current
}

// MARK: - Provider

/// Fetches current US AQI readings for 60 major world cities from the
/// Open-Meteo air quality API.  Free, no API key required.
///
/// Each city becomes a `GeoEvent` with:
///   - `type`: `.airQuality`
///   - `magnitude`: US AQI value (0–500 scale)
///   - `description`: PM2.5 reading in µg/m³
actor AirQualityProvider: DataFeedProvider {

    // MARK: DataFeedProvider

    let feedType: DataFeedType = .airQuality
    var updateInterval: TimeInterval { 60 * 60 }   // 1 hour

    // MARK: City list (60 cities, globally distributed)

    static let cities: [CityLocation] = [
        // North America (8)
        CityLocation(name: "New York",          latitude:  40.71, longitude:  -74.01),
        CityLocation(name: "Los Angeles",        latitude:  34.05, longitude: -118.24),
        CityLocation(name: "Chicago",            latitude:  41.85, longitude:  -87.65),
        CityLocation(name: "Toronto",            latitude:  43.65, longitude:  -79.38),
        CityLocation(name: "Mexico City",        latitude:  19.43, longitude:  -99.13),
        CityLocation(name: "Vancouver",          latitude:  49.25, longitude: -123.12),
        CityLocation(name: "Houston",            latitude:  29.76, longitude:  -95.37),
        CityLocation(name: "Montreal",           latitude:  45.51, longitude:  -73.57),
        // South America (6)
        CityLocation(name: "São Paulo",          latitude: -23.55, longitude:  -46.63),
        CityLocation(name: "Buenos Aires",       latitude: -34.61, longitude:  -58.38),
        CityLocation(name: "Lima",               latitude: -12.05, longitude:  -77.04),
        CityLocation(name: "Bogotá",             latitude:   4.71, longitude:  -74.07),
        CityLocation(name: "Santiago",           latitude: -33.45, longitude:  -70.66),
        CityLocation(name: "Rio de Janeiro",     latitude: -22.91, longitude:  -43.18),
        // Europe (14)
        CityLocation(name: "London",             latitude:  51.51, longitude:   -0.13),
        CityLocation(name: "Paris",              latitude:  48.85, longitude:    2.35),
        CityLocation(name: "Berlin",             latitude:  52.52, longitude:   13.41),
        CityLocation(name: "Madrid",             latitude:  40.42, longitude:   -3.70),
        CityLocation(name: "Rome",               latitude:  41.90, longitude:   12.50),
        CityLocation(name: "Moscow",             latitude:  55.75, longitude:   37.62),
        CityLocation(name: "Amsterdam",          latitude:  52.37, longitude:    4.90),
        CityLocation(name: "Warsaw",             latitude:  52.23, longitude:   21.01),
        CityLocation(name: "Kyiv",               latitude:  50.45, longitude:   30.52),
        CityLocation(name: "Athens",             latitude:  37.98, longitude:   23.73),
        CityLocation(name: "Istanbul",           latitude:  41.01, longitude:   28.95),
        CityLocation(name: "Stockholm",          latitude:  59.33, longitude:   18.07),
        CityLocation(name: "Vienna",             latitude:  48.21, longitude:   16.37),
        CityLocation(name: "Prague",             latitude:  50.07, longitude:   14.44),
        // Middle East (5)
        CityLocation(name: "Cairo",              latitude:  30.06, longitude:   31.25),
        CityLocation(name: "Riyadh",             latitude:  24.69, longitude:   46.72),
        CityLocation(name: "Tehran",             latitude:  35.69, longitude:   51.39),
        CityLocation(name: "Dubai",              latitude:  25.20, longitude:   55.27),
        CityLocation(name: "Tel Aviv",           latitude:  32.09, longitude:   34.79),
        // Africa (7)
        CityLocation(name: "Lagos",              latitude:   6.52, longitude:    3.38),
        CityLocation(name: "Nairobi",            latitude:  -1.29, longitude:   36.82),
        CityLocation(name: "Johannesburg",       latitude: -26.20, longitude:   28.04),
        CityLocation(name: "Casablanca",         latitude:  33.59, longitude:   -7.62),
        CityLocation(name: "Accra",              latitude:   5.56, longitude:   -0.20),
        CityLocation(name: "Addis Ababa",        latitude:   9.03, longitude:   38.74),
        CityLocation(name: "Kinshasa",           latitude:  -4.32, longitude:   15.32),
        // South/Southeast Asia (9)
        CityLocation(name: "Mumbai",             latitude:  19.08, longitude:   72.88),
        CityLocation(name: "Delhi",              latitude:  28.66, longitude:   77.23),
        CityLocation(name: "Karachi",            latitude:  24.86, longitude:   67.01),
        CityLocation(name: "Dhaka",              latitude:  23.72, longitude:   90.41),
        CityLocation(name: "Kolkata",            latitude:  22.57, longitude:   88.36),
        CityLocation(name: "Bangkok",            latitude:  13.75, longitude:  100.52),
        CityLocation(name: "Jakarta",            latitude:  -6.21, longitude:  106.85),
        CityLocation(name: "Manila",             latitude:  14.60, longitude:  120.98),
        CityLocation(name: "Ho Chi Minh City",   latitude:  10.82, longitude:  106.63),
        // East Asia (9)
        CityLocation(name: "Beijing",            latitude:  39.91, longitude:  116.39),
        CityLocation(name: "Shanghai",           latitude:  31.23, longitude:  121.47),
        CityLocation(name: "Tokyo",              latitude:  35.69, longitude:  139.69),
        CityLocation(name: "Seoul",              latitude:  37.57, longitude:  126.98),
        CityLocation(name: "Hong Kong",          latitude:  22.30, longitude:  114.18),
        CityLocation(name: "Osaka",              latitude:  34.69, longitude:  135.50),
        CityLocation(name: "Taipei",             latitude:  25.05, longitude:  121.53),
        CityLocation(name: "Guangzhou",          latitude:  23.13, longitude:  113.27),
        CityLocation(name: "Chengdu",            latitude:  30.57, longitude:  104.07),
        // Oceania (2)
        CityLocation(name: "Sydney",             latitude: -33.87, longitude:  151.21),
        CityLocation(name: "Melbourne",          latitude: -37.81, longitude:  144.96),
    ]

    // MARK: Fetch

    func fetch() async throws -> [GeoEvent] {
        let cities = Self.cities
        var results: [GeoEvent] = []

        await withTaskGroup(of: GeoEvent?.self) { group in
            for city in cities {
                group.addTask {
                    return try? await Self.fetchCity(city)
                }
            }
            for await event in group {
                if let event { results.append(event) }
            }
        }
        return results
    }

    // MARK: Private

    private static func fetchCity(_ city: CityLocation) async throws -> GeoEvent {
        var components = URLComponents(
            string: "https://air-quality-api.open-meteo.com/v1/air-quality"
        )!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current",   value: "us_aqi,pm2_5"),
        ]
        guard let url = components.url else { throw DataFeedError.badHTTPStatus }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataFeedError.badHTTPStatus
        }

        let decoded = try JSONDecoder().decode(AirQualityResponse.self, from: data)
        let pm25Description = decoded.current.pm25.map {
            String(format: "PM2.5: %.1f µg/m³", $0)
        }
        let safeId = city.name.lowercased().replacingOccurrences(of: " ", with: "-")

        return GeoEvent(
            id:          "aq-\(safeId)",
            type:        .airQuality,
            latitude:    city.latitude,
            longitude:   city.longitude,
            magnitude:   decoded.current.usAqi.map { Double($0) },
            depth:       nil,
            timestamp:   Date(),
            title:       city.name,
            description: pm25Description,
            source:      "Open-Meteo",
            sourceURL:   nil
        )
    }
}
```

Add `AirQualityProvider.swift` to the `GlobeDisplay` target in Xcode.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/AirQualityProviderTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add GlobeDisplay/DataFeeds/AirQualityProvider.swift \
        GlobeDisplayTests/AirQualityProviderTests.swift
git commit -m "feat: add AirQualityProvider fetching 60-city Open-Meteo data"
```

---

### Task 5: Update `DataFeedService`

**Files:**
- Modify: `GlobeDisplay/DataFeeds/DataFeedService.swift`

No new tests — wiring glue only. Build verification is sufficient.

- [ ] **Step 1: Register `AirQualityProvider` and add routing**

In `GlobeDisplay/DataFeeds/DataFeedService.swift`:

Add provider property after `wildfireProvider`:

```swift
private let airQualityProvider = AirQualityProvider()
```

Replace `provider(for:)`:

```swift
private func provider(for type: DataFeedType) -> any DataFeedProvider {
    switch type {
    case .earthquakes: return earthquakeProvider
    case .volcanoes:   return volcanoProvider
    case .wildfires:   return wildfireProvider
    case .airQuality:  return airQualityProvider
    }
}
```

Replace `publish(events:for:to:)`:

```swift
private func publish(events: [GeoEvent], for type: DataFeedType, to appState: AppState) {
    switch type {
    case .earthquakes: appState.earthquakeEvents = events
    case .volcanoes:   appState.volcanoEvents    = events
    case .wildfires:   appState.wildfireEvents   = events
    case .airQuality:  appState.airQualityEvents = events
    }
}
```

- [ ] **Step 2: Verify build succeeds**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add GlobeDisplay/DataFeeds/DataFeedService.swift
git commit -m "feat: register AirQualityProvider in DataFeedService"
```

---

### Task 6: Update `OverlayCompositor` — depth-scaled earthquakes + air quality

**Files:**
- Modify: `GlobeDisplay/Rendering/OverlayCompositor.swift`

Note: after this task the build will have errors in `OverlayController` (which calls the old `renderOverlay` signature). These are resolved in Task 7. Do not run the build verify step until Task 8 completes.

- [ ] **Step 1: Update `renderOverlay()` signature to add `airQuality` parameter**

Replace the `renderOverlay()` method signature and guard:

```swift
func renderOverlay(
    earthquakes: [GeoEvent],
    volcanoes: [GeoEvent],
    wildfires: [GeoEvent],
    airQuality: [GeoEvent]
) -> CGImage? {
    guard !earthquakes.isEmpty || !volcanoes.isEmpty
            || !wildfires.isEmpty || !airQuality.isEmpty else {
        return nil
    }
    // ... (width/height/context setup unchanged)
    drawEarthquakes(earthquakes, in: context)
    drawVolcanoes(volcanoes, in: context)
    drawWildfires(wildfires, in: context)
    drawAirQuality(airQuality, in: context)

    return context.makeImage()
}
```

- [ ] **Step 2: Replace `drawEarthquakes()` with depth-aware version**

Replace the entire `drawEarthquakes()` method:

```swift
private func drawEarthquakes(_ events: [GeoEvent], in context: CGContext) {
    let now = Date()
    for event in events {
        let pixel = MapProjection.toPixel(
            latitude: event.latitude,
            longitude: event.longitude,
            in: canvasSize
        )
        let rawRadius = max(4.0, (event.magnitude ?? 2.0) * 5.0)
        let radius = min(rawRadius, 30.0)

        // Age-based color (unchanged)
        let age = now.timeIntervalSince(event.timestamp)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        if age <= 3600 {
            (r, g, b) = (1.0, 0.1, 0.1)
        } else if age <= 21600 {
            (r, g, b) = (1.0, 0.5, 0.0)
        } else {
            (r, g, b) = (1.0, 0.9, 0.0)
        }

        // Depth-based opacity and shallow ring
        let depth = event.depth ?? 0.0   // nil treated as shallow
        let alpha: CGFloat
        let isShallow: Bool
        if depth < 70.0 {
            alpha = 0.8; isShallow = true
        } else if depth < 300.0 {
            alpha = 0.6; isShallow = false
        } else {
            alpha = 0.4; isShallow = false
        }

        drawFilledCircle(at: pixel, radius: radius, r: r, g: g, b: b, alpha: alpha, in: context)
        drawStrokeRing(at: pixel, radius: radius + 1, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)
        if isShallow {
            drawStrokeRing(at: pixel, radius: radius + 4, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 0.6, in: context)
        }

        if let mirroredLon = dateline_mirrorLongitude(event.longitude) {
            let mirrorPixel = MapProjection.toPixel(
                latitude: event.latitude,
                longitude: mirroredLon,
                in: canvasSize
            )
            drawFilledCircle(at: mirrorPixel, radius: radius, r: r, g: g, b: b, alpha: alpha, in: context)
            drawStrokeRing(at: mirrorPixel, radius: radius + 1, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)
            if isShallow {
                drawStrokeRing(at: mirrorPixel, radius: radius + 4, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 0.6, in: context)
            }
        }
    }
}
```

- [ ] **Step 3: Add `drawAirQuality()` after `drawWildfires()`**

```swift
private func drawAirQuality(_ events: [GeoEvent], in context: CGContext) {
    for event in events {
        let pixel = MapProjection.toPixel(
            latitude: event.latitude,
            longitude: event.longitude,
            in: canvasSize
        )

        // AQI stored in magnitude field; default to 0 (Good) if nil.
        let aqi = event.magnitude ?? 0.0
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch aqi {
        case ..<51:  (r, g, b) = (0.0, 0.8, 0.2)   // Good — green
        case ..<101: (r, g, b) = (1.0, 0.9, 0.0)   // Moderate — yellow
        case ..<151: (r, g, b) = (1.0, 0.5, 0.0)   // Unhealthy for sensitive — orange
        case ..<201: (r, g, b) = (1.0, 0.1, 0.1)   // Unhealthy — red
        default:     (r, g, b) = (0.6, 0.0, 0.0)   // Very unhealthy/Hazardous — dark red
        }

        drawFilledCircle(at: pixel, radius: 12, r: r, g: g, b: b, alpha: 0.75, in: context)
        drawStrokeRing(at: pixel, radius: 13, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)

        if let mirroredLon = dateline_mirrorLongitude(event.longitude) {
            let mirrorPixel = MapProjection.toPixel(
                latitude: event.latitude,
                longitude: mirroredLon,
                in: canvasSize
            )
            drawFilledCircle(at: mirrorPixel, radius: 12, r: r, g: g, b: b, alpha: 0.75, in: context)
            drawStrokeRing(at: mirrorPixel, radius: 13, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)
        }
    }
}
```

- [ ] **Step 4: Commit (build errors expected until Task 8)**

```bash
git add GlobeDisplay/Rendering/OverlayCompositor.swift
git commit -m "feat: depth-scaled earthquake markers and air quality overlay drawing"
```

---

### Task 7: Update `OverlayController`

**Files:**
- Modify: `GlobeDisplay/App/OverlayController.swift`

Note: build errors remain until Task 8 adds `loadRiversTexture()` and `unloadRiversTexture()` to `RenderEngine`.

- [ ] **Step 1: Replace `observeStep()` tracking block**

Replace the `withObservationTracking` block inside `observeStep()`:

```swift
withObservationTracking {
    _ = appState.earthquakeEvents
    _ = appState.volcanoEvents
    _ = appState.wildfireEvents
    _ = appState.airQualityEvents
    _ = appState.earthquakeOverlayEnabled
    _ = appState.volcanoOverlayEnabled
    _ = appState.wildfireOverlayEnabled
    _ = appState.airQualityOverlayEnabled
    _ = appState.activeStaticOverlays
} onChange: {
    Task { @MainActor [weak self] in
        self?.rerender()
        self?.observeStep()
    }
}
```

- [ ] **Step 2: Replace `rerender()` to handle air quality and rivers**

Replace the entire `rerender()` method:

```swift
private func rerender() {
    guard let appState, let renderEngine else { return }

    let earthquakes = appState.earthquakeOverlayEnabled ? appState.earthquakeEvents : []
    let volcanoes   = appState.volcanoOverlayEnabled   ? appState.volcanoEvents    : []
    let wildfires   = appState.wildfireOverlayEnabled  ? appState.wildfireEvents   : []
    let airQuality  = appState.airQualityOverlayEnabled ? appState.airQualityEvents : []

    // Rivers static overlay — load once on first enable; clear on disable.
    if appState.activeStaticOverlays.contains(.rivers) {
        Task { @MainActor [weak renderEngine] in
            await renderEngine?.loadRiversTexture()
        }
    } else {
        renderEngine.unloadRiversTexture()
    }

    if let image = OverlayCompositor.shared.renderOverlay(
        earthquakes: earthquakes,
        volcanoes: volcanoes,
        wildfires: wildfires,
        airQuality: airQuality
    ) {
        do {
            try renderEngine.updateOverlayTexture(from: image)
        } catch {
            print("[OverlayController] updateOverlayTexture failed: \(error)")
        }
    } else {
        renderEngine.overlayTexture = nil
    }
}
```

- [ ] **Step 3: Commit (build errors remain until Task 8)**

```bash
git add GlobeDisplay/App/OverlayController.swift
git commit -m "feat: update OverlayController for air quality and rivers layers"
```

---

### Task 8: Update Metal shader and `RenderEngine` for rivers texture

**Files:**
- Modify: `GlobeDisplay/Rendering/EquirectangularShaders.metal`
- Modify: `GlobeDisplay/Rendering/RenderEngine.swift`

- [ ] **Step 1: Replace the fragment shader function in `EquirectangularShaders.metal`**

Replace everything from `fragment float4 equirect_fragment(` to the closing `}`:

```metal
fragment float4 equirect_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> baseTexture    [[texture(0)]],
    texture2d<float> overlayTexture [[texture(1)]],
    texture2d<float> riversTexture  [[texture(2)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler polarSampler(
        mag_filter::linear,
        min_filter::linear,
        s_address::repeat,
        t_address::clamp_to_edge
    );

    float2 c = in.texCoord - float2(0.5, 0.5);

    float aspect = uniforms.aspectRatio;
    float sx = max(1.0, 1.0 / aspect);
    float sy = max(1.0, aspect);
    float2 cs = float2(c.x * sx, c.y * sy);

    float lat = pow(min(1.0, length(cs) / uniforms.projectionRadius), uniforms.projectionGamma);
    if (uniforms.flipVertical > 0.5) { lat = 1.0 - lat; }

    float theta = atan2(cs.y, cs.x);
    float lonSign = (uniforms.flipHorizontal > 0.5) ? 1.0 : -1.0;
    float lon = fract(0.5 + lonSign * theta / (2.0 * M_PI_F) + uniforms.rotationOffset);

    constexpr sampler overlaySampler(
        mag_filter::linear,
        min_filter::linear,
        s_address::clamp_to_zero,
        t_address::clamp_to_zero
    );

    float2 uv = float2(lon, lat);
    float4 base    = baseTexture.sample(polarSampler, uv);
    float4 rivers  = riversTexture.sample(polarSampler, uv);   // equirectangular — wraps like base
    float4 overlay = overlayTexture.sample(overlaySampler, uv);

    // Composite: base → rivers → event overlay (Porter-Duff "over")
    float3 composited = mix(base.rgb, rivers.rgb, rivers.a);
    composited = mix(composited, overlay.rgb, overlay.a);
    composited = clamp(composited * uniforms.brightness, 0.0, 1.0);
    return float4(composited, 1.0);
}
```

- [ ] **Step 2: Add rivers texture properties to `RenderEngine`**

In `GlobeDisplay/Rendering/RenderEngine.swift`, add after `clearOverlayTexture`:

```swift
/// Active rivers texture — non-nil when the rivers layer is enabled.
var riversTexture: MTLTexture?

/// Cached rivers texture retained across enable/disable cycles.
private var cachedRiversTexture: MTLTexture?
```

- [ ] **Step 3: Add `loadRiversTexture()` and `unloadRiversTexture()` to `RenderEngine`**

Add before `// MARK: - MTKViewDelegate`:

```swift
// MARK: - Rivers Overlay

/// Loads the rivers texture from the app bundle on the first call;
/// re-uses the cached texture on subsequent calls.
/// Silently no-ops if the asset is not bundled.
func loadRiversTexture() async {
    if let cached = cachedRiversTexture {
        riversTexture = cached
        return
    }
    guard let url = Bundle.main.url(
        forResource: StaticOverlayLayer.rivers.bundledAssetName,
        withExtension: "png"
    ) else { return }

    let loader = MTKTextureLoader(device: device)
    let options: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .SRGB: false,
    ]
    let tex = try? await loader.newTexture(contentsOf: url, options: options)
    cachedRiversTexture = tex
    riversTexture = tex
}

/// Hides the rivers layer without discarding the cached texture.
func unloadRiversTexture() {
    riversTexture = nil
}
```

- [ ] **Step 4: Bind rivers texture at index 2 in `draw(in:)`**

Inside the `if let texture = baseTexture` block in `draw(in view: MTKView)`, add after the line that binds `overlayTexture`:

```swift
encoder.setFragmentTexture(riversTexture ?? clearOverlayTexture, index: 2)
```

The updated three-line block:

```swift
encoder.setFragmentTexture(texture, index: 0)
encoder.setFragmentTexture(overlayTexture ?? clearOverlayTexture, index: 1)
encoder.setFragmentTexture(riversTexture ?? clearOverlayTexture, index: 2)
```

- [ ] **Step 5: Verify build succeeds**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/Rendering/EquirectangularShaders.metal \
        GlobeDisplay/Rendering/RenderEngine.swift
git commit -m "feat: add rivers texture layer to Metal shader and RenderEngine"
```

---

### Task 9: Update UI — overlay toolbar and data legend

**Files:**
- Modify: `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift`
- Modify: `GlobeDisplay/UI/Components/DataLegendView.swift`

- [ ] **Step 1: Replace `overlayToggles` in `ControlPanelView` to add air quality and rivers buttons**

Replace `overlayToggles` computed property in `BottomToolbar`:

```swift
private var overlayToggles: some View {
    HStack(spacing: 8) {
        overlayButton(
            label: "Quakes",
            icon: DataFeedType.earthquakes.systemImage,
            color: .red,
            isOn: appState.earthquakeOverlayEnabled,
            feedType: .earthquakes
        )
        overlayButton(
            label: "Volcanoes",
            icon: DataFeedType.volcanoes.systemImage,
            color: .purple,
            isOn: appState.volcanoOverlayEnabled,
            feedType: .volcanoes
        )
        overlayButton(
            label: "Fires",
            icon: DataFeedType.wildfires.systemImage,
            color: .orange,
            isOn: appState.wildfireOverlayEnabled,
            feedType: .wildfires
        )
        overlayButton(
            label: "Air",
            icon: DataFeedType.airQuality.systemImage,
            color: .cyan,
            isOn: appState.airQualityOverlayEnabled,
            feedType: .airQuality
        )
        staticOverlayButton(
            label: "Rivers",
            icon: StaticOverlayLayer.rivers.systemImage,
            color: .blue,
            layer: .rivers
        )
    }
}
```

- [ ] **Step 2: Add `.airQuality` case to `overlayButton()` switch**

In `overlayButton()`, replace the switch inside the `Button` action:

```swift
switch feedType {
case .earthquakes: appState.earthquakeOverlayEnabled = newValue
case .volcanoes:   appState.volcanoOverlayEnabled    = newValue
case .wildfires:   appState.wildfireOverlayEnabled   = newValue
case .airQuality:  appState.airQualityOverlayEnabled = newValue
}
```

- [ ] **Step 3: Add `staticOverlayButton()` helper method after `overlayButton()`**

```swift
private func staticOverlayButton(
    label: String,
    icon: String,
    color: Color,
    layer: StaticOverlayLayer
) -> some View {
    let isOn = appState.activeStaticOverlays.contains(layer)
    return Button {
        if isOn {
            appState.activeStaticOverlays.remove(layer)
        } else {
            appState.activeStaticOverlays.insert(layer)
        }
    } label: {
        Label(label, systemImage: icon)
            .font(.caption)
    }
    .buttonStyle(.bordered)
    .tint(isOn ? color : nil)
    .controlSize(.small)
    .accessibilityLabel("\(label) overlay \(isOn ? "on" : "off")")
}
```

- [ ] **Step 4: Update `anyOverlayEnabled`**

Replace:

```swift
private var anyOverlayEnabled: Bool {
    appState.earthquakeOverlayEnabled ||
    appState.volcanoOverlayEnabled ||
    appState.wildfireOverlayEnabled ||
    appState.airQualityOverlayEnabled
}
```

- [ ] **Step 5: Update the `DataLegendView` call site to pass `airQualityEnabled`**

In `BottomToolbar.body`, update the `DataLegendView` instantiation:

```swift
DataLegendView(
    earthquakesEnabled: appState.earthquakeOverlayEnabled,
    volcanoesEnabled:   appState.volcanoOverlayEnabled,
    wildfiresEnabled:   appState.wildfireOverlayEnabled,
    airQualityEnabled:  appState.airQualityOverlayEnabled
)
```

- [ ] **Step 6: Replace `DataLegendView.swift`**

Replace the entire file with:

```swift
import SwiftUI

/// A popover explaining the color and symbol coding for active data overlays.
struct DataLegendView: View {

    let earthquakesEnabled: Bool
    let volcanoesEnabled:   Bool
    let wildfiresEnabled:   Bool
    let airQualityEnabled:  Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if earthquakesEnabled {
                section("Earthquakes") {
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.1, blue: 0.1)).frame(width: 14, height: 14)
                    } label: { Text("< 1 hour ago") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.5, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("1 – 6 hours ago") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.9, blue: 0.0)).frame(width: 10, height: 10)
                    } label: { Text("Older") }
                    Text("Size = magnitude · Full opacity = shallow (< 70 km) · Faded = deep (> 300 km) · Double ring = very shallow")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            if volcanoesEnabled {
                section("Volcanoes") {
                    legendRow {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.9, green: 0.0, blue: 0.8))
                    } label: { Text("Active eruption (Smithsonian GVP)") }
                }
            }

            if wildfiresEnabled {
                section("Wildfires") {
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.4, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("Active wildfire (GDACS)") }
                }
            }

            if airQualityEnabled {
                section("Air Quality (US AQI)") {
                    legendRow {
                        Circle().fill(Color(red: 0.0, green: 0.8, blue: 0.2)).frame(width: 12, height: 12)
                    } label: { Text("0 – 50: Good") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.9, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("51 – 100: Moderate") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.5, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("101 – 150: Unhealthy for sensitive groups") }
                    legendRow {
                        Circle().fill(Color(red: 1.0, green: 0.1, blue: 0.1)).frame(width: 12, height: 12)
                    } label: { Text("151 – 200: Unhealthy") }
                    legendRow {
                        Circle().fill(Color(red: 0.6, green: 0.0, blue: 0.0)).frame(width: 12, height: 12)
                    } label: { Text("200+: Very unhealthy / Hazardous") }
                    Text("Source: Open-Meteo · 60 major cities")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .frame(minWidth: 260)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func legendRow<Symbol: View, Label: View>(
        @ViewBuilder symbol: () -> Symbol,
        @ViewBuilder label: () -> Label
    ) -> some View {
        HStack(spacing: 8) {
            symbol().frame(width: 16, height: 16)
            label().font(.caption)
        }
    }
}
```

- [ ] **Step 7: Verify all tests pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add GlobeDisplay/UI/ControlPanel/ControlPanelView.swift \
        GlobeDisplay/UI/Components/DataLegendView.swift
git commit -m "feat: add air quality and rivers toggles to overlay toolbar and legend"
```

---

### Task 10: Create rivers texture generation script and PNG asset

**Files:**
- Create: `scripts/generate_rivers_texture.py`
- Create: `GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png` (generated)

- [ ] **Step 1: Create `scripts/generate_rivers_texture.py`**

```python
#!/usr/bin/env python3
"""
Generate a 2048x1024 equirectangular PNG of world rivers for GlobeDisplay.

Dependencies (install once):
    pip install cartopy matplotlib

Output:
    GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png

Commit the generated PNG to the repo. Re-run only if you want to change styling.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from pathlib import Path

WIDTH_PX    = 2048
HEIGHT_PX   = 1024
DPI         = 100
RIVER_COLOR = "#4488CC"
RIVER_ALPHA = 0.6
LINE_WIDTH  = 0.6

OUTPUT = (
    Path(__file__).parent.parent
    / "GlobeDisplay" / "Resources" / "BundledContent" / "rivers_2048x1024.png"
)

fig = plt.figure(
    figsize=(WIDTH_PX / DPI, HEIGHT_PX / DPI),
    facecolor=(0, 0, 0, 0),
)
ax = fig.add_subplot(
    1, 1, 1,
    projection=ccrs.PlateCarree(central_longitude=0),
)
ax.set_extent([-180, 180, -90, 90], crs=ccrs.PlateCarree())
ax.set_position([0, 0, 1, 1])
ax.patch.set_alpha(0)
ax.axis("off")

rivers_feature = cfeature.NaturalEarthFeature(
    category="physical",
    name="rivers_lake_centerlines",
    scale="10m",
    facecolor="none",
    edgecolor=RIVER_COLOR,
)
ax.add_feature(rivers_feature, linewidth=LINE_WIDTH, alpha=RIVER_ALPHA)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(
    OUTPUT,
    dpi=DPI,
    transparent=True,
    bbox_inches="tight",
    pad_inches=0,
    format="png",
)
plt.close(fig)
print(f"Saved: {OUTPUT}")
```

- [ ] **Step 2: Run the script**

```bash
pip install cartopy matplotlib   # skip if already installed
python3 scripts/generate_rivers_texture.py
```
Expected: `Saved: .../GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png`
The file should be ~500 KB–2 MB (pale blue lines on transparent background).

- [ ] **Step 3: Add the PNG to the Xcode project**

In Xcode:
1. Right-click `GlobeDisplay/Resources/BundledContent` in the project navigator
2. Choose "Add Files to GlobeDisplay…"
3. Select `rivers_2048x1024.png`
4. Ensure **"Add to target: GlobeDisplay"** is checked
5. Click Add

Verify `rivers_2048x1024.png` now appears in the `GlobeDisplay` target's **Build Phases → Copy Bundle Resources** list.

- [ ] **Step 4: Verify build and all tests pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_rivers_texture.py \
        "GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png" \
        GlobeDisplay.xcodeproj/project.pbxproj
git commit -m "feat: add rivers PNG asset and dev-time generation script"
```
