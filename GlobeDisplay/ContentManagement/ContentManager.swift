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

    /// Imported bundles from user/downloaded content. Mutated by importBundle(_:).
    private(set) var importedContent: [ContentBundle] = []

    /// Returns all bundled (shipped) content.
    func bundledContent() -> [ContentBundle] {
        [
            // ── Solar System ────────────────────────────────────────────
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Earth — Blue Marble",
                description: "The iconic \"Blue Marble\" view of Earth as seen from space. This composite mosaic, assembled from NASA satellite imagery, shows the full planet with realistic colors — deep blue oceans, green and brown landmasses, white polar ice caps, and swirling cloud patterns. It remains one of the most widely reproduced photographs in history.",
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
                title: "Moon",
                description: "A global mosaic of Earth's Moon compiled from thousands of images captured by the Lunar Reconnaissance Orbiter Camera. The Moon's surface is heavily cratered, shaped by billions of years of asteroid impacts. Dark regions called maria (\"seas\") are ancient volcanic plains; bright highland regions are older, more heavily cratered terrain.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "moon"),
                attribution: "NASA/GSFC/Arizona State University",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Mars",
                description: "The Red Planet, Mars, is the fourth planet from the Sun and the most Earth-like world in our solar system. Its red color comes from iron oxide (rust) on its surface. Mars hosts the largest volcano in the solar system (Olympus Mons) and a canyon system (Valles Marineris) that stretches as wide as the United States. Evidence suggests liquid water once flowed across its surface.",
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
                title: "Venus",
                description: "Venus is Earth's closest planetary neighbor and nearly the same size, yet it is radically different — a hellish world with surface temperatures of 465°C (870°F) and crushing atmospheric pressure 90 times that of Earth. This texture is derived from radar data collected by NASA's Magellan spacecraft, which penetrated Venus's thick cloud cover to map its surface. The colors are simulated based on data from Soviet Venera landers.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "venus"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/JPL-Caltech (Magellan data)",
                license: "CC BY 4.0"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                title: "Mercury",
                description: "Mercury is the smallest planet in our solar system and the closest to the Sun. Despite being the innermost planet, Mercury is not the hottest — that title belongs to Venus. Mercury's surface is heavily cratered and resembles our Moon, shaped by billions of years of impacts with no atmosphere or geological activity to erase them. This global mosaic was assembled from data collected by NASA's MESSENGER spacecraft during its orbital mission from 2011 to 2015.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "mercury"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/JHUAPL (MESSENGER data)",
                license: "CC BY 4.0"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                title: "Jupiter",
                description: "Jupiter is the largest planet in our solar system — so large that all other planets could fit inside it with room to spare. It is a gas giant with no solid surface, composed mostly of hydrogen and helium. Its most recognizable feature is the Great Red Spot, a storm larger than Earth that has been raging for at least 350 years. Jupiter's powerful gravity has protected Earth from many asteroid and comet impacts over the history of our solar system.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "jupiter"),
                attribution: "NASA/JPL-Caltech",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
                title: "Saturn",
                description: "Saturn is famous for its spectacular ring system, composed of billions of ice and rock particles ranging in size from grains of sand to mountains. Despite being the second-largest planet, Saturn is the least dense — it would float in water. Saturn has 146 known moons, including Titan, which has a thick atmosphere and lakes of liquid methane, and Enceladus, which shoots geysers of water ice from a subsurface ocean that may harbor life.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "saturn"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/JPL-Caltech (Cassini data)",
                license: "CC BY 4.0"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
                title: "Uranus",
                description: "Uranus is an ice giant that rotates on its side — its axial tilt is 98°, meaning it essentially rolls around the Sun like a ball. This extreme tilt causes the most extreme seasons in the solar system, with each pole experiencing 42 years of continuous sunlight followed by 42 years of darkness. Uranus appears blue-green due to methane in its atmosphere, which absorbs red light. It has 13 known rings and 27 known moons.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "uranus"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/JPL-Caltech (Voyager 2 data)",
                license: "CC BY 4.0"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
                title: "Neptune",
                description: "Neptune is the most distant planet in our solar system and the windiest world we know of — its storms produce wind speeds of up to 2,100 km/h (1,300 mph). Like Uranus, Neptune is an ice giant with a deep blue color from methane in its atmosphere. Its largest moon, Triton, orbits in retrograde (backwards) and is likely a captured Kuiper Belt object. Triton is slowly spiraling toward Neptune and will be torn apart by tidal forces in about 3.6 billion years.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "neptune"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/JPL-Caltech (Voyager 2 data)",
                license: "CC BY 4.0"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
                title: "Pluto",
                description: "Pluto was the ninth planet from 1930 until 2006, when it was reclassified as a dwarf planet. NASA's New Horizons spacecraft flew past Pluto in 2015, revealing a surprisingly complex and geologically active world with mountains of water ice, a vast heart-shaped nitrogen glacier called Tombaugh Regio, and a hazy atmosphere. Pluto orbits in the Kuiper Belt, a distant region of the solar system populated by icy bodies left over from its formation.",
                category: .planets,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "pluto"),
                attribution: "Planet Pixel Emporium / NASA/JHUAPL/SwRI (New Horizons data)",
                license: "Free for non-commercial use"
            ),

            // ── Earth Datasets ──────────────────────────────────────────
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
                title: "Earth — Night Lights",
                description: "This composite image of Earth at night, known as the \"Black Marble,\" was created from data collected by the Suomi NPP satellite in 2016. The bright clusters of light reveal human civilization — dense cities, transportation corridors, and industrial facilities. The image also shows natural light sources: wildfires in Africa, gas flares from oil fields in Siberia and the Middle East, and the aurora in the polar regions.",
                category: .earth,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "earth_night"),
                attribution: "NASA Black Marble / Earth Observatory",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!,
                title: "Earth — Topography",
                description: "This dataset shows Earth's elevation and ocean depth using a color scale from deep blue (deepest ocean trenches) through green and yellow (lowlands and plains) to white (highest mountains). The data combines the ETOPO1 Global Relief Model, which merges land topography from satellites and ground surveys with ocean bathymetry from ship-based sonar measurements. The deepest point is the Challenger Deep in the Mariana Trench (−10,935 m); the highest is Mount Everest (8,849 m).",
                category: .earth,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "earth_topo"),
                attribution: "NASA/NOAA ETOPO1 Global Relief Model",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!,
                title: "Earth — Cloud Cover",
                description: "A global composite of cloud cover over Earth, assembled from satellite imagery. Clouds cover roughly 67% of Earth's surface at any given time and play a critical role in regulating the planet's energy balance. Bright white areas indicate thick cloud cover; cloud-free regions reveal the underlying land and ocean surface. The tropics show persistent bands of convective cloud activity, while the subtropics are characteristically cloud-free — the dry zones where most of the world's deserts are found.",
                category: .atmosphere,
                contentType: .staticImage,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .bundled,
                assets: ContentAssets(primaryImageName: "earth_clouds"),
                attribution: "Solar System Scope (CC BY 4.0) / NASA/GSFC Blue Marble data",
                license: "CC BY 4.0"
            ),
        ]
    }

    /// Returns bundled + imported content combined.
    func allContent() -> [ContentBundle] {
        bundledContent() + importedContent
    }

    /// Adds an externally parsed bundle to the in-memory catalog.
    func importBundle(_ bundle: ContentBundle) {
        importedContent.append(bundle)
    }

    // MARK: - Image Loading

    /// Loads a CGImage for a bundled ContentBundle from the app bundle's BundledContent folder.
    /// `nonisolated` so callers can decode off the main thread without blocking the UI.
    nonisolated func loadCGImage(for bundle: ContentBundle) throws -> CGImage {
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
