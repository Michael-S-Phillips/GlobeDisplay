import MetalKit

/// The MTKView rendered to the external HDMI display (the MagicPlanet globe).
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
