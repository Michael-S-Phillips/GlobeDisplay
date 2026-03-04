import CoreGraphics

/// Equirectangular (plate carrée) projection math.
/// Uses the SOS convention: 0° longitude at horizontal center of image.
enum MapProjection {

    /// Converts geographic coordinates to pixel coordinates in an equirectangular image.
    ///
    /// - Parameters:
    ///   - latitude: Geographic latitude in degrees (−90 to +90; north is positive).
    ///   - longitude: Geographic longitude in degrees (−180 to +180; east is positive).
    ///   - size: The pixel dimensions of the equirectangular image.
    /// - Returns: The corresponding pixel coordinate, where (0, 0) is the top-left corner.
    static func toPixel(latitude: Double, longitude: Double, in size: CGSize) -> CGPoint {
        let x = (longitude + 180.0) / 360.0 * Double(size.width)
        let y = (90.0 - latitude) / 180.0 * Double(size.height)
        return CGPoint(x: x, y: y)
    }

    /// Converts equirectangular pixel coordinates to geographic coordinates.
    ///
    /// - Parameters:
    ///   - pixel: The pixel coordinate in the equirectangular image.
    ///   - size: The pixel dimensions of the equirectangular image.
    /// - Returns: A tuple of `(latitude, longitude)` in degrees.
    static func toCoordinate(pixel: CGPoint, in size: CGSize) -> (latitude: Double, longitude: Double) {
        let longitude = Double(pixel.x) / Double(size.width) * 360.0 - 180.0
        let latitude = 90.0 - Double(pixel.y) / Double(size.height) * 180.0
        return (latitude: latitude, longitude: longitude)
    }

    /// Converts a longitude offset in degrees to a normalized UV offset (0.0–1.0).
    ///
    /// Handles values outside the 0°–360° range via modulo wrapping so the result
    /// is always in the range [0.0, 1.0). A full 360° rotation maps back to 0.0.
    ///
    /// - Parameter degrees: Longitude offset in degrees (any value; wraps automatically).
    /// - Returns: Normalized rotation in the range [0.0, 1.0).
    static func normalizedRotation(_ degrees: Double) -> Double {
        let normalized = degrees / 360.0
        return normalized - floor(normalized)
    }
}
