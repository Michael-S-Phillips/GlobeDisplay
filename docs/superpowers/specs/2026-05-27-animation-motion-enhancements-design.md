# Design: Animation & Motion Enhancements + App Store Release Readiness

**Date:** 2026-05-27
**Status:** Approved
**Goal:** Add more animated/motion options to GlobeDisplay and bring it to App Store submission readiness.

---

## Overview

This effort spans three independent tracks, sequenced in this order:

1. **Track 1 — Finish & merge Shahnab visualizations** (already specced, planned, and code-complete on `feature/shahnab-visualizations`). Verify build + tests, then merge to `main`. Prerequisite for a shippable 1.0.
2. **Track 2 — Animation/motion features** (the new design work in this spec): auto-rotation, real-time video playback, dataset crossfade transitions, and richer image-sequence controls (loop / ping-pong / scrub).
3. **Track 3 — App Store release readiness**: privacy manifest, version/build bump, icon + metadata audit, archive/validation, and a submission checklist the user executes (they hold the Apple Developer account and App Store Connect access).

This document specifies Track 2 in full and Track 3 as a checklist. Track 1 is covered by its existing plan at `docs/superpowers/plans/2026-04-13-shahnab-visualizations.md`.

---

## Current Architecture (relevant facts)

- `RenderEngine` (`RenderEngine.swift:33`) is a `@MainActor` `NSObject` conforming to `MTKViewDelegate`. It composites a `baseTexture` + optional `overlayTexture` each frame in `draw(in:)`, applying `rotationOffset` (degrees) via the fragment shader. The Metal display link drives the loop at the view's refresh rate — **no separate animation timer exists for rotation**.
- `AnimationSequencer` (`AnimationSequencer.swift:24`) is `@MainActor`. It decodes a directory of numbered frames into `[CGImage]` and pushes them to the engine on a `Task` loop at `framerate`. Advance logic is hard-coded looping: `currentFrameIndex = (currentFrameIndex + 1) % frameCount`. `pause()`/`stop()` exist but are not surfaced in the UI.
- Content selection happens in `ContentBrowserView.loadContent` (`ContentBrowserView.swift:103`): `.imageSequence` builds and plays an `AnimationSequencer`; `.staticImage` and `.video` both just load a single `CGImage` (video shows only a poster frame today).
- `VideoFrameExtractor` (`VideoFrameExtractor.swift:25`) does an **offline** sampled extract-to-JPEG (≤120 frames @ 5 fps). It is not real video playback and is not the basis for Track 2's video feature.
- Playback/motion controls are inline in `BottomToolbar` inside `ControlPanelView.swift`. The `PlaybackControlsView.swift` named in CLAUDE.md does **not** yet exist.

---

## Architecture Approach

**Video playback — Approach A (chosen): real-time AVPlayer → Metal.**
A new `VideoPlaybackController` owns an `AVPlayer` + `AVPlayerItemVideoOutput` + `CVMetalTextureCache`. On each `draw(in:)`, the engine pulls the current `CVPixelBuffer` and uses it (via the texture cache) as the base texture. This gives true streaming playback at full length/fps, and seeking, scrubbing, looping, and rate control come directly from `AVPlayer`.

Rejected — Approach B (extract-to-sequence into `AnimationSequencer`): nearly free to build but produces choppy, time-compressed, memory-heavy playback. Unsuitable for real video datasets.

All four motion features keep the existing single-base-texture compositing model; each is additive and isolated.

---

## 1. Auto-Rotation / Continuous Spin

### Behavior
Hands-free continuous longitude rotation at a configurable speed and direction, independent of content type (applies to any base map, sequence, or video).

### Implementation

**`RenderEngine`:**
- Add `var autoRotationSpeed: Double = 0.0` — degrees per second; sign encodes direction (`+` east, `−` west), `0` = off.
- Track `private var lastFrameTimestamp: CFTimeInterval?`. In `draw(in:)`, compute `dt = now - last`; when `autoRotationSpeed != 0`, advance `rotationOffset = (rotationOffset + autoRotationSpeed * dt).truncatingRemainder(dividingBy: 360)` (normalize to 0–360). Reset `lastFrameTimestamp` when spin toggles on to avoid a `dt` spike.

**`AppState`:**
- `var autoRotationEnabled: Bool = false`
- `var autoRotationSpeed: Double = 6.0` — degrees/sec (≈ one revolution per minute), range 1–30.

**Slider reconciliation:** While spinning, the engine owns `rotationOffset` and does **not** write it back to `AppState` every frame (avoids 30 fps `@Observable` churn / SwiftUI thrash). When spin is turned **off**, sync `AppState.rotationOffset = engine.rotationOffset` once so the manual slider resumes from the current position. The manual rotation slider sets the base offset when spin is off.

### UI
In the new `PlaybackControlsView`: a spin toggle (`arrow.clockwise` / play-style), a direction control (E/W), and a speed slider (1–30°/s). Always available regardless of content type.

---

## 2. Real-Time Video Playback

### Implementation

**New file:** `GlobeDisplay/Rendering/VideoPlaybackController.swift` — `@MainActor final class`.
- Owns `AVPlayer`, `AVPlayerItem`, `AVPlayerItemVideoOutput` (pixel format `kCVPixelFormatType_32BGRA`), and a `CVMetalTextureCache` built from `engine.device`.
- `load(url:)` — builds the player item and output, attaches output, prepares for display.
- `play()` / `pause()` / `seek(toProgress:)` / `setRate(_:)` — thin wrappers over `AVPlayer`.
- `loopEnabled: Bool` — when true, observe `AVPlayerItemDidPlayToEndTime` and seek to zero.
- `copyCurrentFrame(to engine:)` — called from the engine's draw loop: if `output.hasNewPixelBuffer(forItemTime:)`, copy the buffer into a Metal texture via the cache and assign it as `engine.baseTexture`.
- `progress: Double` (0–1) and `duration`/`currentTime` for the scrub timeline.

**`RenderEngine`:**
- Add `var videoController: VideoPlaybackController?`. At the top of `draw(in:)`, if set, call `videoController?.copyCurrentFrame(to: self)` before compositing. Mutually exclusive with `animationSequencer` (selecting one clears the other, mirroring existing `animationSequencer = nil` resets).

**`ContentBrowserView.loadContent`:** split `.video` out of the shared `.staticImage` case. The `.video` case resolves the local file URL (same bundle/Documents/absolute-path resolution as sequences), creates a `VideoPlaybackController`, wires it to the engine, and starts playback. Stop/teardown on content switch alongside the existing sequencer teardown.

`VideoFrameExtractor` remains for thumbnail/poster generation but is no longer the playback path.

---

## 3. Smooth Dataset Transitions (Crossfade)

### Behavior
When the base map changes (planet → planet, dataset → dataset), crossfade from the outgoing image to the incoming one over a configurable duration instead of a hard cut. Overlays are not crossfaded — they appear/update normally.

### Implementation

**Shader (`EquirectangularShaders.metal`):** the fragment function samples a new base (index 0) and a previous base (index 2; overlay stays at index 1) and mixes by a `transitionProgress` uniform (0 = show previous, 1 = show new). Extend the `Uniforms` struct in both the shader and `RenderEngine` with `transitionProgress: Float`.

**`RenderEngine`:**
- Add `private var prevBaseTexture: MTLTexture?`, `private var transitionProgress: Double = 1.0`, `private var transitionDuration: Double` (from settings).
- When a new base texture is assigned via a new `setBaseTexture(_:animated:)` entry point, move the old texture into `prevBaseTexture` and set `transitionProgress = 0`. In `draw(in:)`, advance `transitionProgress` toward 1 by `dt / transitionDuration`; pass a 1×1 clear texture for `prevBaseTexture` when none is set.
- `transitionDuration == 0` short-circuits to an instant swap (no allocation of the previous-texture path).

**Scope note:** Crossfade applies to `loadTexture(from:)` (static images) and the first frame on a content switch. Per-frame animation/video updates use the existing direct base-texture path (no crossfade between consecutive animation frames).

**`AppState` / Settings:** `var transitionDuration: Double = 0.6` (range 0–1.5 s; 0 disables). Surfaced in `DisplaySettingsView`.

---

## 4. Better Image-Sequence Controls (Loop / Ping-Pong / Scrub)

### Implementation

**`AnimationSequencer`:**
- Add `enum PlaybackMode: String, CaseIterable, Sendable { case loop, once, pingPong }` and `var playbackMode: PlaybackMode = .loop`.
- Replace the hard-coded `% frameCount` advance with mode-aware stepping:
  - `.loop` — wrap to 0 at the end (current behavior).
  - `.once` — stop (pause) at the final frame.
  - `.pingPong` — track `private var direction: Int = 1`; reverse at both ends.
- Add `func seek(toProgress: Double)` — set `currentFrameIndex = Int((frameCount - 1) * clamp(progress, 0, 1))`; valid whether playing or paused.
- Expose `var progress: Double { frameCount > 0 ? Double(currentFrameIndex) / Double(frameCount - 1) : 0 }`. `currentFrameIndex`/`frameCount`/`isPlaying` already exist.

### UI
In `PlaybackControlsView`, for `.imageSequence` and `.video` content: a play/pause button (wraps `pause()`/`play(engine:)` or video play/pause), a scrubbable timeline `Slider` bound to `progress`/`seek(toProgress:)`, the existing speed slider, and a loop-mode `Picker` (sequence only; video uses its own `loopEnabled` toggle).

---

## 5. UI Consolidation (Targeted Refactor)

`BottomToolbar` in `ControlPanelView.swift` already hosts five inline control clusters (display status, rotation, projection, radius, animation speed, overlay toggles). Adding spin + transport + scrub + loop-mode inline would overload it.

**Change:** Extract the documented-but-missing `GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift`. It owns the motion/playback cluster: spin toggle + speed, transport (play/pause), scrub timeline, loop-mode picker, and the existing animation-speed slider — each shown contextually by `currentContent?.contentType`. `BottomToolbar` keeps display status, projection, radius, rotation, and overlay toggles, and embeds `PlaybackControlsView`. No behavior change to the retained controls; this is decluttering plus the new controls in one place.

---

## Files Changed (Track 2)

| File | Change |
|---|---|
| `GlobeDisplay/App/AppState.swift` | Add `autoRotationEnabled`, `autoRotationSpeed`, `transitionDuration` |
| `GlobeDisplay/Rendering/RenderEngine.swift` | Auto-rotation (`autoRotationSpeed`, dt tracking); `videoController` hook in `draw(in:)`; crossfade (`prevBaseTexture`, `transitionProgress`, `setBaseTexture(_:animated:)`) |
| `GlobeDisplay/Rendering/EquirectangularShaders.metal` | Add `transitionProgress` to `Uniforms`; sample + mix previous base (index 2) |
| `GlobeDisplay/Rendering/VideoPlaybackController.swift` | **New** — AVPlayer → Metal real-time playback |
| `GlobeDisplay/Rendering/AnimationSequencer.swift` | `PlaybackMode` (loop/once/pingPong), `seek(toProgress:)`, `progress` |
| `GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift` | **New** — spin, transport, scrub, loop-mode, speed cluster |
| `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift` | Embed `PlaybackControlsView`; remove the inline animation-speed slider |
| `GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift` | Real `.video` playback path; route base-map loads through `setBaseTexture(_:animated:)` |
| `GlobeDisplay/UI/Settings/DisplaySettingsView.swift` | Add transition-duration control |

---

## Testing (Track 2)

XCTest only (Swift Testing is unavailable in this project).

- `AnimationSequencerTests` — `seek(toProgress:)` clamps and maps to the right index; `progress` round-trips; ping-pong reverses at both ends; `once` stops at the final frame; `loop` wraps.
- `RenderEngineTests` — auto-rotation advances `rotationOffset` by `speed * dt` and wraps past 360; `setBaseTexture(_:animated:)` resets `transitionProgress` to 0 and reaches 1 after `transitionDuration`; `transitionDuration == 0` swaps instantly.
- `VideoPlaybackControllerTests` — `seek(toProgress:)` maps to the right `CMTime`; `loopEnabled` toggles end-time observation; `progress` derives from current/duration. (Frame-copy path validated manually on device — Metal/`CVMetalTextureCache` is not unit-testable in the simulator.)
- Manual on-device verification: spin at several speeds/directions; switch datasets and confirm crossfade; play an MP4 dataset with scrub + loop; ping-pong a time-lapse sequence — all on the external display at ≥30 fps.

---

## Track 3 — App Store Release Readiness (Checklist)

Codeable by Claude:
- **Privacy manifest** — add `GlobeDisplay/PrivacyInfo.xcprivacy`. App makes network calls to public data feeds (USGS, GVP, GDACS, Open-Meteo) and uses no tracking; declare `NSPrivacyTracking = false`, empty tracking domains, and required-reason API usage (e.g. `UserDefaults` reason `CA92.1` if used). Verify no `NSPrivacyAccessedAPIType` is missed.
- **Version/build** — confirm `CFBundleShortVersionString` (1.0) and bump `CFBundleVersion` for the submission build.
- **Icon + launch audit** — confirm `AppIcon.appiconset` includes the 1024×1024 marketing icon and all required iPad sizes; confirm launch screen renders.
- **Capabilities/Info.plist audit** — bundle ID `com.globedisplay.app`, team `K7M2M2864C`, automatic signing, iPad-only, external-display scene config; add any required usage-description strings.
- **Build validation** — `xcodebuild -scheme GlobeDisplay -destination 'generic/platform=iOS' archive` succeeds clean (no warnings that block submission).

User-executed (Claude provides exact step-by-step + commands):
- App Store Connect app record, screenshots, description/keywords, privacy nutrition labels, export-compliance answer.
- Archive in Xcode → Distribute → upload, or `xcodebuild -exportArchive` + notary/altool commands.
- Submit for review.

---

## Out of Scope

- 3D on-screen globe preview (CLAUDE.md forbids SceneKit/RealityKit for output; preview is a separate effort).
- Audio playback from video datasets (globe is silent; muted by default).
- Easing/momentum physics on manual rotation drag.
- Per-overlay crossfade animation.
- Automated CI (GitHub Actions / Xcode Cloud) — noted as a follow-up, not part of this release.
