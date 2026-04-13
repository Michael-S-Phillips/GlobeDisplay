import XCTest
@testable import GlobeDisplay

final class StaticOverlayLayerTests: XCTestCase {
    func test_rivers_displayName_isRivers() {
        XCTAssertEqual(StaticOverlayLayer.rivers.displayName, "Rivers")
    }

    func test_rivers_systemImage_isWaterWaves() {
        XCTAssertEqual(StaticOverlayLayer.rivers.systemImage, "water.waves")
    }

    func test_rivers_bundledAssetName_isCorrect() {
        XCTAssertEqual(StaticOverlayLayer.rivers.bundledAssetName, "rivers_2048x1024")
    }

    func test_caseIterable_hasOneCase() {
        XCTAssertEqual(StaticOverlayLayer.allCases.count, 1)
    }
}
