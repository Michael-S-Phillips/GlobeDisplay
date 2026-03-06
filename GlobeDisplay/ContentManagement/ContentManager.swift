import CoreGraphics
import ImageIO
import Foundation
import Observation

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
@Observable
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

    /// Returns animated datasets available for download from NOAA SOS.
    /// Entries that have already been downloaded appear in `importedContent` instead.
    func downloadableCatalog() -> [ContentBundle] {
        [
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!,
                title: "Ocean Currents — Beauty",
                description: "NASA's Perpetual Ocean animation visualizes the paths of ocean surface currents from 2005 to 2007, simulated by the ECCO2 model. Currents are colored by speed — calm blue regions give way to fast-moving red and yellow streams. The animation reveals the intricate global conveyor of heat and nutrients that shapes climate and marine life worldwide.",
                category: .ocean,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/perpetual_ocean_beauty.mov")!
                ),
                attribution: "NASA/Goddard Space Flight Center Scientific Visualization Studio",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000002")!,
                title: "Ocean Currents — Temperature",
                description: "This version of NASA's Perpetual Ocean combines current paths with sea surface temperature data. Cool blues mark cold polar and deep upwelling waters; warm reds and oranges trace the Gulf Stream, Kuroshio Current, and equatorial warm pools. The overlay reveals how ocean circulation redistributes heat from the tropics toward the poles.",
                category: .ocean,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/perpetual_ocean_temp.mov")!
                ),
                attribution: "NASA/Goddard Space Flight Center Scientific Visualization Studio",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000003")!,
                title: "Ocean Currents — Salinity",
                description: "Ocean salinity drives thermohaline circulation — saltier, denser water sinks; fresher water rises. This animation shows modeled surface salinity variations alongside current paths. Blue indicates low-salinity water (near river mouths and melting ice); red indicates high-salinity regions. The tropics are saltiest due to high evaporation; polar seas are freshened by ice melt.",
                category: .ocean,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/perpetual_ocean_salinity.mov")!
                ),
                attribution: "NASA/Goddard Space Flight Center Scientific Visualization Studio",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000004")!,
                title: "Thermohaline Conveyor Belt",
                description: "The global thermohaline circulation — Earth's great oceanic conveyor belt — transports heat, salt, carbon, and nutrients throughout the world's oceans over centuries to millennia. Warm surface water flows toward the poles; as it cools and becomes saltier, it sinks and flows back as cold deep water. This circulation regulates climate on a planetary scale, including the mild climate of northwest Europe.",
                category: .ocean,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/ocean_conveyor_belt_400.mov")!
                ),
                attribution: "NOAA Science on a Sphere",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000005")!,
                title: "Tectonic Plate Reconstruction",
                description: "Watch 200 million years of plate tectonic movement compressed into minutes. Starting from the supercontinent Pangaea, the continents drift to their current positions as the Atlantic Ocean opens, India collides with Asia to form the Himalayas, and the Pacific shrinks. This reconstruction is based on paleomagnetic data, sea floor spreading records, and fossil distribution patterns.",
                category: .earth,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/plate_movement_400.mov")!
                ),
                attribution: "NOAA Science on a Sphere",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000006")!,
                title: "Atmospheric Winds — GEOS-5",
                description: "A global simulation of Earth's atmospheric winds from NASA's GEOS-5 model, showing the swirling, turbulent flow of air across the planet. Jet streams, trade winds, tropical cyclones, and polar vortices are all visible. The intricate, dynamic patterns reveal how the atmosphere continuously redistributes heat and moisture from the tropics to the poles.",
                category: .atmosphere,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/nccs_wind_400.mov")!
                ),
                attribution: "NASA/Goddard Space Flight Center Scientific Visualization Studio",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000007")!,
                title: "Sea Ice Extent 1978–Present",
                description: "Forty-plus years of Arctic and Antarctic sea ice coverage from satellite passive microwave sensors. Watch the seasonal freeze-thaw cycle play out year after year while the long-term trend of Arctic ice loss becomes unmistakable. Antarctic sea ice shows higher year-to-year variability. Sea ice reflects sunlight back to space; its loss accelerates warming in a feedback loop called ice-albedo feedback.",
                category: .cryosphere,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/10day_seaice.mov")!
                ),
                attribution: "NOAA/NSIDC",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000008")!,
                title: "CO₂ Concentration — Annual Cycle",
                description: "A NASA model simulation showing the annual cycle of atmospheric carbon dioxide concentration. CO₂ levels pulse with the seasons — Northern Hemisphere vegetation absorbs CO₂ in summer, releasing it in winter — while the long-term concentration rises year over year due to fossil fuel combustion. The visualization tracks CO₂ from power plants, cities, fires, and ocean outgassing across the globe.",
                category: .atmosphere,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/geos_5_carbon_400_audio.mov")!
                ),
                attribution: "NASA/Goddard Space Flight Center Scientific Visualization Studio",
                license: "Public Domain (U.S. Government Work)"
            ),
            ContentBundle(
                id: UUID(uuidString: "A0000000-0000-0000-0000-000000000009")!,
                title: "Hurricane Tracks 1950–2020",
                description: "Seven decades of tropical cyclone tracks from all ocean basins worldwide. Each storm is colored by intensity — tropical depression, tropical storm, and Category 1–5 hurricane. The pattern reveals preferred genesis regions, characteristic recurving paths, and how the frequency and intensity of Atlantic hurricanes has changed over the observational record. The most active basins are the northwest Pacific (typhoons) and north Atlantic.",
                category: .atmosphere,
                contentType: .imageSequence,
                resolution: CodableSize(width: 2048, height: 1024),
                source: .downloaded,
                assets: ContentAssets(
                    downloadURL: URL(string: "https://sos.noaa.gov/videos-original/cumulative_hurricanes.mov")!
                ),
                attribution: "NOAA/NHC",
                license: "Public Domain (U.S. Government Work)"
            ),
        ]
    }

    /// True if a bundle with `id` has already been downloaded and imported.
    func isDownloaded(_ id: UUID) -> Bool {
        importedContent.contains { $0.id == id }
    }

    /// Returns bundled + downloadable (not yet imported) + imported content.
    func allContent() -> [ContentBundle] {
        let imported = importedContent
        let downloadable = downloadableCatalog().filter { catalog in
            !imported.contains { $0.id == catalog.id }
        }
        return bundledContent() + downloadable + imported
    }

    /// Adds an externally parsed bundle to the in-memory catalog.
    func importBundle(_ bundle: ContentBundle) {
        // Avoid duplicates (re-download or retry).
        if !importedContent.contains(where: { $0.id == bundle.id }) {
            importedContent.append(bundle)
        }
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
