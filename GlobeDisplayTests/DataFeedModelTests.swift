import XCTest
@testable import GlobeDisplay

final class DataFeedModelTests: XCTestCase {

    func test_airQuality_displayName() {
        XCTAssertEqual(DataFeedType.airQuality.displayName, "Air Quality")
    }

    func test_airQuality_systemImage() {
        XCTAssertEqual(DataFeedType.airQuality.systemImage, "aqi.medium")
    }

    func test_airQuality_updateInterval() {
        XCTAssertEqual(DataFeedType.airQuality.updateInterval, 3600)
    }

    func test_airQuality_overlayColor() {
        XCTAssertEqual(DataFeedType.airQuality.overlayColor, .cyan)
    }

    func test_airQuality_eventType() {
        XCTAssertEqual(DataFeedType.airQuality.eventType, .airQuality)
    }
}
