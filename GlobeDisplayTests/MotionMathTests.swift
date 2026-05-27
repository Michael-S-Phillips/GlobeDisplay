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

    // MARK: - advanceTransition

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
