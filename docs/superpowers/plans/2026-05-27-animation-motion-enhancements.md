# Animation & Motion Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-rotation, real-time video playback, dataset crossfade transitions, and richer image-sequence controls to GlobeDisplay, then bring the app to App Store submission readiness.

**Architecture:** Each feature is additive and isolated. Pure motion math lands in `MapProjection` (unit-testable without Metal). `AnimationSequencer` gains mode-aware stepping + seek. `RenderEngine` gains auto-rotation, a crossfade base-texture path, and a video hook in its draw loop. A new `VideoPlaybackController` streams `AVPlayer` frames into the base texture via `CVMetalTextureCache`. A new `PlaybackControlsView` consolidates the motion/transport UI.

**Tech Stack:** Swift 6, SwiftUI, Metal/MetalKit, AVFoundation, CoreVideo, XCTest. iPad / iPadOS 17+.

**Spec:** `docs/superpowers/specs/2026-05-27-animation-motion-enhancements-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `GlobeDisplay/Utilities/MapProjection.swift` | + pure helpers: `advanceRotation`, `advanceTransition` |
| `GlobeDisplay/Rendering/AnimationSequencer.swift` | + `PlaybackMode`, `step(...)`, `seek(toProgress:)`, `progress` |
| `GlobeDisplay/Rendering/RenderEngine.swift` | + auto-rotation, crossfade base-texture path, video hook |
| `GlobeDisplay/Rendering/EquirectangularShaders.metal` | + `transitionProgress` uniform, previous-base sample/mix |
| `GlobeDisplay/Rendering/VideoPlaybackController.swift` | **New** — AVPlayer → Metal real-time playback + time helpers |
| `GlobeDisplay/App/AppState.swift` | + `autoRotationEnabled`, `autoRotationSpeed`, `transitionDuration` |
| `GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift` | **New** — spin, transport, scrub, loop-mode, speed |
| `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift` | Embed `PlaybackControlsView`; drop inline speed slider |
| `GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift` | Real `.video` playback; route base loads through crossfade |
| `GlobeDisplay/UI/Settings/DisplaySettingsView.swift` | + transition-duration control |
| `GlobeDisplay/PrivacyInfo.xcprivacy` | **New** — privacy manifest |
| `GlobeDisplayTests/AnimationSequencerTests.swift` | **New** — step/seek/progress tests |
| `GlobeDisplayTests/MotionMathTests.swift` | **New** — rotation/transition helper tests |
| `GlobeDisplayTests/VideoPlaybackControllerTests.swift` | **New** — time-mapping helper tests |
| `docs/RELEASE_CHECKLIST.md` | **New** — App Store submission steps for the user |

**Build/test commands** (from CLAUDE.md):
```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build

xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/<ClassName>
```

---

## Task 0: Verify & merge Shahnab visualizations (Track 1 prerequisite)

**Files:** none created — branch integration only.

- [ ] **Step 1: Confirm worktree branch is clean and built**

```bash
git -C .worktrees/shahnab-visualizations status --short   # expect empty
git log --oneline main..feature/shahnab-visualizations     # expect 10 commits
```

- [ ] **Step 2: Build the Shahnab branch**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. (Run from the worktree dir, or check out the branch first — do NOT mix worktrees.)

- [ ] **Step 3: Run the Shahnab test suites**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/AirQualityProviderTests \
  -only-testing:GlobeDisplayTests/DataFeedModelTests \
  -only-testing:GlobeDisplayTests/StaticOverlayLayerTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Merge to main**

```bash
git checkout main
git merge --no-ff feature/shahnab-visualizations -m "feat: merge Shahnab visualizations (air quality, depth-scaled quakes, rivers overlay)"
```
Expected: clean merge. If conflicts arise, resolve them (do not discard either side).

- [ ] **Step 5: Verify main still builds, then remove the worktree**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -5
git worktree remove .worktrees/shahnab-visualizations
```
Expected: `** BUILD SUCCEEDED **`.

---

## Task 1: AnimationSequencer playback modes + seek

**Files:**
- Modify: `GlobeDisplay/Rendering/AnimationSequencer.swift`
- Test: `GlobeDisplayTests/AnimationSequencerTests.swift` (Create)

- [ ] **Step 1: Write failing tests for the pure `step` helper and seek math**

Create `GlobeDisplayTests/AnimationSequencerTests.swift`:
```swift
import XCTest
@testable import GlobeDisplay

final class AnimationSequencerTests: XCTestCase {

    // MARK: - step (pure, nonisolated)

    func test_step_loop_wrapsAtEnd() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .loop)
        XCTAssertEqual(r.next, 0)
        XCTAssertEqual(r.direction, 1)
        XCTAssertFalse(r.finished)
    }

    func test_step_loop_advancesInMiddle() {
        let r = AnimationSequencer.step(from: 2, count: 5, direction: 1, mode: .loop)
        XCTAssertEqual(r.next, 3)
        XCTAssertFalse(r.finished)
    }

    func test_step_once_stopsAtLastFrame() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .once)
        XCTAssertEqual(r.next, 4)
        XCTAssertTrue(r.finished)
    }

    func test_step_pingPong_reversesAtEnd() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .pingPong)
        XCTAssertEqual(r.next, 3)
        XCTAssertEqual(r.direction, -1)
        XCTAssertFalse(r.finished)
    }

    func test_step_pingPong_reversesAtStart() {
        let r = AnimationSequencer.step(from: 0, count: 5, direction: -1, mode: .pingPong)
        XCTAssertEqual(r.next, 1)
        XCTAssertEqual(r.direction, 1)
    }

    // MARK: - seek / progress (MainActor instance)

    @MainActor
    func test_seek_clampsAndMapsToIndex() async {
        let seq = AnimationSequencer()
        seq.setFramesForTesting(count: 11)   // indices 0...10
        seq.seek(toProgress: 0.5)
        XCTAssertEqual(seq.currentFrameIndex, 5)
        seq.seek(toProgress: 2.0)            // clamps high
        XCTAssertEqual(seq.currentFrameIndex, 10)
        seq.seek(toProgress: -1.0)           // clamps low
        XCTAssertEqual(seq.currentFrameIndex, 0)
    }

    @MainActor
    func test_progress_roundTrips() async {
        let seq = AnimationSequencer()
        seq.setFramesForTesting(count: 11)
        seq.seek(toProgress: 0.5)
        XCTAssertEqual(seq.progress, 0.5, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/AnimationSequencerTests 2>&1 | tail -20
```
Expected: FAIL — `step`, `setFramesForTesting`, `seek`, `progress`, and `PlaybackMode` do not exist yet.

- [ ] **Step 3: Add `PlaybackMode`, the `step` helper, `seek`, `progress`, and a test seam**

In `AnimationSequencer.swift`, add the top-level enum above the class:
```swift
/// How an image sequence advances when it reaches an end.
enum PlaybackMode: String, CaseIterable, Sendable {
    case loop      // wrap to the start
    case once      // stop at the final frame
    case pingPong  // bounce between ends
}
```

Inside `AnimationSequencer`, add the mode property near `framerate`:
```swift
/// What happens when playback reaches an end. Default loops (legacy behavior).
var playbackMode: PlaybackMode = .loop
```

Add a private direction tracker near the other private state:
```swift
/// +1 forward, -1 reverse. Only changes in .pingPong mode.
private var direction: Int = 1
```

Add the pure stepping helper, seek, progress, and the test seam (anywhere in the class body):
```swift
/// Computes the next frame index given the current position and playback mode.
/// Pure and nonisolated so it can be unit-tested without a render engine.
nonisolated static func step(
    from index: Int, count: Int, direction: Int, mode: PlaybackMode
) -> (next: Int, direction: Int, finished: Bool) {
    guard count > 1 else { return (index, direction, mode == .once) }
    switch mode {
    case .loop:
        return ((index + 1) % count, direction, false)
    case .once:
        return index + 1 >= count ? (index, direction, true) : (index + 1, direction, false)
    case .pingPong:
        let tentative = index + direction
        if tentative >= count { return (count - 2, -1, false) }
        if tentative < 0 { return (1, 1, false) }
        return (tentative, direction, false)
    }
}

/// Moves the playhead to a fractional position (0...1). Valid while playing or paused.
func seek(toProgress progress: Double) {
    guard frameCount > 1 else { currentFrameIndex = 0; return }
    let clamped = min(max(progress, 0.0), 1.0)
    currentFrameIndex = Int((Double(frameCount - 1) * clamped).rounded())
}

/// Current playhead position as a fraction (0...1).
var progress: Double {
    frameCount > 1 ? Double(currentFrameIndex) / Double(frameCount - 1) : 0.0
}

#if DEBUG
/// Test seam: populate `frameCount` without decoding real images.
func setFramesForTesting(count: Int) {
    frames = Array(repeating: blankFrame(), count: count)
    frameCount = count
    currentFrameIndex = 0
}

private func blankFrame() -> CGImage {
    let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                        bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}
#endif
```

- [ ] **Step 4: Replace the hard-coded advance in the play loop with mode-aware stepping**

In `play(engine:)`, replace this line:
```swift
self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frameCount
```
with:
```swift
let r = AnimationSequencer.step(
    from: self.currentFrameIndex, count: self.frameCount,
    direction: self.direction, mode: self.playbackMode
)
self.currentFrameIndex = r.next
self.direction = r.direction
if r.finished { self.pause(); break }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/AnimationSequencerTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/Rendering/AnimationSequencer.swift GlobeDisplayTests/AnimationSequencerTests.swift
git commit -m "feat: add loop/once/ping-pong modes and seek to AnimationSequencer"
```

---

## Task 2: Auto-rotation

**Files:**
- Modify: `GlobeDisplay/Utilities/MapProjection.swift`
- Modify: `GlobeDisplay/Rendering/RenderEngine.swift`
- Modify: `GlobeDisplay/App/AppState.swift`
- Test: `GlobeDisplayTests/MotionMathTests.swift` (Create)

- [ ] **Step 1: Write failing tests for `advanceRotation`**

Create `GlobeDisplayTests/MotionMathTests.swift`:
```swift
import XCTest
@testable import GlobeDisplay

final class MotionMathTests: XCTestCase {

    func test_advanceRotation_addsSpeedTimesDt() {
        XCTAssertEqual(MapProjection.advanceRotation(0, speedDegPerSec: 6, dt: 1), 6, accuracy: 0.0001)
    }

    func test_advanceRotation_wrapsPast360() {
        XCTAssertEqual(MapProjection.advanceRotation(359, speedDegPerSec: 6, dt: 1), 5, accuracy: 0.0001)
    }

    func test_advanceRotation_negativeSpeedWrapsBelowZero() {
        XCTAssertEqual(MapProjection.advanceRotation(0, speedDegPerSec: -6, dt: 1), 354, accuracy: 0.0001)
    }

    func test_advanceRotation_zeroSpeedUnchanged() {
        XCTAssertEqual(MapProjection.advanceRotation(123, speedDegPerSec: 0, dt: 1), 123, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/MotionMathTests 2>&1 | tail -15
```
Expected: FAIL — `advanceRotation` undefined.

- [ ] **Step 3: Add `advanceRotation` to MapProjection**

Append inside `enum MapProjection`:
```swift
/// Advances a longitude rotation by `speedDegPerSec * dt`, wrapping into [0, 360).
/// Negative speed rotates the other direction.
static func advanceRotation(_ degrees: Double, speedDegPerSec: Double, dt: Double) -> Double {
    let advanced = degrees + speedDegPerSec * dt
    let wrapped = advanced.truncatingRemainder(dividingBy: 360.0)
    return wrapped < 0 ? wrapped + 360.0 : wrapped
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/MotionMathTests 2>&1 | tail -15
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Wire auto-rotation into RenderEngine**

In `RenderEngine.swift`, add a property near `rotationOffset`:
```swift
/// Continuous spin speed in degrees/second. Sign = direction. 0 = off.
var autoRotationSpeed: Double = 0.0

/// Timestamp of the previous frame, used to compute spin delta-time.
private var lastFrameTimestamp: CFTimeInterval?
```

In `draw(in:)`, immediately after the `guard` block (before configuring the render pass descriptor), insert:
```swift
let now = CACurrentMediaTime()
if autoRotationSpeed != 0, let last = lastFrameTimestamp {
    let dt = now - last
    rotationOffset = MapProjection.advanceRotation(rotationOffset, speedDegPerSec: autoRotationSpeed, dt: dt)
}
lastFrameTimestamp = now
```

Add `import QuartzCore` at the top of the file (for `CACurrentMediaTime`).

- [ ] **Step 6: Add auto-rotation state to AppState**

In `AppState.swift`, under `// MARK: - Animation playback`:
```swift
var autoRotationEnabled: Bool = false
var autoRotationSpeed: Double = 6.0   // degrees/sec when enabled (range 1–30)
```

- [ ] **Step 7: Build to confirm everything compiles**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add GlobeDisplay/Utilities/MapProjection.swift GlobeDisplay/Rendering/RenderEngine.swift GlobeDisplay/App/AppState.swift GlobeDisplayTests/MotionMathTests.swift
git commit -m "feat: add continuous auto-rotation to the render engine"
```

---

## Task 3: Dataset crossfade transitions

**Files:**
- Modify: `GlobeDisplay/Utilities/MapProjection.swift`
- Modify: `GlobeDisplay/Rendering/EquirectangularShaders.metal`
- Modify: `GlobeDisplay/Rendering/RenderEngine.swift`
- Modify: `GlobeDisplay/App/AppState.swift`
- Test: `GlobeDisplayTests/MotionMathTests.swift`

- [ ] **Step 1: Add failing tests for `advanceTransition`**

Append to `MotionMathTests.swift`:
```swift
extension MotionMathTests {
    func test_advanceTransition_advancesByDtOverDuration() {
        XCTAssertEqual(MapProjection.advanceTransition(0, dt: 0.3, duration: 0.6), 0.5, accuracy: 0.0001)
    }
    func test_advanceTransition_clampsToOne() {
        XCTAssertEqual(MapProjection.advanceTransition(0.9, dt: 0.3, duration: 0.6), 1.0, accuracy: 0.0001)
    }
    func test_advanceTransition_zeroDurationCompletesImmediately() {
        XCTAssertEqual(MapProjection.advanceTransition(0, dt: 0.016, duration: 0), 1.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/MotionMathTests 2>&1 | tail -15
```
Expected: FAIL — `advanceTransition` undefined.

- [ ] **Step 3: Add `advanceTransition` to MapProjection**

```swift
/// Advances a 0...1 crossfade progress by `dt / duration`, clamped at 1.0.
/// A non-positive duration completes instantly.
static func advanceTransition(_ progress: Double, dt: Double, duration: Double) -> Double {
    guard duration > 0 else { return 1.0 }
    return min(1.0, progress + dt / duration)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/MotionMathTests 2>&1 | tail -15
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Add `transitionProgress` to the shader Uniforms and mix previous base**

IMPORTANT (post-Shahnab): the merged shader has a rivers texture occupying a texture index beyond `overlayTexture [[texture(1)]]`. Before editing, read the current `EquirectangularShaders.metal` and `RenderEngine.swift` `Uniforms`/`draw(in:)` to find the next FREE texture index, and use it for the previous-base texture (do NOT assume index 2). Keep the Swift `Uniforms` struct field order identical to the metal struct.

In `EquirectangularShaders.metal`, add to the `Uniforms` struct (append after the last field, e.g. `flipVertical` plus any Shahnab-added fields):
```metal
float transitionProgress; // 0 = show previous base, 1 = show new base
```
Add a previous-base texture parameter at the next free index N (verified from the merged shader), e.g.:
```metal
texture2d<float> prevBaseTexture [[texture(N)]],
```
The shader already declares `float4 base = baseTexture.sample(polarSampler, uv);` (around line 99). Immediately after it, blend with the previous base:
```metal
float4 prevBase = prevBaseTexture.sample(polarSampler, uv);
base = mix(prevBase, base, uniforms.transitionProgress);
```
(Reuse the existing `polarSampler` and `uv` variables.)

- [ ] **Step 6: Mirror the uniform in RenderEngine and add the crossfade path**

In `RenderEngine.swift`, add `transitionProgress` to the private `Uniforms` struct (after `flipVertical`):
```swift
var transitionProgress: Float
```

Add crossfade state near `baseTexture`:
```swift
private var prevBaseTexture: MTLTexture?
private var transitionProgress: Double = 1.0

/// Crossfade duration in seconds. 0 = instant swap.
var transitionDuration: Double = 0.6
```

Add an animated base-texture setter (used by content loading):
```swift
/// Swaps the base texture, optionally crossfading from the outgoing one.
func setBaseTexture(_ texture: MTLTexture?, animated: Bool) {
    if animated, transitionDuration > 0, let current = baseTexture {
        prevBaseTexture = current
        transitionProgress = 0.0
    } else {
        prevBaseTexture = nil
        transitionProgress = 1.0
    }
    baseTexture = texture
}
```

Update `loadTexture(from:)` to route through it — replace its final line
`baseTexture = try await loader.newTexture(...)` with:
```swift
let texture = try await loader.newTexture(cgImage: image, options: options)
setBaseTexture(texture, animated: true)
```

In `draw(in:)`, after the auto-rotation block from Task 2, advance the transition:
```swift
if transitionProgress < 1.0, let last = lastFrameTimestamp {
    transitionProgress = MapProjection.advanceTransition(
        transitionProgress, dt: now - last, duration: transitionDuration
    )
    if transitionProgress >= 1.0 { prevBaseTexture = nil }
}
```
(Note: `now`/`lastFrameTimestamp` are set by the Task 2 block; keep this block after it.)

Bind the previous base texture at the same free index N used in the shader (Step 5), and pass the uniform. After the existing texture bindings, add:
```swift
encoder.setFragmentTexture(prevBaseTexture ?? clearOverlayTexture, index: N)
```
And add `transitionProgress: Float(transitionProgress)` to the `Uniforms(...)` initializer (in the same field position as the metal struct).

- [ ] **Step 7: Add `transitionDuration` to AppState**

In `AppState.swift`, under the animation section:
```swift
var transitionDuration: Double = 0.6   // crossfade seconds, 0 disables
```

- [ ] **Step 8: Build to confirm shader + engine compile**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -8
```
Expected: `** BUILD SUCCEEDED **`. (Metal shader errors surface here — read them carefully if it fails.)

- [ ] **Step 9: Commit**

```bash
git add GlobeDisplay/Utilities/MapProjection.swift GlobeDisplay/Rendering/EquirectangularShaders.metal GlobeDisplay/Rendering/RenderEngine.swift GlobeDisplay/App/AppState.swift GlobeDisplayTests/MotionMathTests.swift
git commit -m "feat: crossfade between base maps on dataset switch"
```

---

## Task 4: VideoPlaybackController (time helpers + scaffold)

**Files:**
- Create: `GlobeDisplay/Rendering/VideoPlaybackController.swift`
- Test: `GlobeDisplayTests/VideoPlaybackControllerTests.swift` (Create)

- [ ] **Step 1: Write failing tests for the pure time-mapping helpers**

Create `GlobeDisplayTests/VideoPlaybackControllerTests.swift`:
```swift
import XCTest
import CoreMedia
@testable import GlobeDisplay

final class VideoPlaybackControllerTests: XCTestCase {

    func test_timeForProgress_mapsToFractionOfDuration() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let t = VideoPlaybackController.timeForProgress(0.5, duration: duration)
        XCTAssertEqual(CMTimeGetSeconds(t), 5.0, accuracy: 0.001)
    }

    func test_timeForProgress_clampsAboveOne() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let t = VideoPlaybackController.timeForProgress(2.0, duration: duration)
        XCTAssertEqual(CMTimeGetSeconds(t), 10.0, accuracy: 0.001)
    }

    func test_progressForTime_isFraction() {
        let current = CMTime(seconds: 3, preferredTimescale: 600)
        let duration = CMTime(seconds: 12, preferredTimescale: 600)
        XCTAssertEqual(VideoPlaybackController.progressForTime(current, duration: duration), 0.25, accuracy: 0.001)
    }

    func test_progressForTime_zeroDurationIsZero() {
        let zero = CMTime(seconds: 0, preferredTimescale: 600)
        XCTAssertEqual(VideoPlaybackController.progressForTime(zero, duration: zero), 0.0, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/VideoPlaybackControllerTests 2>&1 | tail -15
```
Expected: FAIL — `VideoPlaybackController` undefined.

- [ ] **Step 3: Create VideoPlaybackController with helpers and the playback scaffold**

Create `GlobeDisplay/Rendering/VideoPlaybackController.swift`:
```swift
import AVFoundation
import CoreVideo
import Metal
import QuartzCore

/// Streams an MP4/H.264 dataset into the RenderEngine base texture in real time.
/// AVPlayer drives decoding; each draw call pulls the latest pixel buffer.
@MainActor
final class VideoPlaybackController {

    private let player = AVPlayer()
    private var output: AVPlayerItemVideoOutput?
    private var textureCache: CVMetalTextureCache?
    private let device: MTLDevice

    /// When true, the video restarts from 0 on reaching the end.
    var loopEnabled: Bool = true

    private var endObserver: NSObjectProtocol?

    init(device: MTLDevice) {
        self.device = device
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    // MARK: - Pure time helpers (unit-tested)

    nonisolated static func timeForProgress(_ progress: Double, duration: CMTime) -> CMTime {
        let clamped = min(max(progress, 0.0), 1.0)
        return CMTime(seconds: CMTimeGetSeconds(duration) * clamped, preferredTimescale: 600)
    }

    nonisolated static func progressForTime(_ current: CMTime, duration: CMTime) -> Double {
        let d = CMTimeGetSeconds(duration)
        guard d > 0 else { return 0.0 }
        return CMTimeGetSeconds(current) / d
    }

    // MARK: - Lifecycle

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
        item.add(videoOutput)
        output = videoOutput
        player.replaceCurrentItem(with: item)

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self, self.loopEnabled else { return }
            Task { @MainActor in
                self.player.seek(to: .zero)
                self.player.play()
            }
        }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func setRate(_ rate: Float) { player.rate = rate }

    func seek(toProgress progress: Double) {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return }
        player.seek(to: Self.timeForProgress(progress, duration: duration))
    }

    var progress: Double {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return 0 }
        return Self.progressForTime(player.currentTime(), duration: duration)
    }

    /// Pulls the current video frame into `engine`'s base texture. Call once per draw.
    func copyCurrentFrame(to engine: RenderEngine) {
        guard let output, let textureCache else { return }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTexture
        )
        guard status == kCVReturnSuccess,
              let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture)
        else { return }
        engine.baseTexture = texture
    }
}
```

Note: `RenderEngine.baseTexture` is currently `private`. Change its declaration in `RenderEngine.swift` from `private var baseTexture: MTLTexture?` to `var baseTexture: MTLTexture?` so the controller can assign it. (It is already mutated only on the main actor.)

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -only-testing:GlobeDisplayTests/VideoPlaybackControllerTests 2>&1 | tail -15
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Register the new file in the Xcode project if needed, then build**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -8
```
Expected: `** BUILD SUCCEEDED **`. If the file isn't compiled, add it to the `GlobeDisplay` target in `project.pbxproj` (follow the pattern used for the Shahnab files — e.g. `AirQualityProvider.swift`).

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/Rendering/VideoPlaybackController.swift GlobeDisplay/Rendering/RenderEngine.swift GlobeDisplayTests/VideoPlaybackControllerTests.swift GlobeDisplay.xcodeproj/project.pbxproj
git commit -m "feat: add VideoPlaybackController for real-time AVPlayer-to-Metal playback"
```

---

## Task 5: Wire video into the render loop and content selection

**Files:**
- Modify: `GlobeDisplay/Rendering/RenderEngine.swift`
- Modify: `GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift`

- [ ] **Step 1: Add the video hook to RenderEngine**

In `RenderEngine.swift`, add near `animationSequencer`:
```swift
/// Active real-time video playback, mutually exclusive with animationSequencer.
var videoController: VideoPlaybackController?
```

In `draw(in:)`, as the very first statement inside the method (before the `guard`), pull the latest video frame:
```swift
videoController?.copyCurrentFrame(to: self)
```

- [ ] **Step 2: Give the `.video` case real playback in ContentBrowserView**

In `ContentBrowserView.swift` `loadContent`, the teardown block already nils the sequencer. Add video teardown right after `engine.animationSequencer = nil`:
```swift
engine.videoController?.pause()
engine.videoController = nil
```

Split `.video` out of the combined `case .staticImage, .video:`. Keep `.staticImage` as-is, and add a dedicated `.video` case:
```swift
case .video:
    guard let videoName = bundle.assets.videoPath else {
        status = .error("No video file specified for \(bundle.title)")
        return
    }
    let url: URL
    if videoName.hasPrefix("/") {
        url = URL(fileURLWithPath: videoName)
    } else if let bundleURL = Bundle.main.url(forResource: videoName, withExtension: nil) {
        url = bundleURL
    } else {
        url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(videoName)
    }
    let controller = VideoPlaybackController(device: engine.device)
    controller.load(url: url)
    controller.play()
    engine.videoController = controller
    status = .ready(bundle.title)
```

VERIFIED: the asset property is `bundle.assets.videoPath` (`ContentBundle.swift:65`). Use `videoPath` for `videoName` above.

- [ ] **Step 3: Build to confirm it compiles**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -8
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add GlobeDisplay/Rendering/RenderEngine.swift GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift
git commit -m "feat: play .video datasets in real time via VideoPlaybackController"
```

---

## Task 6: PlaybackControlsView + Settings transition control

**Files:**
- Create: `GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift`
- Modify: `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift`
- Modify: `GlobeDisplay/UI/Settings/DisplaySettingsView.swift`

- [ ] **Step 1: Create PlaybackControlsView**

Create `GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift`:
```swift
import SwiftUI

/// Motion + transport controls: continuous spin, play/pause, scrub timeline,
/// loop-mode, and animation speed. Sections appear contextually by content type.
struct PlaybackControlsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.renderEngine) private var renderEngine

    var body: some View {
        @Bindable var state = appState
        HStack(spacing: 16) {
            spinControls(state: state)

            if appState.currentContent?.contentType == .imageSequence {
                Divider().frame(height: 32)
                sequenceTransport
            }
        }
    }

    @ViewBuilder
    private func spinControls(state: AppState) -> some View {
        Button {
            state.autoRotationEnabled.toggle()
            applySpin()
        } label: {
            Image(systemName: appState.autoRotationEnabled ? "stop.circle" : "arrow.clockwise.circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.autoRotationEnabled ? "Stop spin" : "Start spin")

        if appState.autoRotationEnabled {
            Slider(value: $state.autoRotationSpeed, in: 1...30, step: 1) {
                Text("Spin speed")
            } minimumValueLabel: {
                Image(systemName: "tortoise").font(.caption2)
            } maximumValueLabel: {
                Image(systemName: "hare").font(.caption2)
            }
            .frame(width: 120)
            .onChange(of: appState.autoRotationSpeed) { _, _ in applySpin() }
            .accessibilityLabel("Spin speed")
        }
    }

    private var sequenceTransport: some View {
        @Bindable var state = appState
        return HStack(spacing: 12) {
            Button {
                guard let seq = appState.activeAnimationSequencer, let engine = renderEngine else { return }
                if seq.isPlaying { seq.pause() } else { seq.play(engine: engine) }
            } label: {
                Image(systemName: (appState.activeAnimationSequencer?.isPlaying ?? false) ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play or pause animation")

            Slider(
                value: Binding(
                    get: { appState.activeAnimationSequencer?.progress ?? 0 },
                    set: { appState.activeAnimationSequencer?.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            .frame(width: 160)
            .accessibilityLabel("Animation timeline")

            Picker("Loop mode", selection: Binding(
                get: { appState.activeAnimationSequencer?.playbackMode ?? .loop },
                set: { appState.activeAnimationSequencer?.playbackMode = $0 }
            )) {
                Image(systemName: "repeat").tag(PlaybackMode.loop)
                Image(systemName: "1.circle").tag(PlaybackMode.once)
                Image(systemName: "arrow.left.arrow.right").tag(PlaybackMode.pingPong)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Slider(value: $state.animationPlaybackRate, in: 0.25...4.0, step: 0.25) {
                Text("Speed")
            } minimumValueLabel: {
                Text("¼×").font(.caption2)
            } maximumValueLabel: {
                Text("4×").font(.caption2)
            }
            .frame(width: 120)
            .accessibilityLabel("Animation speed")
        }
    }

    private func applySpin() {
        guard let engine = renderEngine else { return }
        if appState.autoRotationEnabled {
            engine.autoRotationSpeed = appState.autoRotationSpeed
        } else {
            engine.autoRotationSpeed = 0
            appState.rotationOffset = engine.rotationOffset   // resume slider from current position
        }
    }
}
```

- [ ] **Step 2: Embed PlaybackControlsView in the toolbar and drop the inline speed slider**

In `ControlPanelView.swift` `BottomToolbar.body`, replace the conditional inline `animationSpeedSlider` block:
```swift
if appState.currentContent?.contentType == .imageSequence {
    Divider().frame(height: 32)
    animationSpeedSlider
}
```
with:
```swift
Divider().frame(height: 32)
PlaybackControlsView()
```
Delete the now-unused `animationSpeedSlider` computed property. Keep the existing `.onChange(of: appState.animationPlaybackRate)` handler on `BottomToolbar` (it still drives sequencer framerate).

- [ ] **Step 3: Add the transition-duration control to Settings**

VERIFIED: there is no `DisplaySettingsView.swift`. Edit `GlobeDisplay/UI/Settings/SettingsView.swift` and add the control to `displaySection` (it already reads `@Environment(\.renderEngine)` and uses `@Bindable var state = appState`). Insert this row after the Brightness `VStack`:
```swift
VStack(alignment: .leading, spacing: 4) {
    HStack {
        Label("Transition", systemImage: "rectangle.2.swap")
        Spacer()
        Text(appState.transitionDuration == 0 ? "Off" : String(format: "%.1fs", appState.transitionDuration))
            .foregroundStyle(.secondary).font(.callout).monospacedDigit()
    }
    Slider(value: $state.transitionDuration, in: 0...1.5, step: 0.1)
        .onChange(of: appState.transitionDuration) { _, v in
            renderEngine?.transitionDuration = v
        }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Crossfade transition duration")
```
Also extend the "Reset Display Calibration" button to reset `appState.transitionDuration = 0.6` and `renderEngine?.transitionDuration = 0.6`.

- [ ] **Step 4: Build and run the full test suite**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **` and the app builds.

- [ ] **Step 5: Manual on-device verification (record results)**

Connect the iPad to the MagicPlanet (or an HDMI display) and confirm on the external screen:
- Toggle spin on/off at min and max speed, both unaffected by content type; turning spin off leaves the rotation slider at the current position.
- Switch between two static planets — confirm a visible crossfade at the default 0.6 s, and an instant cut when transition duration is set to Off.
- Play an MP4 dataset: it streams smoothly; scrub seeks; loop restarts at the end.
- Image sequence: play/pause works; scrub seeks; ping-pong bounces; once stops at the end.
- Confirm ≥30 fps (no visible stutter) with spin + overlays active.

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/UI/ControlPanel/PlaybackControlsView.swift GlobeDisplay/UI/ControlPanel/ControlPanelView.swift GlobeDisplay/UI/Settings/DisplaySettingsView.swift GlobeDisplay.xcodeproj/project.pbxproj
git commit -m "feat: consolidate spin/transport/scrub controls into PlaybackControlsView"
```

---

## Task 7: Privacy manifest + Info.plist / version audit (Track 3)

**Files:**
- Create: `GlobeDisplay/PrivacyInfo.xcprivacy`
- Modify: `GlobeDisplay/Info.plist` (only if audit finds gaps)

- [ ] **Step 1: Create the privacy manifest**

Create `GlobeDisplay/PrivacyInfo.xcprivacy`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Verify the UserDefaults reason is accurate; add file-timestamp/disk-space reasons only if used**

```bash
grep -rn "UserDefaults\|@AppStorage" GlobeDisplay --include=*.swift | head
grep -rn "FileManager.*creationDate\|contentModificationDate\|systemFreeSize\|fileSize" GlobeDisplay --include=*.swift | head
```
If `@AppStorage`/`UserDefaults` is unused, remove the `UserDefaults` dict entirely. If file-timestamp or disk-space APIs are used, add the corresponding `NSPrivacyAccessedAPICategory*` dict with the right reason code (Apple's required-reason API list).

- [ ] **Step 3: Add the manifest to the app target in the Xcode project**

Add `PrivacyInfo.xcprivacy` to the `GlobeDisplay` target's Copy Bundle Resources (edit `project.pbxproj` following the `rivers_2048x1024.png` resource pattern, or add it in Xcode).

- [ ] **Step 4: Bump the build number**

In `GlobeDisplay/Info.plist`, set `CFBundleVersion` to `2` (was `1`); leave `CFBundleShortVersionString` at `1.0`.

- [ ] **Step 5: Verify the app builds with the manifest bundled**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build 2>&1 | tail -6
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add GlobeDisplay/PrivacyInfo.xcprivacy GlobeDisplay/Info.plist GlobeDisplay.xcodeproj/project.pbxproj
git commit -m "chore: add privacy manifest and bump build number for App Store submission"
```

---

## Task 8: Archive validation + submission checklist (Track 3)

**Files:**
- Create: `docs/RELEASE_CHECKLIST.md`

- [ ] **Step 1: Confirm the marketing icon and required iPad icon sizes exist**

```bash
ls GlobeDisplay/Resources/Assets.xcassets/AppIcon.appiconset/
cat GlobeDisplay/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
```
Confirm a 1024×1024 marketing icon is present (App Store requires it). Note any missing sizes in the checklist.

- [ ] **Step 2: Produce a release archive to validate signing/build for distribution**

```bash
xcodebuild -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'generic/platform=iOS' \
  -archivePath build/GlobeDisplay.xcarchive archive 2>&1 | tail -25
```
Expected: `** ARCHIVE SUCCEEDED **`. If signing fails because no device provisioning profile exists, record that as a user step (it requires their Apple Developer account) and continue.

- [ ] **Step 3: Write the submission checklist for the user**

Create `docs/RELEASE_CHECKLIST.md` documenting exactly what the user must do (they hold the Apple Developer account / App Store Connect access):
```markdown
# GlobeDisplay — App Store Submission Checklist

Bundle ID: com.globedisplay.app · Team: K7M2M2864C · Version 1.0 (build 2)

## Prerequisites (user)
- [ ] Active paid Apple Developer Program membership
- [ ] App Store Connect access for team K7M2M2864C

## App Store Connect setup (user)
- [ ] Create the app record (Bundle ID com.globedisplay.app, name "GlobeDisplay")
- [ ] Category: Education. Age rating questionnaire (no objectionable content)
- [ ] Description, keywords, support URL, marketing URL
- [ ] Screenshots: 12.9" iPad Pro (2048×2732) and 11" iPad — capture the control UI
- [ ] Privacy nutrition labels: "Data Not Collected" (matches PrivacyInfo.xcprivacy)
- [ ] Export compliance: uses only standard HTTPS → exempt (answer "No" to custom crypto)

## Build upload (user, with Claude-provided commands)
- [ ] In Xcode: Product → Archive → Distribute App → App Store Connect → Upload
      (or use the xcodebuild archive from Task 8 + `xcrun altool`/`notarytool` flow)
- [ ] Select the uploaded build in App Store Connect
- [ ] Submit for review

## Notes
- Deployment target iPadOS 17.0, iPad-only.
- External-display (HDMI) usage is the core feature — describe the MagicPlanet use case
  in the review notes to avoid confusion during App Review.
```

- [ ] **Step 4: Commit**

```bash
git add docs/RELEASE_CHECKLIST.md
git commit -m "docs: add App Store submission checklist"
```

- [ ] **Step 5: Final full-suite test and build sanity check**

```bash
xcodebuild test -project GlobeDisplay.xcodeproj -scheme GlobeDisplay \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **`.

---

## Self-Review Notes

- **Spec coverage:** Auto-rotation → Task 2; Video playback → Tasks 4–5; Crossfade → Task 3; Sequence controls (loop/once/pingPong + scrub) → Task 1; UI consolidation → Task 6; Shahnab finish → Task 0; Release readiness (privacy manifest, version, icon audit, archive, checklist) → Tasks 7–8. All spec sections mapped.
- **Type consistency:** `PlaybackMode` (top-level enum) used in Tasks 1 & 6; `step(from:count:direction:mode:)`, `seek(toProgress:)`, `progress`, `setBaseTexture(_:animated:)`, `advanceRotation`, `advanceTransition`, `timeForProgress`, `progressForTime`, `copyCurrentFrame(to:)`, `autoRotationSpeed`, `videoController`, `transitionProgress`, `transitionDuration` — names consistent across tasks.
- **Known verify-in-code points:** the `ContentAssets` video-path property name (Task 5 Step 2) and `DisplaySettingsView`'s environment access (Task 6 Step 3) are flagged to confirm against the actual source during execution.
```
