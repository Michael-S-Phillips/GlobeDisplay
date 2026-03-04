import XCTest
@testable import GlobeDisplay

final class ContentBundleTests: XCTestCase {

    func test_contentBundle_codableRoundTrip() throws {
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

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ContentBundle.self, from: data)

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

    func test_contentCategory_allCases_areDistinct() {
        let allCases = ContentCategory.allCases
        let uniqueCases = Set(allCases.map { $0.rawValue })
        XCTAssertEqual(allCases.count, uniqueCases.count)
    }

    func test_contentAssets_defaultsToNilOptionals() {
        let assets = ContentAssets(primaryImageName: "test")
        XCTAssertNil(assets.sequenceDirectory)
        XCTAssertNil(assets.videoPath)
        XCTAssertNil(assets.frameCount)
        XCTAssertNil(assets.framerate)
    }
}
