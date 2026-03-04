import CoreGraphics
import ImageIO
import Foundation

enum ContentManagerError: Error, LocalizedError {
    case imageNotFound(String)
    case imageDecodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageNotFound(let name): "Bundled image not found: \(name)"
        case .imageDecodeFailed(let name): "Failed to decode image: \(name)"
        }
    }
}

/// Discovers, indexes, and serves content to the rendering pipeline.
/// Phase 1: bundled planetary textures only.
@MainActor
final class ContentManager {

    static let shared = ContentManager()
    private init() {}

    // MARK: - Catalog

    /// Returns the full catalog of content available in Phase 1.
    func bundledContent() -> [ContentBundle] {
        [
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Earth — Blue Marble",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "blue_marble"),
                attribution: "NASA Visible Earth",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "Earth — Night Lights",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "earth_night"),
                attribution: "NASA Black Marble / Earth Observatory",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Mars",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "mars"),
                attribution: "NASA/JPL-Caltech",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                title: "Moon",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "moon"),
                attribution: "NASA/GSFC/Arizona State University",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                title: "Jupiter",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "jupiter"),
                attribution: "NASA/JPL-Caltech",
                license: "Public Domain (U.S. Government Work)"
            ),
        ]
    }

    // MARK: - Image Loading

    /// Loads a CGImage for a bundled ContentBundle from the app bundle's BundledContent folder.
    func loadCGImage(for bundle: ContentBundle) throws -> CGImage {
        guard let imageName = bundle.assets.primaryImageName else {
            throw ContentManagerError.imageNotFound("(no image name in assets)")
        }

        let url = Bundle.main.url(forResource: imageName, withExtension: "jpg")
               ?? Bundle.main.url(forResource: imageName, withExtension: "png")

        guard let url else {
            throw ContentManagerError.imageNotFound(imageName)
        }

        guard let dataProvider = CGDataProvider(url: url as CFURL) else {
            throw ContentManagerError.imageDecodeFailed(imageName)
        }

        // Try JPEG first, then PNG
        let image = CGImage(jpegDataProviderSource: dataProvider, decode: nil,
                            shouldInterpolate: true, intent: .defaultIntent)
                 ?? CGImage(pngDataProviderSource: dataProvider, decode: nil,
                            shouldInterpolate: true, intent: .defaultIntent)

        guard let image else {
            throw ContentManagerError.imageDecodeFailed(imageName)
        }

        return image
    }
}
