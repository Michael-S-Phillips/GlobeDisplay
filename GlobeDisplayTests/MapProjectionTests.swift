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
