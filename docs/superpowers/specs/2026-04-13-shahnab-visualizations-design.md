# Design: Shahnab Visualization Additions

**Date:** 2026-04-13  
**Status:** Approved  
**Inspired by:** [github.com/Shahnab](https://github.com/Shahnab) — `Atmosphere`, `Seismic3D`, `earthrivers` repos

---

## Overview

Three additions to GlobeDisplay's overlay system, all fitting within the existing `DataFeedProvider` / `OverlayCompositor` / `RenderEngine` architecture:

1. **Air quality feed** — Open-Meteo API, 60 major cities, colored point markers
2. **Depth-scaled earthquake markers** — shallow quakes visually distinct from deep ones
3. **Rivers static overlay** — pre-rendered equirectangular PNG composited below live events

---

## Architecture Approach

Option B was chosen: introduce a lightweight `StaticOverlayLayer` enum for bundled raster overlays (rivers and future additions like tectonic plates, population density), keeping them separate from the live event overlay pipeline. Live feeds and static layers composite independently in `RenderEngine`.

Rendering order: **base map → rivers texture (if enabled) → live event overlay**

---

## 1. Air Quality Provider

### Data Source
Open-Meteo air quality API — free, no API key required, hourly data.

```
GET https://air-quality-api.open-meteo.com/v1/air-quality
    ?latitude={lat}&longitude={lon}&current=us_aqi,pm2_5
```

### Implementation

**New file:** `GlobeDisplay/DataFeeds/AirQualityProvider.swift`
- Actor conforming to `DataFeedProvider`
- 60 hardcoded major world cities (lat/lon constants)
- Fetches all cities concurrently via `withTaskGroup`
- Maps each response to a `GeoEvent` with `magnitude` holding the AQI value (0–500 scale)
- `updateInterval`: 3600 s (1 hour)

**Model changes:**
- `GeoEventType` — add `.airQuality` case
- `DataFeedType` — add `.airQuality` case:
  - `displayName`: `"Air Quality"`
  - `systemImage`: `"aqi.medium"`
  - `updateInterval`: 3600 s
  - `overlayColor`: `.cyan`
  - `eventType`: `.airQuality`

**AppState:** add `airQualityEvents: [GeoEvent]`

**DataFeedService:** register `AirQualityProvider`, add cases in `provider(for:)`, `publish()`, `clearEvents()`

### Compositor
New `drawAirQuality(_ events: [GeoEvent], in context: CGContext)` in `OverlayCompositor`:

| AQI Range | Color | Label |
|---|---|---|
| 0–50 | Green `(0.0, 0.8, 0.2)` | Good |
| 51–100 | Yellow `(1.0, 0.9, 0.0)` | Moderate |
| 101–150 | Orange `(1.0, 0.5, 0.0)` | Unhealthy for sensitive groups |
| 151–200 | Red `(1.0, 0.1, 0.1)` | Unhealthy |
| 200+ | Dark red `(0.6, 0.0, 0.0)` | Very unhealthy / Hazardous |

- Fixed circle radius: 12px
- Alpha: 0.75
- White stroke ring at radius + 1 (1.5px line width), consistent with earthquake markers
- Dateline wrap applied (same `dateline_mirrorLongitude` helper)

`renderOverlay()` signature gains an `airQuality: [GeoEvent]` parameter; guard condition updated to include it.

---

## 2. Depth-Scaled Earthquake Markers

**Scope:** `OverlayCompositor.drawEarthquakes()` only — no model or data changes.

### Depth Classification

| Depth | Class | Opacity multiplier | Extra ring |
|---|---|---|---|
| 0–70 km (or nil) | Shallow | 1.0× | Yes — stroke ring at radius + 4, 1.5px, white, alpha 0.6 |
| 70–300 km | Intermediate | 0.75× | No |
| 300+ km | Deep | 0.50× | No |

### Combined Signal
- **Size** encodes magnitude (unchanged): `radius = clamp(magnitude * 5, 4, 30)`
- **Color** encodes age (unchanged): red < 1h, orange < 6h, yellow otherwise
- **Opacity** encodes depth (new): full → intermediate → faded
- **Shallow ring** (new): second `strokeRing` drawn when depth < 70 km or depth is nil

`nil` depth is treated as shallow — the most common case and the safe default for display purposes.

---

## 3. Rivers Static Overlay

### Asset
**File:** `GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png`
- 2048×1024 PNG, transparent background
- Pale blue river lines (`#4488CC`, ~60% opacity) on transparency
- Source: Natural Earth 10m rivers + lake centerlines dataset (public domain)
- Generated once at dev time; committed to the repo as a static asset

**Generation script:** `scripts/generate_rivers_texture.py`
- Dependencies: `cartopy`, `matplotlib`, `shapely`
- Renders Natural Earth 10m rivers shapefile onto a 2048×1024 equirectangular canvas
- Output: `GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png`

### New Type
**New file:** `GlobeDisplay/Rendering/StaticOverlayLayer.swift`

```swift
enum StaticOverlayLayer: String, CaseIterable, Hashable, Sendable {
    case rivers

    var displayName: String {
        switch self { case .rivers: "Rivers" }
    }

    var systemImage: String {
        switch self { case .rivers: "water.waves" }
    }

    var bundledAssetName: String {
        switch self { case .rivers: "rivers_2048x1024" }
    }
}
```

### Rendering
**`RenderEngine`:**
- Load `rivers_2048x1024.png` as an `MTLTexture` at startup (once, cached)
- When `AppState.activeStaticOverlays.contains(.rivers)`, composite rivers texture between base map and live overlay
- Compositing order: base map → rivers → live event overlay

### State & UI
**`AppState`:** add `activeStaticOverlays: Set<StaticOverlayLayer> = []`

**`OverlayTogglesView`:** add a rivers toggle row using `StaticOverlayLayer.rivers.displayName` / `.systemImage`, binding to `appState.activeStaticOverlays`

---

## Files Changed

| File | Change |
|---|---|
| `GlobeDisplay/Models/GeoEvent.swift` | Add `.airQuality` to `GeoEventType` |
| `GlobeDisplay/Models/DataFeed.swift` | Add `.airQuality` to `DataFeedType` |
| `GlobeDisplay/App/AppState.swift` | Add `airQualityEvents`, `activeStaticOverlays` |
| `GlobeDisplay/DataFeeds/AirQualityProvider.swift` | **New** — 60-city Open-Meteo provider |
| `GlobeDisplay/DataFeeds/DataFeedService.swift` | Register `AirQualityProvider`, add routing cases |
| `GlobeDisplay/Rendering/OverlayCompositor.swift` | Add `drawAirQuality()`, update `drawEarthquakes()` with depth, update `renderOverlay()` signature |
| `GlobeDisplay/Rendering/StaticOverlayLayer.swift` | **New** — static overlay enum |
| `GlobeDisplay/Rendering/RenderEngine.swift` | Load rivers texture, composite when enabled |
| `GlobeDisplay/UI/ControlPanel/OverlayTogglesView.swift` | Add rivers and air quality toggles |
| `GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png` | **New** — pre-rendered asset |
| `scripts/generate_rivers_texture.py` | **New** — dev-time generation script |

---

## Out of Scope

- Global temperature choropleth (static data, no live API identified)
- Population density overlay (needs bundled raster dataset, separate effort)
- AQI threshold alerts or push notifications
- Air quality historical data
