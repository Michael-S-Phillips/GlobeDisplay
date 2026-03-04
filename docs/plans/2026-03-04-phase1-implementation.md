# Phase 1 Implementation Plan — Foundation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Render a static equirectangular image to the MagicPlanet globe via HDMI, with a real-time longitude rotation control on the iPad.

**Architecture:** XcodeGen scaffolds the project from `project.yml`. `RenderEngine` is a `@MainActor` class that owns the Metal pipeline and acts as `MTKViewDelegate`. `ExternalDisplayManager` detects the HDMI screen via `UIScreen` notifications and creates a `UIWindow` hosting an `MTKView`. The iPad's built-in screen shows a SwiftUI `NavigationSplitView` control panel.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, Metal/MetalKit, XcodeGen, XCTest

---

## Prerequisites

These must be done manually before running any code tasks:

1. **Install Xcode** from the Mac App Store (search "Xcode"). This is ~10 GB and may take 30–60 minutes.
2. After Xcode opens for the first time, accept the license and let it install additional components.
3. Plug in your iPad via USB, trust this computer on the iPad when prompted.

---

## Task 1: Install XcodeGen and Generate Project Scaffold

**Files:**
- Create: `project.yml`
- Create: `GlobeDisplay/` (source directory, empty)
- Create: `GlobeDisplayTests/` (test directory, empty)
- Create: `GlobeDisplayUITests/` (UI test directory, empty)

**Step 1: Install XcodeGen via Homebrew**

```bash
brew install xcodegen
```

Expected: `xcodegen` installs to `/opt/homebrew/bin/xcodegen`.

**Step 2: Create `project.yml`**

Create this file at `/Users/phillipsm/Documents/SIC_Management/GlobeDisplay/project.yml`:

```yaml
name: GlobeDisplay
options:
  bundleIdPrefix: com.globedisplay
  deploymentTarget:
    iOS: "16.0"
  xcodeVersion: "16.0"
  createIntermediateGroups: true
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    IPHONEOS_DEPLOYMENT_TARGET: "16.0"
    TARGETED_DEVICE_FAMILY: "2"
    SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO

targets:
  GlobeDisplay:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: GlobeDisplay
        excludes:
          - "**/*.md"
    info:
      path: GlobeDisplay/Info.plist
      properties:
        UILaunchScreen: {}
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
          UISceneConfigurations: {}
        UISupportedInterfaceOrientations~ipad:
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationPortraitUpsideDown
        UIRequiredDeviceCapabilities:
          - metal
        UIApplicationSupportsIndirectInputEvents: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.globedisplay.app
        CODE_SIGN_STYLE: Automatic

  GlobeDisplayTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: GlobeDisplayTests
    dependencies:
      - target: GlobeDisplay
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.globedisplay.tests
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/GlobeDisplay.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GlobeDisplay"

  GlobeDisplayUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: GlobeDisplayUITests
    dependencies:
      - target: GlobeDisplay
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.globedisplay.uitests
        TEST_TARGET_NAME: GlobeDisplay
```

**Step 3: Create source directories**

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay
mkdir -p GlobeDisplay/App
mkdir -p GlobeDisplay/Models
mkdir -p GlobeDisplay/Rendering
mkdir -p GlobeDisplay/ExternalDisplay
mkdir -p GlobeDisplay/ContentManagement
mkdir -p GlobeDisplay/UI/ControlPanel
mkdir -p GlobeDisplay/UI/Components
mkdir -p GlobeDisplay/Utilities
mkdir -p GlobeDisplay/Resources/BundledContent
mkdir -p GlobeDisplayTests/TestFixtures
mkdir -p GlobeDisplayUITests
```

**Step 4: Generate the Xcode project**

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay
xcodegen generate
```

Expected output: `✅ Generated: GlobeDisplay.xcodeproj`

**Step 5: Open project in Xcode and configure signing**

```bash
open GlobeDisplay.xcodeproj
```

In Xcode:
- Select the `GlobeDisplay` target → Signing & Capabilities tab
- Set Team to your personal Apple ID (sign in via Xcode → Settings → Accounts if needed)
- Xcode will auto-create a provisioning profile
- Select your iPad as the run destination from the device picker at the top

**Step 6: Commit**

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay
git add project.yml GlobeDisplay.xcodeproj GlobeDisplay/ GlobeDisplayTests/ GlobeDisplayUITests/
git commit -m "feat: scaffold Xcode project with XcodeGen"
```

---

## Task 2: MapProjection Utilities — TDD

**Files:**
- Create: `GlobeDisplay/Utilities/MapProjection.swift`
- Create: `GlobeDisplayTests/MapProjectionTests.swift`

**Step 1: Write the failing tests first**

Create `GlobeDisplayTests/MapProjectionTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class MapProjectionTests: XCTestCase {

    let imageSize = CGSize(width: 2048, height: 1024)

    // MARK: - toPixel

    func test_toPixel_originCoord_returnsCenterPixel() {
        let pixel = MapProjection.toPixel(latitude: 0, longitude: 0, in: imageSize)
        XCTAssertEqual(pixel.x, 1024.0, accuracy: 0.5)
        XCTAssertEqual(pixel.y, 512.0, accuracy: 0.5)
    }

    func test_toPixel_northPole_returnsTopRow() {
        let pixel = MapProjection.toPixel(latitude: 90, longitude: 0, in: imageSize)
        XCTAssertEqual(pixel.y, 0.0, accuracy: 0.5)
    }

    func test_toPixel_southPole_returnsBottomRow() {
        let pixel = MapProjection.toPixel(latitude: -90, longitude: 0, in: imageSize)
        XCTAssertEqual(pixel.y, 1024.0, accuracy: 0.5)
    }

    func test_toPixel_positiveDateLine_returnsRightEdge() {
        let pixel = MapProjection.toPixel(latitude: 0, longitude: 180, in: imageSize)
        XCTAssertEqual(pixel.x, 2048.0, accuracy: 0.5)
    }

    func test_toPixel_negativeDateLine_returnsLeftEdge() {
        let pixel = MapProjection.toPixel(latitude: 0, longitude: -180, in: imageSize)
        XCTAssertEqual(pixel.x, 0.0, accuracy: 0.5)
    }

    func test_toPixel_sosConvention_primeMeridianAtHorizontalCenter() {
        // SOS standard: 0° longitude maps to width/2
        let pixel = MapProjection.toPixel(latitude: 0, longitude: 0, in: imageSize)
        XCTAssertEqual(pixel.x, imageSize.width / 2, accuracy: 0.5)
    }

    // MARK: - toCoordinate

    func test_toCoordinate_centerPixel_returnsOrigin() {
        let center = CGPoint(x: 1024, y: 512)
        let coord = MapProjection.toCoordinate(pixel: center, in: imageSize)
        XCTAssertEqual(coord.latitude, 0.0, accuracy: 0.01)
        XCTAssertEqual(coord.longitude, 0.0, accuracy: 0.01)
    }

    func test_toCoordinate_topRow_returnsNorthPole() {
        let topCenter = CGPoint(x: 1024, y: 0)
        let coord = MapProjection.toCoordinate(pixel: topCenter, in: imageSize)
        XCTAssertEqual(coord.latitude, 90.0, accuracy: 0.01)
    }

    // MARK: - Round-trip

    func test_roundTrip_standardCoord_isAccurate() {
        let lat = 37.7749   // San Francisco
        let lon = -122.4194
        let pixel = MapProjection.toPixel(latitude: lat, longitude: lon, in: imageSize)
        let coord = MapProjection.toCoordinate(pixel: pixel, in: imageSize)
        XCTAssertEqual(coord.latitude, lat, accuracy: 0.01)
        XCTAssertEqual(coord.longitude, lon, accuracy: 0.01)
    }

    // MARK: - normalizedRotation

    func test_normalizedRotation_zero_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_360_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(360), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_180_returnsHalf() {
        XCTAssertEqual(MapProjection.normalizedRotation(180), 0.5, accuracy: 0.0001)
    }

    func test_normalizedRotation_over360_wraps() {
        XCTAssertEqual(MapProjection.normalizedRotation(540), 0.5, accuracy: 0.0001)
    }

    func test_normalizedRotation_negative_wraps() {
        XCTAssertEqual(MapProjection.normalizedRotation(-180), 0.5, accuracy: 0.0001)
    }
}
```

**Step 2: Run tests — expect failure**

In Xcode: Cmd+U. Tests will fail with "cannot find type 'MapProjection' in scope."

**Step 3: Implement `MapProjection.swift`**

Create `GlobeDisplay/Utilities/MapProjection.swift`:

```swift
import CoreGraphics

/// Equirectangular (plate carrée) projection math.
/// Uses the SOS convention: 0° longitude at horizontal center of image.
enum MapProjection {

    /// Converts geographic coordinates to pixel coordinates in an equirectangular image.
    static func toPixel(latitude: Double, longitude: Double, in size: CGSize) -> CGPoint {
        let x = (longitude + 180.0) / 360.0 * Double(size.width)
        let y = (90.0 - latitude) / 180.0 * Double(size.height)
        return CGPoint(x: x, y: y)
    }

    /// Converts equirectangular pixel coordinates to geographic coordinates.
    static func toCoordinate(pixel: CGPoint, in size: CGSize) -> (latitude: Double, longitude: Double) {
        let longitude = Double(pixel.x) / Double(size.width) * 360.0 - 180.0
        let latitude = 90.0 - Double(pixel.y) / Double(size.height) * 180.0
        return (latitude: latitude, longitude: longitude)
    }

    /// Converts a longitude offset in degrees to a normalized UV offset (0.0–1.0).
    /// Handles values outside 0°–360° via modulo wrapping.
    static func normalizedRotation(_ degrees: Double) -> Double {
        let normalized = degrees / 360.0
        return normalized - floor(normalized)
    }
}
```

**Step 4: Run tests — expect all pass**

Cmd+U. All 11 `MapProjectionTests` should pass.

**Step 5: Commit**

```bash
git add GlobeDisplay/Utilities/MapProjection.swift GlobeDisplayTests/MapProjectionTests.swift
git commit -m "feat: add MapProjection utilities with full test coverage"
```

---

## Task 3: ContentBundle Model — TDD

**Files:**
- Create: `GlobeDisplay/Models/ContentBundle.swift`
- Create: `GlobeDisplay/Models/PlanetaryBody.swift`
- Create: `GlobeDisplayTests/ContentBundleTests.swift`

**Step 1: Write failing tests**

Create `GlobeDisplayTests/ContentBundleTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class ContentBundleTests: XCTestCase {

    func test_contentBundle_codableRoundTrip() throws {
        let original = ContentBundle(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            title: "Earth — Blue Marble",
            category: .planets,
            contentType: .staticImage,
            resolution: CGSize(width: 2048, height: 1024),
            source: .bundled,
            assets: ContentAssets(primaryImageName: "blue_marble"),
            attribution: "NASA Visible Earth",
            license: "Public Domain"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ContentBundle.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.contentType, original.contentType)
        XCTAssertEqual(decoded.resolution.width, original.resolution.width, accuracy: 0.1)
        XCTAssertEqual(decoded.resolution.height, original.resolution.height, accuracy: 0.1)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.assets.primaryImageName, original.assets.primaryImageName)
        XCTAssertEqual(decoded.attribution, original.attribution)
        XCTAssertEqual(decoded.license, original.license)
    }

    func test_contentCategory_allCases_areDistinct() {
        let allCases = ContentCategory.allCases
        let uniqueCases = Set(allCases.map { $0.rawValue })
        XCTAssertEqual(allCases.count, uniqueCases.count)
    }
}
```

**Step 2: Run tests — expect failure**

Cmd+U. Should fail with "cannot find type 'ContentBundle'."

**Step 3: Implement the models**

Create `GlobeDisplay/Models/ContentBundle.swift`:

```swift
import CoreGraphics
import Foundation

struct ContentBundle: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let category: ContentCategory
    let contentType: ContentType
    let resolution: CGSize
    let source: ContentSource
    let assets: ContentAssets
    let attribution: String
    let license: String
}

enum ContentCategory: String, Codable, CaseIterable, Sendable {
    case planets, earth, atmosphere, ocean, cryosphere
    case space, land, biosphere, humanImpact, education
}

enum ContentType: String, Codable, Sendable {
    case staticImage
    case imageSequence
    case video
}

enum ContentSource: String, Codable, Sendable {
    case bundled, downloaded, userImported
}

struct ContentAssets: Codable, Sendable {
    var primaryImageName: String?
    var sequenceDirectory: String?
    var videoPath: String?
    var frameCount: Int?
    var framerate: Double?

    init(primaryImageName: String? = nil) {
        self.primaryImageName = primaryImageName
    }
}

// CGSize Codable conformance (not provided by Apple)
extension CGSize: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(Double.self)
        let height = try container.decode(Double.self)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Double(width))
        try container.encode(Double(height))
    }
}
```

Create `GlobeDisplay/Models/PlanetaryBody.swift`:

```swift
import Foundation

enum PlanetaryBody: String, Codable, CaseIterable, Sendable {
    case earth, moon, mars, venus, mercury
    case jupiter, saturn, uranus, neptune, pluto

    var displayName: String {
        rawValue.capitalized
    }
}
```

**Step 4: Run tests — expect pass**

Cmd+U. Both `ContentBundleTests` should pass.

**Step 5: Commit**

```bash
git add GlobeDisplay/Models/ GlobeDisplayTests/ContentBundleTests.swift
git commit -m "feat: add ContentBundle and related models with Codable tests"
```

---

## Task 4: AppState

**Files:**
- Create: `GlobeDisplay/App/AppState.swift`

No unit tests — this is a trivial observable container. Correctness is verified by the UI behavior.

**Step 1: Create `AppState.swift`**

```swift
import Foundation
import Observation
import CoreGraphics

/// Global application state. Injected as an environment object at the root.
@Observable
@MainActor
final class AppState {
    var currentContent: ContentBundle?
    var rotationOffset: Double = 0.0        // degrees, 0–360
    var displayConnected: Bool = false
    var displayResolution: CGSize = CGSize(width: 2048, height: 1024)
}
```

> **Note:** `@Observable` requires iOS 17+. Since most iPads shipping with iPadOS 16 can upgrade to 17, this is acceptable. If iOS 16 support is later required, replace `@Observable` with `ObservableObject` and add `@Published` to each property.

**Step 2: Commit**

```bash
git add GlobeDisplay/App/AppState.swift
git commit -m "feat: add @Observable AppState"
```

---

## Task 5: Metal Shaders

**Files:**
- Create: `GlobeDisplay/Rendering/EquirectangularShaders.metal`

Metal shader files cannot be unit tested, but the project will fail to build if there are shader compilation errors, which serves as the verification step.

**Step 1: Create the shader file**

Create `GlobeDisplay/Rendering/EquirectangularShaders.metal`:

```metal
#include <metal_stdlib>
using namespace metal;

// Must match the Swift-side Uniforms struct in RenderEngine.swift
struct Uniforms {
    float rotationOffset;   // normalized 0.0–1.0
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Renders a full-screen quad. No vertex buffer needed — vertices are
// generated from the vertex ID.
vertex VertexOut equirect_vertex(uint vertexID [[vertex_id]]) {
    // Triangle strip: bottom-left, bottom-right, top-left, top-right
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    // UV: origin at top-left (Metal convention)
    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = uvs[vertexID];
    return out;
}

fragment float4 equirect_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> baseTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // address::repeat on the sampler handles date-line wraparound automatically
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::repeat
    );

    float2 uv = in.texCoord;
    uv.x = uv.x + uniforms.rotationOffset;

    return baseTexture.sample(textureSampler, uv);
}
```

**Step 2: Verify shader compiles**

In Xcode: Cmd+B (build). The build should succeed. If you see Metal compiler errors, fix them before continuing.

**Step 3: Commit**

```bash
git add GlobeDisplay/Rendering/EquirectangularShaders.metal
git commit -m "feat: add equirectangular Metal shaders with rotation support"
```

---

## Task 6: RenderEngine

**Files:**
- Create: `GlobeDisplay/Rendering/RenderEngine.swift`
- Create: `GlobeDisplay/ExternalDisplay/GlobeOutputView.swift`

**Step 1: Create `RenderEngine.swift`**

`RenderEngine` is a `@MainActor` class (not a Swift actor) so it can be used directly as `MTKViewDelegate`. All Metal work is encoded synchronously per frame; the GPU executes asynchronously, so there's no main-thread blocking.

Create `GlobeDisplay/Rendering/RenderEngine.swift`:

```swift
import Metal
import MetalKit
import CoreGraphics

// Must match the struct in EquirectangularShaders.metal
private struct Uniforms {
    var rotationOffset: Float
}

enum RenderEngineError: Error {
    case metalDeviceUnavailable
    case commandQueueFailed
    case shaderLibraryFailed
    case shaderFunctionNotFound(String)
    case pipelineStateFailed(Error)
}

@MainActor
final class RenderEngine: NSObject {

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var baseTexture: MTLTexture?

    /// Longitude rotation in degrees (0–360). Updated in real time from the UI.
    var rotationOffset: Double = 0.0

    // MARK: - Init

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderEngineError.metalDeviceUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderEngineError.commandQueueFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        super.init()
        try buildPipeline()
    }

    private func buildPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw RenderEngineError.shaderLibraryFailed
        }
        guard let vertexFn = library.makeFunction(name: "equirect_vertex") else {
            throw RenderEngineError.shaderFunctionNotFound("equirect_vertex")
        }
        guard let fragmentFn = library.makeFunction(name: "equirect_fragment") else {
            throw RenderEngineError.shaderFunctionNotFound("equirect_fragment")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw RenderEngineError.pipelineStateFailed(error)
        }
    }

    // MARK: - Texture Loading

    /// Loads a CGImage as the current base texture. Safe to call while rendering is active —
    /// the old texture stays visible until the new one is ready.
    func loadTexture(from image: CGImage) async throws {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: false
        ]
        baseTexture = try await loader.newTexture(cgImage: image, options: options)
    }
}

// MARK: - MTKViewDelegate

extension RenderEngine: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No action needed for Phase 1 — we render at whatever size the view requests.
    }

    func draw(in view: MTKView) {
        guard
            let pipelineState,
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        // Clear to black when no texture is loaded
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        encoder.setRenderPipelineState(pipelineState)

        if let texture = baseTexture {
            encoder.setFragmentTexture(texture, index: 0)
            var uniforms = Uniforms(rotationOffset: Float(MapProjection.normalizedRotation(rotationOffset)))
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
```

**Step 2: Create `GlobeOutputView.swift`**

Create `GlobeDisplay/ExternalDisplay/GlobeOutputView.swift`:

```swift
import MetalKit

/// The MTKView rendered to the external HDMI display.
/// Configured for a continuous 30 fps render loop driven by RenderEngine.
final class GlobeOutputView: MTKView {

    init(renderEngine: RenderEngine) {
        super.init(frame: .zero, device: renderEngine.device)
        self.delegate = renderEngine
        self.isPaused = false
        self.enableSetNeedsDisplay = false
        self.preferredFramesPerSecond = 30
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        self.framebufferOnly = true
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not implemented") }
}
```

**Step 3: Build to verify — Cmd+B**

Expected: Clean build. Fix any Swift 6 concurrency warnings before committing.

**Step 4: Commit**

```bash
git add GlobeDisplay/Rendering/RenderEngine.swift GlobeDisplay/ExternalDisplay/GlobeOutputView.swift
git commit -m "feat: add RenderEngine Metal compositor and GlobeOutputView"
```

---

## Task 7: ExternalDisplayManager

**Files:**
- Create: `GlobeDisplay/ExternalDisplay/ExternalDisplayManager.swift`
- Create: `GlobeDisplay/ExternalDisplay/DisplayCalibration.swift`

**Step 1: Create `DisplayCalibration.swift`**

Create `GlobeDisplay/ExternalDisplay/DisplayCalibration.swift`:

```swift
import CoreGraphics
import Foundation

/// User-configurable display settings, persisted via AppStorage.
struct DisplayCalibration: Sendable {
    /// Preferred render resolution, independent of the display's native resolution.
    var renderResolution: CGSize = CGSize(width: 2048, height: 1024)
}
```

**Step 2: Create `ExternalDisplayManager.swift`**

Create `GlobeDisplay/ExternalDisplay/ExternalDisplayManager.swift`:

```swift
import UIKit
import SwiftUI

/// Detects the HDMI-connected MagicPlanet display and drives it with the RenderEngine.
/// Must run on the main thread — UIScreen notifications are delivered on the main thread.
@MainActor
final class ExternalDisplayManager {

    private let renderEngine: RenderEngine
    private let appState: AppState
    private var externalWindow: UIWindow?

    var calibration = DisplayCalibration()

    init(renderEngine: RenderEngine, appState: AppState) {
        self.renderEngine = renderEngine
        self.appState = appState
        registerForScreenNotifications()
        // Check if a screen is already connected at launch
        // (e.g., app relaunched while globe is plugged in)
        checkExistingScreens()
    }

    // MARK: - Screen Detection

    private func registerForScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidConnect(_:)),
            name: UIScreen.didConnectNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect(_:)),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    private func checkExistingScreens() {
        // UIScreen.screens includes the built-in + any connected external screens
        let externalScreens = UIScreen.screens.filter { $0 != UIScreen.main }
        if let screen = externalScreens.first {
            setupExternalWindow(for: screen)
        }
    }

    @objc private func screenDidConnect(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen,
              screen != UIScreen.main else { return }
        setupExternalWindow(for: screen)
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        tearDownExternalWindow()
    }

    // MARK: - Window Management

    private func setupExternalWindow(for screen: UIScreen) {
        tearDownExternalWindow()  // Clean up any existing window first

        let window = UIWindow(frame: screen.bounds)
        // Assign to the external screen (deprecated API, still functional for physical displays)
        window.screen = screen

        let globeView = GlobeOutputView(renderEngine: renderEngine)
        let controller = UIViewController()
        controller.view = globeView
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        window.isHidden = false

        externalWindow = window
        appState.displayConnected = true
        appState.displayResolution = screen.nativeBounds.size
    }

    private func tearDownExternalWindow() {
        externalWindow?.isHidden = true
        externalWindow = nil
        appState.displayConnected = false
        appState.displayResolution = CGSize(width: 2048, height: 1024)
    }
}
```

**Step 3: Build — Cmd+B**

Expected: Clean build.

**Step 4: Commit**

```bash
git add GlobeDisplay/ExternalDisplay/ExternalDisplayManager.swift GlobeDisplay/ExternalDisplay/DisplayCalibration.swift
git commit -m "feat: add ExternalDisplayManager with UIScreen detection"
```

---

## Task 8: ContentManager (Phase 1 — Bundled Content Only)

**Files:**
- Create: `GlobeDisplay/ContentManagement/ContentManager.swift`

**Step 1: Create `ContentManager.swift`**

Create `GlobeDisplay/ContentManagement/ContentManager.swift`:

```swift
import CoreGraphics
import ImageIO
import Foundation

enum ContentManagerError: Error {
    case imageNotFound(String)
    case imageDecodeFailed(String)
}

/// Manages content discovery and loading. Phase 1: bundled assets only.
@MainActor
final class ContentManager {

    static let shared = ContentManager()
    private init() {}

    // MARK: - Catalog

    /// Returns all content available in Phase 1 (bundled planetary textures).
    func bundledContent() -> [ContentBundle] {
        [
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Earth — Blue Marble",
                category: .planets,
                contentType: .staticImage,
                resolution: CGSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "blue_marble"),
                attribution: "NASA Visible Earth",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "Earth — Night Lights",
                category: .planets,
                contentType: .staticImage,
                resolution: CGSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "earth_night"),
                attribution: "NASA Black Marble / Earth Observatory",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Mars",
                category: .planets,
                contentType: .staticImage,
                resolution: CGSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "mars"),
                attribution: "NASA/JPL-Caltech / Viking & MOLA",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                title: "Moon",
                category: .planets,
                contentType: .staticImage,
                resolution: CGSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "moon"),
                attribution: "NASA/GSFC/Arizona State University (LROC WAC)",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                title: "Jupiter",
                category: .planets,
                contentType: .staticImage,
                resolution: CGSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "jupiter"),
                attribution: "NASA/JPL-Caltech / Cassini & Juno",
                license: "Public Domain (U.S. Government Work)"
            ),
        ]
    }

    // MARK: - Image Loading

    /// Loads a CGImage for a bundled ContentBundle.
    func loadCGImage(for bundle: ContentBundle) throws -> CGImage {
        guard let imageName = bundle.assets.primaryImageName else {
            throw ContentManagerError.imageNotFound("no image name in assets")
        }

        // Look in BundledContent folder inside the app bundle
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "jpg",
                                         subdirectory: "BundledContent")
               ?? Bundle.main.url(forResource: imageName, withExtension: "png",
                                   subdirectory: "BundledContent") else {
            throw ContentManagerError.imageNotFound(imageName)
        }

        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let image = CGImage(
                  jpegDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) ?? CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            throw ContentManagerError.imageDecodeFailed(imageName)
        }

        return image
    }
}
```

**Step 2: Build — Cmd+B**

**Step 3: Commit**

```bash
git add GlobeDisplay/ContentManagement/ContentManager.swift
git commit -m "feat: add ContentManager with bundled planetary content catalog"
```

---

## Task 9: Planetary Texture Assets

**Files:**
- Create: `GlobeDisplay/Resources/BundledContent/blue_marble.jpg`
- Create: `GlobeDisplay/Resources/BundledContent/earth_night.jpg`
- Create: `GlobeDisplay/Resources/BundledContent/mars.jpg`
- Create: `GlobeDisplay/Resources/BundledContent/moon.jpg`
- Create: `GlobeDisplay/Resources/BundledContent/jupiter.jpg`

**Step 1: Download the textures**

Run these commands to download free public-domain textures and resize them to 2048×1024:

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay/GlobeDisplay/Resources/BundledContent

# Blue Marble (NASA Visible Earth)
curl -L "https://eoimages.gsfc.nasa.gov/images/imagerecords/74000/74117/world.200408.3x5400x2700.jpg" \
  -o blue_marble_src.jpg

# Earth night lights (NASA Black Marble)
curl -L "https://eoimages.gsfc.nasa.gov/images/imagerecords/144000/144898/BlackMarble_2016_01deg.jpg" \
  -o earth_night_src.jpg

# Mars (USGS Astrogeology)
curl -L "https://astropedia.astrogeology.usgs.gov/download/Mars/Viking/MDIM21/thumbs/Mars_Viking_MDIM21_ClrMosaic_global_232m.jpg" \
  -o mars_src.jpg
```

> **Note:** If these specific URLs are unavailable, excellent free alternatives:
> - All planets at 2k resolution: https://www.solarsystemscope.com/textures/
> - NASA 3D Resources: https://nasa3d.arc.nasa.gov/images
> Download equirectangular (2:1 aspect ratio) JPEG or PNG files for each body.

**Step 2: Resize to 2048×1024 using sips (macOS built-in)**

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay/GlobeDisplay/Resources/BundledContent

# Resize each downloaded source to exactly 2048×1024
sips -z 1024 2048 blue_marble_src.jpg --out blue_marble.jpg
sips -z 1024 2048 earth_night_src.jpg --out earth_night.jpg
# Repeat for mars.jpg, moon.jpg, jupiter.jpg from your downloaded files
```

**Step 3: Add to Xcode project**

In Xcode: Right-click `GlobeDisplay/Resources/BundledContent` group → "Add Files to GlobeDisplay..." → select all 5 `.jpg` files. Ensure "Add to target: GlobeDisplay" is checked.

Alternatively, re-run `xcodegen generate` — it will pick up the new files automatically since the `sources` entry covers the whole `GlobeDisplay/` directory:

```bash
cd /Users/phillipsm/Documents/SIC_Management/GlobeDisplay
xcodegen generate
```

**Step 4: Add a test fixture**

Create a small 256×128 solid-color PNG for use in unit tests:

```bash
# Create a minimal 256×128 red PNG using sips + a placeholder
# The easiest method: use Python's Pillow if available, or create from a screenshot
# Alternatively, in Xcode: File → New → File → Metal File, then use the canvas to export

# Quick method using ImageMagick if installed:
brew install imagemagick
convert -size 256x128 xc:red \
  /Users/phillipsm/Documents/SIC_Management/GlobeDisplay/GlobeDisplayTests/TestFixtures/test_equirectangular.png
```

> If ImageMagick is unavailable, just duplicate any of the small PNG files and place it at the fixture path — the content doesn't matter, only the dimensions.

**Step 5: Commit**

```bash
git add GlobeDisplay/Resources/BundledContent/*.jpg GlobeDisplayTests/TestFixtures/
git commit -m "feat: add bundled planetary textures and test fixture"
```

---

## Task 10: App Entry Point

**Files:**
- Create: `GlobeDisplay/App/GlobeDisplayApp.swift`

**Step 1: Create `GlobeDisplayApp.swift`**

```swift
import SwiftUI

@main
struct GlobeDisplayApp: App {

    @State private var appState = AppState()
    @State private var renderEngine: RenderEngine? = try? RenderEngine()
    @State private var displayManager: ExternalDisplayManager?

    var body: some Scene {
        WindowGroup {
            Group {
                if let renderEngine {
                    ControlPanelView()
                        .environment(appState)
                        .onAppear {
                            // Create the display manager once the view is on screen
                            // (UIScreen API requires the app to be active)
                            if displayManager == nil {
                                displayManager = ExternalDisplayManager(
                                    renderEngine: renderEngine,
                                    appState: appState
                                )
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "Metal Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This device does not support Metal rendering.")
                    )
                }
            }
        }
    }
}
```

> `ControlPanelView` is created in the next task. Add a placeholder now if needed to get the project building.

**Step 2: Add placeholder ControlPanelView if needed**

If Task 11 isn't done yet, add a temporary placeholder so the project compiles:

```swift
// Temporary placeholder — replaced in Task 11
struct ControlPanelView: View {
    var body: some View {
        Text("GlobeDisplay — Control Panel")
    }
}
```

Place this in `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift` temporarily.

**Step 3: Build — Cmd+B**

**Step 4: Commit**

```bash
git add GlobeDisplay/App/GlobeDisplayApp.swift GlobeDisplay/UI/ControlPanel/ControlPanelView.swift
git commit -m "feat: add app entry point with RenderEngine and ExternalDisplayManager wiring"
```

---

## Task 11: Control Panel UI

**Files:**
- Create/Replace: `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift`
- Create: `GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift`
- Create: `GlobeDisplay/UI/Components/ContentCard.swift`

**Step 1: Create `ContentCard.swift`**

Create `GlobeDisplay/UI/Components/ContentCard.swift`:

```swift
import SwiftUI

struct ContentCard: View {
    let bundle: ContentBundle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail — loads from BundledContent folder
            Group {
                if let imageName = bundle.assets.primaryImageName,
                   let uiImage = UIImage(named: imageName) ?? loadBundledImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(2, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .aspectRatio(2, contentMode: .fill)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            Text(bundle.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text("\(Int(bundle.resolution.width))×\(Int(bundle.resolution.height))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bundle.title)
        .accessibilityHint("Double-tap to display on globe")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func loadBundledImage(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg",
                                         subdirectory: "BundledContent")
               ?? Bundle.main.url(forResource: name, withExtension: "png",
                                   subdirectory: "BundledContent"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
```

**Step 2: Create `ContentBrowserView.swift`**

Create `GlobeDisplay/UI/ControlPanel/ContentBrowserView.swift`:

```swift
import SwiftUI

struct ContentBrowserView: View {

    @Environment(AppState.self) private var appState
    let renderEngine: RenderEngine
    let contentManager = ContentManager.shared

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(contentManager.bundledContent()) { bundle in
                    ContentCard(
                        bundle: bundle,
                        isSelected: appState.currentContent?.id == bundle.id
                    )
                    .onTapGesture {
                        loadContent(bundle)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Planets")
    }

    private func loadContent(_ bundle: ContentBundle) {
        appState.currentContent = bundle
        Task {
            do {
                let image = try contentManager.loadCGImage(for: bundle)
                try await renderEngine.loadTexture(from: image)
            } catch {
                print("Failed to load texture: \(error)")
            }
        }
    }
}
```

**Step 3: Create the full `ControlPanelView.swift`**

Replace `GlobeDisplay/UI/ControlPanel/ControlPanelView.swift`:

```swift
import SwiftUI

struct ControlPanelView: View {

    @Environment(AppState.self) private var appState
    // RenderEngine is passed in from the environment (set up in the App entry point)
    // We use a custom environment key for this.

    var body: some View {
        RenderEngineEnvironmentView()
            .preferredColorScheme(.dark)
    }
}

/// Reads the RenderEngine from the environment and builds the full split-view UI.
private struct RenderEngineEnvironmentView: View {

    @Environment(AppState.self) private var appState
    @Environment(RenderEngineKey.self) private var renderEngine

    var body: some View {
        NavigationSplitView {
            // Sidebar: content categories
            List {
                NavigationLink(destination: contentBrowser) {
                    Label("Planets", systemImage: "globe")
                }
            }
            .navigationTitle("GlobeDisplay")
            .listStyle(.sidebar)
        } detail: {
            contentBrowser
        }
        .safeAreaInset(edge: .bottom) {
            bottomToolbar
        }
    }

    private var contentBrowser: some View {
        Group {
            if let engine = renderEngine {
                ContentBrowserView(renderEngine: engine)
            } else {
                ContentUnavailableView("Metal Unavailable",
                                       systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // Display status indicator
            displayStatusIndicator

            Divider()
                .frame(height: 32)

            // Rotation slider
            HStack {
                Image(systemName: "rotate.3d")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                @Bindable var state = appState
                Slider(
                    value: $state.rotationOffset,
                    in: 0...360,
                    step: 1
                ) {
                    Text("Longitude offset")
                } minimumValueLabel: {
                    Text("0°").font(.caption2)
                } maximumValueLabel: {
                    Text("360°").font(.caption2)
                }
                .onChange(of: appState.rotationOffset) { _, newValue in
                    renderEngine?.rotationOffset = newValue
                }
                .accessibilityLabel("Longitude offset")
                .accessibilityValue("\(Int(appState.rotationOffset)) degrees")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var displayStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.displayConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(appState.displayConnected ? "Globe connected" : "No display")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appState.displayConnected ? "Globe connected" : "No display detected")
    }
}

// MARK: - Environment Key for RenderEngine

struct RenderEngineKey: EnvironmentKey {
    static let defaultValue: RenderEngine? = nil
}

extension EnvironmentValues {
    var renderEngine: RenderEngine? {
        get { self[RenderEngineKey.self] }
        set { self[RenderEngineKey.self] = newValue }
    }
}
```

**Step 4: Update `GlobeDisplayApp.swift` to inject RenderEngine into environment**

Update the `.environment` call in `GlobeDisplayApp.swift`:

```swift
ControlPanelView()
    .environment(appState)
    .environment(\.renderEngine, renderEngine)  // add this line
    .onAppear {
        if displayManager == nil {
            displayManager = ExternalDisplayManager(
                renderEngine: renderEngine,
                appState: appState
            )
        }
    }
```

> This requires updating the `if let renderEngine` branch in `GlobeDisplayApp`. The full updated body:

```swift
var body: some Scene {
    WindowGroup {
        Group {
            if let engine = renderEngine {
                ControlPanelView()
                    .environment(appState)
                    .environment(\.renderEngine, engine)
                    .onAppear {
                        if displayManager == nil {
                            displayManager = ExternalDisplayManager(
                                renderEngine: engine,
                                appState: appState
                            )
                        }
                    }
            } else {
                ContentUnavailableView(
                    "Metal Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This device does not support Metal rendering.")
                )
            }
        }
    }
}
```

**Step 5: Build and run on iPad — Cmd+R**

Select your iPad as the destination. The app should:
- Launch and show the dark-themed control panel
- Sidebar with "Planets" category
- Content grid with 5 planetary texture cards
- Rotation slider in the bottom toolbar
- "No display" indicator in amber

**Step 6: Commit**

```bash
git add GlobeDisplay/UI/ GlobeDisplay/App/GlobeDisplayApp.swift
git commit -m "feat: add NavigationSplitView control panel with content browser and rotation slider"
```

---

## Task 12: DisplayCalibration Tests

**Files:**
- Create: `GlobeDisplayTests/DisplayCalibrationTests.swift`

**Step 1: Write the tests**

Create `GlobeDisplayTests/DisplayCalibrationTests.swift`:

```swift
import XCTest
@testable import GlobeDisplay

final class DisplayCalibrationTests: XCTestCase {

    // These tests verify MapProjection.normalizedRotation, which is the math
    // behind the DisplayCalibration rotation offset feature.

    func test_normalizedRotation_exactlyOneRotation_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(360.0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_twoRotations_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(720.0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_negativeQuarterTurn_equalsThreeQuarterTurn() {
        XCTAssertEqual(
            MapProjection.normalizedRotation(-90.0),
            MapProjection.normalizedRotation(270.0),
            accuracy: 0.0001
        )
    }

    func test_normalizedRotation_90degrees_returnsQuarter() {
        XCTAssertEqual(MapProjection.normalizedRotation(90.0), 0.25, accuracy: 0.0001)
    }
}
```

**Step 2: Run tests — Cmd+U**

Expected: All 4 tests pass (the implementation is already in `MapProjection.swift`).

**Step 3: Commit**

```bash
git add GlobeDisplayTests/DisplayCalibrationTests.swift
git commit -m "test: add DisplayCalibration rotation tests"
```

---

## Task 13: Manual QA on Hardware

This task is performed by the human reviewer. No code changes.

**Setup:**
1. Plug iPad into Mac via USB
2. In Xcode, select your iPad as the run destination
3. Cmd+R to build and run
4. If prompted for provisioning: Xcode → Preferences → Accounts → manage certificates → create iOS Development certificate

**QA Checklist:**

- [ ] App launches successfully, iPad shows dark-themed control panel
- [ ] Sidebar shows "Planets" category
- [ ] Content grid shows 5 planetary texture cards with thumbnails
- [ ] Plug in HDMI adapter + HDMI cable to MagicPlanet
- [ ] Status indicator turns green and shows "Globe connected"
- [ ] Tap "Earth — Blue Marble" → globe displays the Blue Marble image
- [ ] Drag rotation slider → image shifts horizontally on the globe in real time
- [ ] Wrap-around works: drag to 360° then back to 0° — no seam or jump
- [ ] Tap each of the 5 textures — each loads correctly on the globe
- [ ] Unplug HDMI → indicator returns to amber "No display"
- [ ] Re-plug → indicator turns green, previously selected content reappears

**If any item fails:** Create a GitHub issue describing the failure with the specific step and observed behavior before continuing to Phase 2.

---

## Final State After Phase 1

All unit tests pass:
```bash
xcodebuild test \
  -project GlobeDisplay.xcodeproj \
  -scheme GlobeDisplay \
  -destination 'platform=iOS,name=<your iPad name>' \
  -only-testing:GlobeDisplayTests
```

Working modules:
- `MapProjection` — fully tested coordinate math
- `ContentBundle` — Codable model with round-trip tests
- `AppState` — observable state container
- `RenderEngine` — Metal compositor, rotation support
- `ExternalDisplayManager` — HDMI screen detection
- `ContentManager` — 5 bundled planetary textures
- `ControlPanelView` — NavigationSplitView with content browser and rotation slider

Ready for Phase 2: animated image sequences, content downloading, and the full `ContentManager` with SOS import.
