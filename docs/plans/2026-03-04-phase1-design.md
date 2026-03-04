# Phase 1 Design — Foundation

**Date:** 2026-03-04
**Status:** Approved
**Goal:** Render a static equirectangular image to the MagicPlanet globe via HDMI, with a rotation control on the iPad.

---

## 1. Project Setup

- **Tool:** XcodeGen — project generated from `project.yml`, keeping configuration version-controlled
- **Targets:** `GlobeDisplay` (app), `GlobeDisplayTests` (unit), `GlobeDisplayUITests` (UI)
- **Deployment target:** iPadOS 16.0+
- **Language:** Swift 6, strict concurrency enabled
- **Bundle ID:** `com.globedisplay.app`
- **Capabilities:** Metal (`UIRequiredDeviceCapabilities`), `UISupportsDocumentBrowser` (stubbed for Phase 2 SOS import)
- **Code signing:** Personal team (free Apple account), automatic signing

**`AppState`** is an `@Observable` class injected as an environment object at the root. Phase 1 properties:

```swift
@Observable
class AppState {
    var currentContent: ContentBundle?
    var rotationOffset: Double = 0.0   // degrees, 0–360
    var displayConnected: Bool = false
    var displayResolution: CGSize = CGSize(width: 2048, height: 1024)
}
```

---

## 2. External Display & Dual-Screen Pipeline

**`ExternalDisplayManager`** — main-thread class (not actor), owns the external `UIWindow`.

- Registers for `UIScreen.didConnectNotification` / `UIScreen.didDisconnectNotification` on init
- On connect:
  1. Create `UIWindow` sized to the external screen's bounds
  2. Set root to `UIHostingController<GlobeOutputView>`
  3. Make window key and visible
  4. Set `AppState.displayConnected = true`
- On disconnect: tear down window, reset state, show "Connect your globe" banner in control UI

**`GlobeOutputView`** — `MTKView` subclass acting as `MTKViewDelegate`.

- `isPaused = false`, `enableSetNeedsDisplay = false` → continuous 30fps loop
- Each frame calls `RenderEngine.draw(in:renderPassDescriptor:)` on the actor

**`DisplayCalibration`** — stores user-settable render resolution (default `2048×1024`) independent of the screen's native resolution. The Metal pipeline renders to this size; the display scales as needed.

---

## 3. Metal Rendering Pipeline

**`RenderEngine`** — Swift actor. Owns all Metal resources.

| Property | Type | Purpose |
|---|---|---|
| `device` | `MTLDevice` | GPU handle |
| `commandQueue` | `MTLCommandQueue` | Command submission |
| `pipelineState` | `MTLRenderPipelineState` | Compiled shaders |
| `baseTexture` | `MTLTexture?` | Current equirectangular map |
| `rotationOffset` | `Double` | Longitude shift (0.0–1.0 normalized) |

**Texture loading:** `ContentManager.loadTexture(for:)` returns a `CGImage`. `RenderEngine` converts it to `MTLTexture` via `MTKTextureLoader` asynchronously. The previous texture remains visible until the new one is ready.

**`EquirectangularShaders.metal`** — single render pass over a full-screen quad:
- Vertex shader: outputs four corners of the screen
- Fragment shader: samples the base texture with UV offset for rotation
  ```metal
  float2 uv = in.texCoord;
  uv.x = fract(uv.x + rotationOffset);  // fract() handles date-line wrap
  return baseTexture.sample(textureSampler, uv);
  ```

**Render loop:** Actor encodes render command → commits command buffer → presents drawable. Clears to black if no texture loaded.

**Phase 1 scope:** One base texture, one shader pass, one rotation parameter. Overlay blending slots in during Phase 3 without modifying the shader interface.

---

## 4. Control UI

**Layout:** `NavigationSplitView` (landscape), two columns.

**Sidebar:**
- List of content categories (Phase 1: "Planets" only)
- SF Symbol icon + label per row

**Detail:**
- `LazyVGrid` with adaptive columns (minimum 160pt) — works on all iPad sizes
- `ContentBundle` cards: thumbnail, title, resolution badge
- Tapping a card calls `RenderEngine.loadTexture(for:)` and sets `AppState.currentContent`

**Bundled Phase 1 textures (all 2048×1024):**
1. Earth — Blue Marble
2. Earth — Night Lights
3. Mars
4. Moon
5. Jupiter

**Bottom toolbar (persistent):**
- **Rotation slider** — 0°–360°, "Longitude offset" label, bound to `AppState.rotationOffset`, updates `RenderEngine` in real time
- **Display status indicator** — green dot "Globe connected" / amber dot "No display detected". Tapping when disconnected shows HDMI setup instructions sheet.

**UI defaults:** Dark mode (`preferredColorScheme(.dark)`), large touch targets (min 44×44pt), no hardcoded sizes.

---

## 5. Testing

### Unit Tests

**`MapProjectionTests`** (highest priority):
- Standard conversion: 0°lon/0°lat → center pixel
- Poles: 90°N → top row, 90°S → bottom row
- Date line: 180° and -180° → same pixel column
- SOS centering: 0°lon → `width/2`
- Round-trip: pixel → lat/lon → pixel with < 0.5px error
- Boundary: coordinates exactly at image edges

**`DisplayCalibrationTests`:**
- Rotation offset > 360° wraps correctly
- Negative rotation offset wraps correctly

**`ContentBundleTests`:**
- `Codable` round-trip: encode → decode → assert all fields equal

### Test Fixtures

`TestFixtures/`:
- `test_equirectangular.png` — 256×128 solid-color PNG for image-loading tests

### Explicitly Out of Scope for Phase 1 Tests
- Metal GPU rendering (not unit-testable without device)
- External display connection (physical hardware; covered by manual QA)
- Network calls (no networking in Phase 1)

### Manual QA Checklist (run on hardware after each build)
1. App launches, iPad UI appears
2. Plug in HDMI adapter → "Globe connected" indicator turns green
3. Select Blue Marble → globe shows the image
4. Move rotation slider → image shifts horizontally on globe in real time
5. Unplug HDMI → indicator returns to amber

---

## Out of Scope for Phase 1

- Animated datasets / image sequences (Phase 2)
- Live data overlays (Phase 3)
- Content downloading (Phase 2)
- Educational info panel (Phase 4)
- Overlay compositor (Phase 3)
