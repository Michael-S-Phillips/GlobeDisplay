import CoreGraphics
import UIKit

/// Renders arrays of GeoEvents onto a 2048×1024 equirectangular CGContext
/// and returns a CGImage for upload to the GPU overlay texture.
///
/// Drawing is performed entirely with CGContext / UIBezierPath so there is
/// no dependency on UIKit views — only the drawing primitives, which are
/// safe to call on the main actor.
@MainActor
final class OverlayCompositor {

    static let shared = OverlayCompositor()

    private let canvasSize = CGSize(width: 2048, height: 1024)

    // Prevent external instantiation.
    private init() {}

    // MARK: - Public API

    /// Renders all active overlay events to an equirectangular CGImage.
    ///
    /// Returns `nil` when every supplied array is empty, signalling the caller
    /// that the overlay texture should be cleared rather than updated.
    func renderOverlay(
        earthquakes: [GeoEvent],
        volcanoes: [GeoEvent],
        wildfires: [GeoEvent]
    ) -> CGImage? {
        guard !earthquakes.isEmpty || !volcanoes.isEmpty || !wildfires.isEmpty else {
            return nil
        }

        let width  = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Flip y-axis: CGBitmapContext has y=0 at bottom; MapProjection has y=0 at top (north pole).
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        drawEarthquakes(earthquakes, in: context)
        drawVolcanoes(volcanoes, in: context)
        drawWildfires(wildfires, in: context)

        return context.makeImage()
    }

    // MARK: - Event Drawing

    private func drawEarthquakes(_ events: [GeoEvent], in context: CGContext) {
        let now = Date()
        for event in events {
            let pixel = MapProjection.toPixel(
                latitude: event.latitude,
                longitude: event.longitude,
                in: canvasSize
            )
            let rawRadius = max(4.0, (event.magnitude ?? 2.0) * 5.0)
            let radius = min(rawRadius, 30.0)

            let age = now.timeIntervalSince(event.timestamp)
            let (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat)
            if age <= 3600 {           // within 1 hour — red
                (r, g, b, a) = (1.0, 0.1, 0.1, 0.8)
            } else if age <= 21600 {   // within 6 hours — orange
                (r, g, b, a) = (1.0, 0.5, 0.0, 0.7)
            } else {                   // older — yellow
                (r, g, b, a) = (1.0, 0.9, 0.0, 0.6)
            }

            drawFilledCircle(at: pixel, radius: radius, r: r, g: g, b: b, alpha: a, in: context)
            drawStrokeRing(at: pixel, radius: radius + 1, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)

            // Anti-dateline wrap: mirror point when near ±180° longitude.
            if let mirroredLon = dateline_mirrorLongitude(event.longitude) {
                let mirrorPixel = MapProjection.toPixel(
                    latitude: event.latitude,
                    longitude: mirroredLon,
                    in: canvasSize
                )
                drawFilledCircle(at: mirrorPixel, radius: radius, r: r, g: g, b: b, alpha: a, in: context)
                drawStrokeRing(at: mirrorPixel, radius: radius + 1, lineWidth: 1.5, r: 1, g: 1, b: 1, alpha: 1, in: context)
            }
        }
    }

    private func drawVolcanoes(_ events: [GeoEvent], in context: CGContext) {
        for event in events {
            let pixel = MapProjection.toPixel(
                latitude: event.latitude,
                longitude: event.longitude,
                in: canvasSize
            )
            drawTriangle(at: pixel, side: 14, r: 0.9, g: 0.0, b: 0.8, alpha: 0.85, in: context)

            if let mirroredLon = dateline_mirrorLongitude(event.longitude) {
                let mirrorPixel = MapProjection.toPixel(
                    latitude: event.latitude,
                    longitude: mirroredLon,
                    in: canvasSize
                )
                drawTriangle(at: mirrorPixel, side: 14, r: 0.9, g: 0.0, b: 0.8, alpha: 0.85, in: context)
            }
        }
    }

    private func drawWildfires(_ events: [GeoEvent], in context: CGContext) {
        for event in events {
            let pixel = MapProjection.toPixel(
                latitude: event.latitude,
                longitude: event.longitude,
                in: canvasSize
            )
            drawFilledCircle(at: pixel, radius: 8, r: 1.0, g: 0.4, b: 0.0, alpha: 0.75, in: context)

            if let mirroredLon = dateline_mirrorLongitude(event.longitude) {
                let mirrorPixel = MapProjection.toPixel(
                    latitude: event.latitude,
                    longitude: mirroredLon,
                    in: canvasSize
                )
                drawFilledCircle(at: mirrorPixel, radius: 8, r: 1.0, g: 0.4, b: 0.0, alpha: 0.75, in: context)
            }
        }
    }

    // MARK: - Primitive Drawing Helpers

    private func drawFilledCircle(
        at center: CGPoint,
        radius: CGFloat,
        r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat,
        in context: CGContext
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.setFillColor(red: r, green: g, blue: b, alpha: alpha)
        context.fillEllipse(in: rect)
    }

    private func drawStrokeRing(
        at center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat,
        in context: CGContext
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.setStrokeColor(red: r, green: g, blue: b, alpha: alpha)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: rect)
    }

    /// Draws an upward-pointing equilateral triangle centred at `center`
    /// with the given side length in pixels.
    private func drawTriangle(
        at center: CGPoint,
        side: CGFloat,
        r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat,
        in context: CGContext
    ) {
        // Equilateral triangle geometry:
        //   height = (√3 / 2) × side
        //   centroid is at 1/3 height from base.
        let height = (sqrt(3.0) / 2.0) * side
        let topY    = center.y - (height * 2.0 / 3.0)    // apex above centroid
        let bottomY = center.y + (height / 3.0)           // base below centroid
        let halfBase = side / 2.0

        let path = UIBezierPath()
        path.move(to: CGPoint(x: center.x, y: topY))
        path.addLine(to: CGPoint(x: center.x - halfBase, y: bottomY))
        path.addLine(to: CGPoint(x: center.x + halfBase, y: bottomY))
        path.close()

        context.setFillColor(red: r, green: g, blue: b, alpha: alpha)
        context.addPath(path.cgPath)
        context.fillPath()

        context.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.setLineWidth(1.0)
        context.addPath(path.cgPath)
        context.strokePath()
    }

    // MARK: - Anti-Dateline Wrap

    /// Returns a mirrored longitude (lon ± 360°) when the event falls within
    /// 15° of the ±180° dateline, so markers are drawn on both edges of the
    /// equirectangular canvas.  Returns `nil` if no wrap is needed.
    private func dateline_mirrorLongitude(_ longitude: Double) -> Double? {
        let threshold = 15.0
        if longitude > 180.0 - threshold {        // near +180° → also draw at lon - 360°
            return longitude - 360.0
        } else if longitude < -180.0 + threshold { // near -180° → also draw at lon + 360°
            return longitude + 360.0
        }
        return nil
    }
}
