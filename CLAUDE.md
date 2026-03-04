# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

This is a **greenfield project** — the Xcode project has not been created yet. Development follows the phases in §6. When starting, create the Xcode project at `GlobeDisplay/GlobeDisplay.xcodeproj` with a SwiftUI lifecycle targeting iPadOS 16.0+.

## Build & Test Commands

Once the Xcode project exists:

```bash
# Build (command line)
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build

# Run all tests
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'

# Run a single test class
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' -only-testing:GlobeDisplayTests/MapProjectionTests
```

Primary development is done in Xcode. Open `GlobeDisplay.xcodeproj` and use Cmd+B to build, Cmd+U to run tests.

## Specialized Subagents

Domain-specific agents live in `.claude/agents/` — use them for focused work:

| Agent file | Domain |
|---|---|
| `renderer.md` | Metal pipeline, `RenderEngine`, `ExternalDisplayManager`, coordinate math |
| `data-feeds.md` | API integration, `DataFeedService`, provider protocols, `GeoEvent` models |
| `content-pipeline.md` | `ContentManager`, `BundleParser`, SOS import, thumbnail generation |
| `ui-design.md` | SwiftUI control interface, `ControlUI` module |
| `testing.md` | Test strategy, fixtures, CI configuration |
| `research.md` | Technical spikes, API evaluation, prototyping |

## Key Architectural Constraints

**External display is the primary output** — the iPad screen is only a controller. `ExternalDisplayManager` must detect the `UIScreen` for the HDMI-connected MagicPlanet and route all `RenderEngine` output there. The built-in display shows only `ControlUI`.

**No 3D rendering** — Metal is used for 2D equirectangular frame compositing only. The MagicPlanet's internal fisheye optics handle sphere mapping in hardware. Never use SceneKit/RealityKit for globe output.

**SOS format is the content standard** — all images are equirectangular 2:1 JPEG/PNG with 0° longitude centered (prime meridian at horizontal midpoint). `ContentManager` and `BundleParser` must conform to the NOAA SOS dataset format to maintain compatibility with the 500+ free datasets in that catalog.

**Swift 6 strict concurrency** — `RenderEngine` is a Swift actor managing the Metal pipeline. All async work uses structured concurrency. No force-unwraps in production code.

## Critical Data Flow

```
DataFeedService (actors per provider)
    → GeoEvent models
    → OverlayCompositor (lat/lon → equirectangular pixel coords via MapProjection)
    → Metal overlay texture

ContentManager (local + bundled content)
    → ContentBundle
    → RenderEngine (Metal compositor)

RenderEngine (base texture + overlay textures → composited frame)
    → ExternalDisplayManager
    → HDMI → MagicPlanet
```

`MapProjection.swift` is the math foundation for the entire overlay system — equirectangular projection means `x = (lon + 180) / 360 * width` and `y = (90 - lat) / 180 * height`.

## Canonical Data Contracts

These are the cross-module data structures. All providers and consumers must conform to them.

**`GeoEvent`** — normalized output from every `DataFeedProvider`:
```swift
struct GeoEvent: Identifiable, Codable, Sendable {
    let id: String
    let type: GeoEventType        // .earthquake, .volcano, .wildfire, .storm, etc.
    let coordinates: CLLocationCoordinate2D
    let magnitude: Double?        // Richter for quakes; VEI for volcanoes
    let depth: Double?            // km, for earthquakes
    let timestamp: Date
    let title: String
    let description: String?
    let source: String
    let sourceURL: URL?
    let properties: [String: AnyCodable]
}
```

**`ContentBundle`** — content package model for all media:
```swift
struct ContentBundle: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let category: ContentCategory  // .planets, .earth, .atmosphere, .ocean, …
    let contentType: ContentType   // .staticImage, .imageSequence, .video
    let resolution: CGSize
    let source: ContentSource      // .bundled, .downloaded, .userImported
    let assets: ContentAssets      // paths to image/video files
    let attribution: String
}
```

**`DataFeedProvider`** — protocol all data providers implement:
```swift
protocol DataFeedProvider: Actor {
    var feedType: DataFeedType { get }
    var updateInterval: TimeInterval { get }
    func fetch() async throws -> [GeoEvent]
    func startAutoRefresh() async
    func stopAutoRefresh() async
}
```

## Rendering Resolution Tiers

| Tier | Resolution | Use case |
|---|---|---|
| Standard | 2048×1024 | Animation, real-time overlays |
| High | 4096×2048 | Static planetary textures |
| Ultra | 8192×4096 | 4K projector models |

Bundled app content ships at 2048×1024 to respect App Store size limits. Higher-resolution assets are downloadable.

---

# GlobeDisplay — Open-Source MagicPlanet Content Display System

## Project Overview

GlobeDisplay is an open-source iPad application that drives a **Global Imagination MagicPlanet** spherical projection globe. The app renders equirectangular-projected imagery and sends it to the globe via the iPad's external-display output (USB-C or Lightning → HDMI adapter). The goal is to provide an educational, interactive experience that showcases planetary surfaces, real-time Earth data (weather, earthquakes, volcanism), and curated thematic datasets—without depending on any proprietary software.

---

## 1. Technical Context

### 1.1 MagicPlanet Hardware

| Property | Detail |
|---|---|
| Display type | Rear-projection acrylic sphere (40 cm – 3 m) |
| Projection format | **Equirectangular (plate carrée)** — 2:1 aspect ratio image mapped onto the sphere by the internal fisheye lens |
| Input | HDMI (the globe's internal projector accepts a standard video signal) |
| Recommended resolutions | 2048×1024 (animation), 4096×2048 (static texture), up to 8192×4096 for 4K projector models |
| Refresh | 30 fps for animated content |

The MagicPlanet's optics handle the equirectangular → spherical mapping in hardware. Our app therefore only needs to output a correctly oriented equirectangular frame to the external display. The internal fisheye lens does the rest.

### 1.2 iPad External Display Pipeline

- **iPadOS 16+** supports full external-display rendering via the `UIScreen` API or SwiftUI's `WindowGroup` scenes.
- Connection: USB-C Digital AV Adapter (or Lightning Digital AV Adapter for older iPads) → HDMI cable → MagicPlanet projector input.
- The app renders content to the **external screen** (the globe) while keeping a control interface on the **iPad's built-in screen**.

### 1.3 Content Format Standard

We adopt the **NOAA Science on a Sphere (SOS) dataset standard** as our primary content format:

- **Static imagery:** JPEG or PNG, equirectangular, 2:1 aspect ratio.
- **Animated sequences:** numbered image sequences (PNG preferred) or MP4 video, equirectangular.
- **Coordinate system:** Geographic (lon/lat). 0° longitude centered; latitude −90° (south) at bottom, +90° (north) at top.
- **Orientation convention (SOS standard):** Prime meridian (0° lon) at horizontal center of image. South Pole at bottom row; North Pole at top row.

This means the app can directly consume the 500+ datasets in NOAA's SOS catalog as well as NASA SVS equirectangular assets.

---

## 2. Product Architecture

```
┌─────────────────────────────────────────────────────────┐
│  iPad (Built-in Display)                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Control UI (SwiftUI)                             │  │
│  │  • Content browser / category selector            │  │
│  │  • Rotation, zoom, speed controls                 │  │
│  │  • Data overlay toggles (earthquakes, volcanoes)  │  │
│  │  • Info panel (educational descriptions)          │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Rendering Engine (Metal / Core Image)            │  │
│  │  • Equirectangular frame compositor               │  │
│  │  • Dynamic overlay renderer (point data → eqrect) │  │
│  │  • Animation sequencer (image seq / video)        │  │
│  └──────────────────┬────────────────────────────────┘  │
│                     │                                   │
│                     ▼                                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │  External Display Output (UIScreen API)           │  │
│  │  → HDMI → MagicPlanet Projector                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 2.1 Core Modules

| Module | Responsibility |
|---|---|
| **ContentManager** | Discovers, indexes, caches, and serves content bundles (static maps, image sequences, video). Handles on-device storage and optional cloud sync. |
| **RenderEngine** | Composites the final equirectangular frame at the target resolution. Uses Metal for GPU-accelerated blending of base maps + overlays. |
| **OverlaySystem** | Converts geospatial point/polygon data (earthquakes, volcanoes, weather) into equirectangular overlay textures in real time. |
| **DataFeedService** | Fetches live data from external APIs (USGS earthquakes, Smithsonian GVP volcanoes, OpenWeatherMap, NASA EONET, etc.) and normalizes it into internal models. |
| **ExternalDisplayManager** | Detects the connected external screen, configures resolution, and drives the render loop to the MagicPlanet. |
| **ControlUI** | SwiftUI-based control interface on the iPad's built-in screen. Browsing, playback, overlay toggles, educational info. |
| **EducationEngine** | Manages educational metadata, descriptions, and guided "stories" that sequence datasets with narration/text. |

---

## 3. Content Categories & Data Sources

### 3.1 Static Planetary Mosaics

| Planet/Body | Source | Format |
|---|---|---|
| Earth (Blue Marble) | NASA Visible Earth / NOAA SOS | JPEG/PNG equirectangular |
| Earth (night lights) | NASA Black Marble | JPEG equirectangular |
| Mars | NASA/JPL Viking & MOLA | JPEG equirectangular |
| Moon | NASA/LROC WAC | JPEG equirectangular |
| Jupiter | NASA/JPL Cassini & Juno | JPEG equirectangular |
| Saturn | NASA/JPL Cassini | JPEG equirectangular |
| Venus (radar) | NASA/JPL Magellan | JPEG equirectangular |
| Mercury | NASA/JHUAPL MESSENGER | JPEG equirectangular |
| Pluto | NASA/JHUAPL New Horizons | JPEG equirectangular |

**Free sources:** [Solar System Scope Textures](https://www.solarsystemscope.com/textures/), [NASA 3D Resources](https://nasa3d.arc.nasa.gov/images), [NASA SVS](https://svs.gsfc.nasa.gov/), [Planet Pixel Emporium](https://planetpixelemporium.com/planets.html)

### 3.2 Dynamic / Real-Time Earth Data

| Dataset | API / Source | Update Cadence |
|---|---|---|
| Earthquakes | [USGS GeoJSON Feed](https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php) | Every 5 min |
| Volcanic activity | Smithsonian GVP / NASA EONET | Daily |
| Cloud cover & weather | OpenWeatherMap / NOAA GFS | Hourly |
| Sea surface temp | NOAA CoralReefWatch / PODAAC | Daily |
| Hurricanes / tropical cyclones | NOAA NHC / JTWC | 6-hourly |
| Wildfires | NASA FIRMS / EONET | Near-real-time |
| Ocean currents | NASA OSCAR / NOAA | Weekly |
| Satellite imagery (true color) | NASA GIBS / Worldview | Daily |

### 3.3 NOAA SOS Catalog (500+ Datasets)

The app should support importing and displaying any dataset from the [NOAA SOS Dataset Catalog](https://sos.noaa.gov/catalog/datasets/). These are pre-formatted equirectangular assets covering atmosphere, biosphere, cryosphere, hydrosphere, land, space, and more.

---

## 4. Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| Language | **Swift 6** | Native iOS performance; concurrency with async/await and actors |
| UI framework | **SwiftUI** | Declarative UI for the control interface; lifecycle management |
| Rendering | **Metal** + **MetalKit** | GPU-accelerated compositing for real-time equirectangular frame output |
| Image processing | **Core Image** / **vImage** | Fast image transformations, color grading, overlay blending |
| Video playback | **AVFoundation** | MP4/H.264/H.265 decoding for animated datasets |
| Networking | **URLSession** + **Swift Concurrency** | Async data fetching with structured concurrency |
| Persistence | **SwiftData** (or Core Data) | Content catalog, favorites, download management |
| Local storage | **FileManager** + structured bundles | On-device content cache |
| Mapping math | Custom **MapProjection** utilities | Lat/lon ↔ pixel coordinate conversions |
| Testing | **XCTest** + **Swift Testing** | Unit and integration tests |
| CI/CD | **Xcode Cloud** or **GitHub Actions** (with `macos-latest`) | Automated builds and test runs |

### 4.1 Minimum Requirements

- iPad with iPadOS 16.0+
- USB-C or Lightning Digital AV Adapter
- HDMI cable
- MagicPlanet globe (any size with HDMI input)
- Internet connection (for dynamic data; offline mode available for cached/bundled content)

---

## 5. Project Structure

```
GlobeDisplay/
├── CLAUDE.md                          ← This file
├── .claude/
│   └── agents/                        ← AI agent configurations
│       ├── renderer.md                ← Rendering & Metal pipeline agent
│       ├── data-feeds.md              ← API integration & data pipeline agent
│       ├── ui-design.md               ← SwiftUI control interface agent
│       ├── content-pipeline.md        ← Content ingestion & management agent
│       ├── testing.md                 ← Test strategy & QA agent
│       └── research.md               ← Technical research & prototyping agent
├── GlobeDisplay.xcodeproj/            ← Xcode project
├── GlobeDisplay/
│   ├── App/
│   │   ├── GlobeDisplayApp.swift      ← App entry point, scene configuration
│   │   └── AppState.swift             ← Global app state (ObservableObject)
│   ├── Models/
│   │   ├── ContentBundle.swift        ← Content package model
│   │   ├── PlanetaryBody.swift        ← Planet metadata
│   │   ├── GeoEvent.swift             ← Earthquake/volcano/storm event model
│   │   ├── DataFeed.swift             ← API feed configuration
│   │   └── Overlay.swift              ← Overlay layer model
│   ├── Rendering/
│   │   ├── RenderEngine.swift         ← Main compositor
│   │   ├── MetalRenderer.swift        ← Metal pipeline setup
│   │   ├── EquirectangularShaders.metal ← GPU shaders
│   │   ├── OverlayCompositor.swift    ← Blends overlays onto base map
│   │   └── AnimationSequencer.swift   ← Drives image-sequence playback
│   ├── ExternalDisplay/
│   │   ├── ExternalDisplayManager.swift ← UIScreen detection & configuration
│   │   ├── GlobeOutputView.swift      ← The view rendered to HDMI
│   │   └── DisplayCalibration.swift   ← Rotation offset, brightness, orientation
│   ├── DataFeeds/
│   │   ├── DataFeedService.swift      ← Coordinator for all feeds
│   │   ├── USGSEarthquakeProvider.swift ← USGS earthquake API client
│   │   ├── VolcanoProvider.swift       ← Smithsonian GVP / EONET
│   │   ├── WeatherProvider.swift       ← Cloud cover, storms
│   │   ├── NASAEONETProvider.swift     ← NASA Earth Observatory events
│   │   └── SatelliteImageryProvider.swift ← NASA GIBS tiles
│   ├── ContentManagement/
│   │   ├── ContentManager.swift       ← Discovery, indexing, caching
│   │   ├── ContentDownloader.swift    ← Background download manager
│   │   ├── BundleParser.swift         ← Parses SOS-format dataset bundles
│   │   └── ThumbnailGenerator.swift   ← Preview generation
│   ├── UI/
│   │   ├── ControlPanel/
│   │   │   ├── ControlPanelView.swift ← Main control interface
│   │   │   ├── ContentBrowserView.swift ← Browse & select content
│   │   │   ├── CategoryGridView.swift  ← Category navigation
│   │   │   ├── PlaybackControlsView.swift ← Play/pause, speed, rotation
│   │   │   └── OverlayTogglesView.swift   ← Enable/disable data overlays
│   │   ├── Education/
│   │   │   ├── InfoPanelView.swift    ← Educational descriptions
│   │   │   ├── StoryPlayerView.swift  ← Guided narrative sequences
│   │   │   └── QuizView.swift         ← Interactive quiz mode
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift     ← App settings
│   │   │   ├── DisplaySettingsView.swift ← Resolution, orientation, calibration
│   │   │   └── DataSourceSettingsView.swift ← API keys, update intervals
│   │   └── Components/
│   │       ├── GlobePreview.swift     ← 3D preview (SceneKit) on iPad screen
│   │       ├── DataLegendView.swift   ← Color scale legends
│   │       └── LoadingOverlay.swift   ← Download/processing progress
│   ├── Utilities/
│   │   ├── MapProjection.swift        ← Equirectangular math utilities
│   │   ├── CoordinateConverter.swift  ← Lat/lon ↔ pixel ↔ 3D conversions
│   │   ├── ImageUtilities.swift       ← Resize, crop, format conversion
│   │   └── NetworkMonitor.swift       ← Connectivity state
│   └── Resources/
│       ├── Assets.xcassets/           ← App icons, colors
│       ├── BundledContent/            ← Shipped-with-app content (small selection)
│       └── Shaders/                   ← Additional Metal shader files
├── GlobeDisplayTests/
│   ├── RenderEngineTests.swift
│   ├── DataFeedServiceTests.swift
│   ├── ContentManagerTests.swift
│   ├── MapProjectionTests.swift
│   └── ExternalDisplayTests.swift
├── GlobeDisplayUITests/
│   └── ControlPanelUITests.swift
└── Documentation/
    ├── ARCHITECTURE.md                ← Detailed architecture document
    ├── CONTENT_GUIDE.md               ← How to create/import custom content
    ├── API_REFERENCE.md               ← Data feed API documentation
    └── SETUP_GUIDE.md                 ← Hardware setup instructions
```

---

## 6. Development Phases

### Phase 1 — Foundation (Weeks 1–3)
**Goal:** Render a static equirectangular image to an external display.

- [ ] Create Xcode project with SwiftUI lifecycle
- [ ] Implement `ExternalDisplayManager` (detect & configure external screen)
- [ ] Build basic Metal rendering pipeline for equirectangular frames
- [ ] Display a bundled Blue Marble Earth texture on the globe
- [ ] Basic control UI: content selector, rotation controls
- [ ] Unit tests for coordinate math and display detection

### Phase 2 — Content System (Weeks 4–6)
**Goal:** Browse and display multiple planetary bodies and static datasets.

- [ ] Design and implement `ContentBundle` model and `ContentManager`
- [ ] Bundle 8–10 planetary textures (all solar system bodies)
- [ ] Build content browser UI with categories and thumbnails
- [ ] Implement image-sequence animation playback
- [ ] MP4 video dataset support via AVFoundation
- [ ] Add rotation (longitude offset) and animation speed controls
- [ ] Support NOAA SOS dataset bundle format for importing community content

### Phase 3 — Live Data Overlays (Weeks 7–10)
**Goal:** Real-time earthquake, volcano, and weather overlays on Earth.

- [ ] Implement `DataFeedService` architecture with provider protocol
- [ ] Build `USGSEarthquakeProvider` (GeoJSON → `GeoEvent` models)
- [ ] Build `VolcanoProvider` (Smithsonian GVP / NASA EONET)
- [ ] Implement `OverlayCompositor` — lat/lon point data → equirectangular overlay texture
- [ ] GPU-accelerated overlay blending in Metal pipeline
- [ ] Animated markers (pulsing earthquake dots scaled by magnitude, volcano icons)
- [ ] Cloud cover / weather overlay from NOAA or OpenWeatherMap
- [ ] Overlay toggle controls in the UI
- [ ] Color legends and data attribution

### Phase 4 — Education & Polish (Weeks 11–14)
**Goal:** Guided educational experiences and app polish.

- [ ] `EducationEngine` — curated "stories" that sequence datasets with descriptions
- [ ] Info panel with rich educational text per dataset
- [ ] Interactive quiz mode
- [ ] Display calibration tool (rotation offset, brightness, orientation flip)
- [ ] Offline mode (graceful degradation when no internet)
- [ ] Accessibility (VoiceOver, Dynamic Type on control UI)
- [ ] Performance profiling and optimization
- [ ] App icon, launch screen, onboarding flow

### Phase 5 — Distribution & Community (Weeks 15–16)
**Goal:** Release and enable community contributions.

- [ ] TestFlight beta distribution
- [ ] App Store submission
- [ ] Open-source repository setup (LICENSE, CONTRIBUTING.md)
- [ ] Content creation guide for community contributors
- [ ] Documentation site

---

## 7. Key Design Decisions

### 7.1 Why an iPad App (Not Desktop)?
- MagicPlanet globes in educational settings (museums, classrooms) benefit from a portable, touch-based controller.
- iPads natively support external displays via HDMI adapters.
- Educators and docents can walk around with the iPad as a remote control while the globe displays content.

### 7.2 Why Metal (Not SceneKit/RealityKit)?
- We are NOT rendering a 3D sphere on-screen. The MagicPlanet's optics do the sphere mapping.
- We only need to output a flat equirectangular frame, but we need to composite multiple layers (base map + overlays) at high resolution and 30 fps.
- Metal gives us direct GPU access for efficient image compositing without the overhead of a 3D scene graph.

### 7.3 Why SOS Dataset Compatibility?
- NOAA's SOS catalog has 500+ free, curated, educational datasets ready to use.
- SOS is the de facto standard for spherical display content in museums and science centers.
- Aligning with this standard means instant access to a large content library and community.

### 7.4 Equirectangular Orientation Convention
- All imagery uses the **SOS/plate carrée convention**: 0° longitude at image center, south at bottom, north at top.
- The `DisplayCalibration` module handles any rotational offset needed to align the image with the physical globe's orientation.

---

## 8. API & Data Feed Reference

### Earthquake Data (USGS)
```
GET https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson
```
Returns GeoJSON FeatureCollection with magnitude, coordinates, depth, time. Updated every 5 minutes. No API key required.

### Volcanic Activity (NASA EONET)
```
GET https://eonet.gsfc.nasa.gov/api/v3/events?category=volcanoes
```
Returns JSON with event geometry (lat/lon), title, date range. No API key required.

### Natural Events (NASA EONET)
```
GET https://eonet.gsfc.nasa.gov/api/v3/events
```
Categories: wildfires, severe storms, floods, volcanoes, sea/lake ice. No API key required.

### Satellite Imagery (NASA GIBS)
```
https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/{layer}/default/{date}/{resolution}/{z}/{y}/{x}.png
```
Tile-based; requires stitching into equirectangular mosaic. No API key required.

### Weather Data (OpenWeatherMap)
```
GET https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={key}
```
Requires free API key. For cloud overlay, use the weather map tiles API.

---

## 9. Coding Standards & Conventions

- **Language:** Swift 6 with strict concurrency checking enabled
- **Architecture:** MVVM with SwiftUI; service layer for data access
- **Concurrency:** Use Swift structured concurrency (async/await, actors) for all async work. The `RenderEngine` actor manages the Metal pipeline. `DataFeedService` uses async sequences.
- **Error handling:** Typed errors with `Result` or `throws`. Never force-unwrap in production code.
- **Naming:** Swift API Design Guidelines. Types are `PascalCase`, properties/methods are `camelCase`.
- **Documentation:** All public APIs must have doc comments (`///`). Complex algorithms get inline explanations.
- **Testing:** Minimum 80% code coverage for Models, DataFeeds, and Utilities. UI tests for critical flows.
- **Dependencies:** Minimize third-party dependencies. Prefer system frameworks (Metal, AVFoundation, Core Image).
- **Accessibility:** All control UI elements must have accessibility labels. Support Dynamic Type.
- **Git:** Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`). Feature branches off `main`.

---

## 10. Performance Targets

| Metric | Target |
|---|---|
| Frame rate (external display) | ≥ 30 fps |
| Static content load time | < 2 seconds |
| Overlay update latency | < 500 ms from data fetch to render |
| Memory footprint | < 500 MB (including textures) |
| App launch to globe output | < 5 seconds |
| Offline startup | < 3 seconds with cached content |

---

## 11. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| iPad external display API limitations | Could restrict resolution or refresh rate | Test on target hardware early (Phase 1); fallback to AirPlay if needed |
| MagicPlanet orientation mismatch | Content appears rotated/flipped on globe | Calibration tool with rotation offset and mirror settings |
| Large texture memory pressure | Crashes on older iPads | Stream image tiles; use mipmaps; support multiple resolution tiers |
| API rate limits on live data | Stale overlays | Cache aggressively; respect update cadences; offline fallback |
| App Store review (external display usage) | Rejection risk | Follow Apple's external display guidelines; clearly document educational purpose |

---

## 12. License & Attribution

- **App license:** MIT (open source)
- **Content:** NASA/NOAA imagery is public domain (U.S. government works). Third-party textures must be attributed per their licenses.
- **APIs:** All selected APIs are free-tier compatible. Attribute data sources in the app's info panel.
