import Metal
import MetalKit
import CoreGraphics

// Matches the Uniforms struct in EquirectangularShaders.metal exactly.
private struct Uniforms {
    var rotationOffset: Float
    var aspectRatio: Float
    var projectionGamma: Float
    var projectionRadius: Float
    var brightness: Float       // output multiplier, default 1.0
    var flipHorizontal: Float   // 1.0 = mirror east/west
    var flipVertical: Float     // 1.0 = flip north/south
}

enum RenderEngineError: Error {
    case metalDeviceUnavailable
    case commandQueueFailed
    case shaderLibraryFailed
    case shaderFunctionNotFound(String)
    case pipelineStateFailed(Error)
    case textureCreationFailed
    case bufferCreationFailed
    case blitEncoderFailed
    case cgContextCreationFailed
}

/// Owns the Metal rendering pipeline and composites equirectangular frames
/// to the external display at 30 fps.
///
/// @MainActor ensures all Metal resource access and delegate callbacks
/// occur on the same thread without data races.
@MainActor
final class RenderEngine: NSObject {

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var baseTexture: MTLTexture?

    /// Longitude rotation in degrees (0–360). Updated in real time from the UI slider.
    var rotationOffset: Double = 0.0

    /// Fisheye projection correction exponent. 1 = equidistant, 2 = equisolid.
    /// Tune this slider until latitude rings appear horizontal on the globe.
    var projectionGamma: Double = 1.0

    /// cs-space radius at which the south pole appears. 0.7 empirically calibrated for MagicPlanet.
    var projectionRadius: Double = 0.7

    /// Output brightness multiplier (0.5–1.5). Default 1.0.
    var brightness: Double = 1.0

    /// Mirror the east/west (longitude) direction.
    var flipHorizontal: Bool = false

    /// Flip the north/south (co-latitude) direction.
    var flipVertical: Bool = false

    /// Retains the active AnimationSequencer so its lifecycle is tied to the engine.
    var animationSequencer: AnimationSequencer?

    /// Overlay texture (RGBA, transparent background) composited over the base map.
    /// Set to nil to disable overlay blending.
    var overlayTexture: MTLTexture?

    /// A reusable 1×1 fully-transparent texture passed to the shader when no overlay is active.
    /// Avoids a nil check branch in every draw call.
    private var clearOverlayTexture: MTLTexture?

    // MARK: - Init

    /// Private designated init satisfies NSObject's non-throwing init() requirement.
    private init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        super.init()
    }

    /// Public throwing factory method used by callers (e.g. `try? RenderEngine.make()`).
    /// A static factory is required because Swift does not allow overriding NSObject's
    /// non-throwing `init()` with a throwing initializer.
    static func make() throws -> RenderEngine {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderEngineError.metalDeviceUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderEngineError.commandQueueFailed
        }
        let engine = RenderEngine(device: device, commandQueue: commandQueue)
        try engine.buildPipeline()
        engine.buildClearOverlayTexture()
        return engine
    }

    private func buildClearOverlayTexture() {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false
        )
        desc.usage = .shaderRead
        desc.storageMode = .shared
        clearOverlayTexture = device.makeTexture(descriptor: desc)
        // All bytes default to zero → fully transparent pixel.
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

    /// Loads a CGImage as the current base map texture.
    /// The previous texture stays visible until the new one is fully uploaded to the GPU.
    func loadTexture(from image: CGImage) async throws {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: false
        ]
        baseTexture = try await loader.newTexture(cgImage: image, options: options)
    }

    // MARK: - Animation Frame Update

    /// Updates the base texture directly from a CGImage for animation playback.
    ///
    /// Bypasses MTKTextureLoader's async overhead by rendering the CGImage into a
    /// CPU-accessible staging `MTLBuffer` via a `CGContext`, then blitting to a
    /// GPU-private `MTLTexture` using a `MTLBlitCommandEncoder`.
    func updateAnimationFrame(_ image: CGImage) throws {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let byteCount = bytesPerRow * height

        // Allocate a shared-storage Metal buffer so the CPU can write pixels
        // and the GPU can read them without a copy through the kernel.
        guard let stagingBuffer = device.makeBuffer(
            length: byteCount,
            options: .storageModeShared
        ) else {
            throw RenderEngineError.bufferCreationFailed
        }

        // Render CGImage into the staging buffer's raw memory using a CGContext.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Big,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ]

        guard let context = CGContext(
            data: stagingBuffer.contents(),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw RenderEngineError.cgContextCreationFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create the private destination texture.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        descriptor.storageMode = .private

        guard let privateTexture = device.makeTexture(descriptor: descriptor) else {
            throw RenderEngineError.textureCreationFailed
        }

        // Blit from the staging buffer into the private texture.
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            throw RenderEngineError.blitEncoderFailed
        }

        blitEncoder.copy(
            from: stagingBuffer,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: byteCount,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: privateTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
        commandBuffer.commit()

        baseTexture = privateTexture
    }

    // MARK: - Overlay Texture

    /// Uploads a CGImage as the overlay texture (RGBA with transparency).
    /// Uses the same CPU→GPU blit path as updateAnimationFrame.
    func updateOverlayTexture(from image: CGImage) throws {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        guard let stagingBuffer = device.makeBuffer(
            length: byteCount, options: .storageModeShared
        ) else { throw RenderEngineError.bufferCreationFailed }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Big,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ]
        guard let context = CGContext(
            data: stagingBuffer.contents(),
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { throw RenderEngineError.cgContextCreationFailed }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = .shaderRead
        descriptor.storageMode = .private

        guard let privateTexture = device.makeTexture(descriptor: descriptor)
        else { throw RenderEngineError.textureCreationFailed }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else { throw RenderEngineError.blitEncoderFailed }

        blitEncoder.copy(
            from: stagingBuffer, sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow, sourceBytesPerImage: byteCount,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: privateTexture, destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
        commandBuffer.commit()

        overlayTexture = privateTexture
    }
}

// MARK: - MTKViewDelegate

extension RenderEngine: MTKViewDelegate {

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Phase 1: no action needed. Future phases may resize overlay textures here.
    }

    func draw(in view: MTKView) {
        guard
            let pipelineState,
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        // Configure the descriptor before creating the encoder — mutations after
        // makeRenderCommandEncoder(descriptor:) are silently ignored by Metal.
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0.1, blue: 0.4, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        encoder.setRenderPipelineState(pipelineState)

        if let texture = baseTexture {
            encoder.setFragmentTexture(texture, index: 0)
            // Use the live overlay texture, or fall back to the 1×1 clear placeholder.
            encoder.setFragmentTexture(overlayTexture ?? clearOverlayTexture, index: 1)
            let aspect = Float(view.drawableSize.height / view.drawableSize.width)
            var uniforms = Uniforms(
                rotationOffset: Float(MapProjection.normalizedRotation(rotationOffset)),
                aspectRatio: aspect,
                projectionGamma: Float(projectionGamma),
                projectionRadius: Float(projectionRadius),
                brightness: Float(brightness),
                flipHorizontal: flipHorizontal ? 1.0 : 0.0,
                flipVertical: flipVertical ? 1.0 : 0.0
            )
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
