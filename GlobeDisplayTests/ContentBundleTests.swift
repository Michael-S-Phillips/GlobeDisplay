import XCTest
@testable import GlobeDisplay

final class ContentBundleTests: XCTestCase {

    // MARK: - ContentBundle Codable

    func test_contentBundle_codableRoundTrip_preservesAllFields() throws {
        let original = ContentBundle(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            title: "Earth — Blue Marble",
            category: .planets,
            contentType: .staticImage,
            resolution: CGSize(width: 2048, height: 1024),
            source: .bundled,
            assets: ContentAssets(primaryImageName: "blue_marble"),
            attribution: "NASA Visible Earth",
            license: "Public Domain"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContentBundle.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.contentType, original.contentType)
        XCTAssertEqual(decoded.resolution.width, original.resolution.width, accuracy: 0.1)
        XCTAssertEqual(decoded.resolution.height, original.resolution.height, accuracy: 0.1)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.assets.primaryImageName, original.assets.primaryImageName)
        XCTAssertEqual(decoded.attribution, original.attribution)
        XCTAssertEqual(decoded.license, original.license)
    }

    // MARK: - ContentCategory

    func test_contentCategory_allCases_haveDistinctRawValues() {
        let allCases = ContentCategory.allCases
        let uniqueRawValues = Set(allCases.map { $0.rawValue })
        XCTAssertEqual(allCases.count, uniqueRawValues.count)
    }

    func test_contentCategory_allCases_countIsTen() {
        XCTAssertEqual(ContentCategory.allCases.count, 10)
    }

    // MARK: - ContentAssets

    func test_contentAssets_init_setsNonPrimaryFieldsToNil() {
        let assets = ContentAssets(primaryImageName: "test")
        XCTAssertNil(assets.sequenceDirectory)
        XCTAssertNil(assets.videoPath)
        XCTAssertNil(assets.frameCount)
        XCTAssertNil(assets.framerate)
    }

    func test_contentAssets_defaultInit_setsAllFieldsToNil() {
        let assets = ContentAssets()
        XCTAssertNil(assets.primaryImageName)
        XCTAssertNil(assets.sequenceDirectory)
        XCTAssertNil(assets.videoPath)
        XCTAssertNil(assets.frameCount)
        XCTAssertNil(assets.framerate)
    }

    func test_contentAssets_codableRoundTrip_preservesAllFields() throws {
        var assets = ContentAssets(primaryImageName: "frames/base")
        assets.sequenceDirectory = "frames/"
        assets.videoPath = "video/earth.mp4"
        assets.frameCount = 360
        assets.framerate = 30.0

        let data = try JSONEncoder().encode(assets)
        let decoded = try JSONDecoder().decode(ContentAssets.self, from: data)

        XCTAssertEqual(decoded.primaryImageName, assets.primaryImageName)
        XCTAssertEqual(decoded.sequenceDirectory, assets.sequenceDirectory)
        XCTAssertEqual(decoded.videoPath, assets.videoPath)
        XCTAssertEqual(decoded.frameCount, assets.frameCount)
        XCTAssertEqual(decoded.framerate, assets.framerate)
    }

    // MARK: - PlanetaryBody

    func test_planetaryBody_allCases_countIsTen() {
        XCTAssertEqual(PlanetaryBody.allCases.count, 10)
    }

    func test_planetaryBody_displayName_isCapitalized() {
        XCTAssertEqual(PlanetaryBody.earth.displayName, "Earth")
        XCTAssertEqual(PlanetaryBody.mars.displayName, "Mars")
        XCTAssertEqual(PlanetaryBody.jupiter.displayName, "Jupiter")
    }

    func test_planetaryBody_codableRoundTrip_preservesCase() throws {
        let bodies: [PlanetaryBody] = [.earth, .mars, .jupiter, .pluto]
        let data = try JSONEncoder().encode(bodies)
        let decoded = try JSONDecoder().decode([PlanetaryBody].self, from: data)
        XCTAssertEqual(decoded, bodies)
    }
}
