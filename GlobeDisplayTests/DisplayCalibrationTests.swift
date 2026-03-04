import XCTest
@testable import GlobeDisplay

/// Tests for the rotation offset math that backs DisplayCalibration.
/// The implementation lives in MapProjection.normalizedRotation(_:).
final class DisplayCalibrationTests: XCTestCase {

    // MARK: - Boundary values

    func test_normalizedRotation_exactlyOneRotation_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(360.0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_twoRotations_returnsZero() {
        XCTAssertEqual(MapProjection.normalizedRotation(720.0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_90degrees_returnsQuarter() {
        XCTAssertEqual(MapProjection.normalizedRotation(90.0), 0.25, accuracy: 0.0001)
    }

    // MARK: - Wrapping

    func test_normalizedRotation_negativeQuarterTurn_equalsThreeQuarterTurn() {
        XCTAssertEqual(
            MapProjection.normalizedRotation(-90.0),
            MapProjection.normalizedRotation(270.0),
            accuracy: 0.0001
        )
    }

    func test_normalizedRotation_negativeDegrees_producesPositiveResult() {
        let result = MapProjection.normalizedRotation(-180.0)
        XCTAssertGreaterThanOrEqual(result, 0.0)
        XCTAssertLessThan(result, 1.0)
        XCTAssertEqual(result, 0.5, accuracy: 0.0001)
    }

    // MARK: - Slider range

    func test_normalizedRotation_sliderMinimum_returnsZero() {
        // The UI slider minimum is 0°
        XCTAssertEqual(MapProjection.normalizedRotation(0.0), 0.0, accuracy: 0.0001)
    }

    func test_normalizedRotation_sliderMaximum_returnsZero() {
        // The UI slider maximum is 360°, which wraps back to 0 (no seam visible)
        XCTAssertEqual(MapProjection.normalizedRotation(360.0), 0.0, accuracy: 0.0001)
    }
}
