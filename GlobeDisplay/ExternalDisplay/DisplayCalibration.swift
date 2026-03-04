import CoreGraphics

/// User-configurable display settings stored independently of the physical screen's native resolution.
struct DisplayCalibration: Sendable {
    /// The resolution at which RenderEngine composites frames.
    /// The physical display scales the output to fit.
    var renderResolution: CGSize = CGSize(width: 2048, height: 1024)
}
