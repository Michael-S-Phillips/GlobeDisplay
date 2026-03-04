import Metal
import MetalKit
import CoreGraphics

// Matches the Uniforms struct in EquirectangularShaders.metal exactly.
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

    // MARK: - Init

    /// Private designated init satisfies NSObject's non-throwing init() requirement.
    private init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        super.init()
    }

    /// Public throwing convenience init used by callers (e.g. `try? RenderEngine()`).
    convenience init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderEngineError.metalDeviceUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderEngineError.commandQueueFailed
        }
        self.init(device: device, commandQueue: commandQueue)
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
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

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
