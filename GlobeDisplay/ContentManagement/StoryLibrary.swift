import Foundation

/// Pre-authored guided stories shipped with the app.
enum StoryLibrary {

    static func allStories() -> [Story] {
        [tourOfSolarSystem, earthDynamicSystems]
    }

    // MARK: - Tour of the Solar System

    /// Content bundle IDs from ContentManager's stable UUIDs.
    private static let earth     = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let moon      = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let mars      = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let venus     = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private static let mercury   = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    private static let jupiter   = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    private static let saturn    = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    private static let uranus    = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
    private static let neptune   = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    private static let pluto     = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private static let nightLights  = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private static let topography   = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!
    private static let cloudCover   = UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!

    private static let tourOfSolarSystem = Story(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        title: "Tour of the Solar System",
        description: "Journey through all eight planets — plus Pluto — from the Sun outward.",
        systemImage: "sparkles",
        steps: [
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!, contentBundleID: mercury,
                      narrative: "Mercury — the smallest planet and the closest to the Sun. A cratered, airless world of extremes: scorching days (430°C) and frigid nights (−180°C). NASA's MESSENGER spacecraft mapped every inch of its surface from 2011 to 2015.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000002")!, contentBundleID: venus,
                      narrative: "Venus — Earth's 'evil twin'. Same size, but a runaway greenhouse effect has made it the hottest planet (465°C). Thick sulfuric acid clouds completely hide the surface, which was mapped by radar aboard NASA's Magellan orbiter.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000003")!, contentBundleID: earth,
                      narrative: "Earth — our home. The only world we know of with liquid water on its surface, a breathable atmosphere, and life. From space, the thin blue haze of our atmosphere looks impossibly fragile against the blackness of space.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000004")!, contentBundleID: moon,
                      narrative: "The Moon — Earth's faithful companion. Formed about 4.5 billion years ago from debris ejected when a Mars-sized body collided with the early Earth. The dark 'seas' (maria) are ancient lava plains; the bright highlands are older, more heavily cratered terrain.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000005")!, contentBundleID: mars,
                      narrative: "Mars — the Red Planet. Iron oxide dust gives it its distinctive color. Home to Olympus Mons (the largest volcano in the solar system, three times the height of Everest) and Valles Marineris (a canyon as wide as the United States). Mars once had liquid water — and may have harbored life.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000006")!, contentBundleID: jupiter,
                      narrative: "Jupiter — the giant. So large that all other planets could fit inside it. A gas giant with no solid surface, it rotates once every 10 hours despite being 1,300 times Earth's volume. The Great Red Spot is a storm that has raged for over 350 years. Jupiter's gravity acts as a shield, deflecting many comets and asteroids away from the inner solar system.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000007")!, contentBundleID: saturn,
                      narrative: "Saturn — the ringed wonder. Its spectacular rings are made of billions of ice and rock particles, ranging from tiny grains to mountain-sized boulders. Saturn is the least dense planet — it would float in water. Its moon Enceladus shoots geysers of water ice from a subsurface ocean that may harbor microbial life.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000008")!, contentBundleID: uranus,
                      narrative: "Uranus — the tilted giant. Its axis is tilted 98°, so it essentially rolls around the Sun on its side, causing 42-year-long seasons. This ice giant appears blue-green due to methane in its atmosphere. Its rings were only discovered in 1977, when they blocked a background star.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-000000000009")!, contentBundleID: neptune,
                      narrative: "Neptune — the windy giant. The most distant planet, with the strongest winds in the solar system — up to 2,100 km/h. Its largest moon Triton orbits backwards and is slowly spiraling inward; in about 3.6 billion years, Neptune's tidal forces will tear it apart into a new ring system.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000001-0000-0000-0000-00000000000A")!, contentBundleID: pluto,
                      narrative: "Pluto — the dwarf planet at the edge of the solar system. Once considered the ninth planet, Pluto was reclassified in 2006. NASA's New Horizons flyby in 2015 revealed a surprisingly complex world: towering water-ice mountains, a vast nitrogen glacier shaped like a heart, and a hazy atmosphere. Pluto is just one of thousands of objects in the distant Kuiper Belt.",
                      autoAdvanceSeconds: nil),
        ]
    )

    // MARK: - Earth's Dynamic Systems

    private static let earthDynamicSystems = Story(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        title: "Earth's Dynamic Systems",
        description: "Explore Earth from multiple perspectives — surface, elevation, lights at night, and real-time natural hazards.",
        systemImage: "globe",
        steps: [
            StoryStep(id: UUID(uuidString: "10000002-0000-0000-0000-000000000001")!, contentBundleID: earth,
                      narrative: "This is Earth as astronauts see it — the 'Blue Marble'. Oceans cover 71% of the surface. The thin blue haze at the horizon is our entire atmosphere — everything that sustains all life on Earth, compressed into a layer thinner, relative to the planet, than the skin of an apple.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000002-0000-0000-0000-000000000002")!, contentBundleID: topography,
                      narrative: "Beneath the oceans and land lies a dramatic landscape of mountains, plains, and deep trenches. Colors here represent elevation: deep blue for the ocean floor (down to −11 km in the Mariana Trench), green for lowlands, brown for highlands, and white for mountain peaks. The mid-ocean ridges — the longest mountain ranges on Earth — are entirely underwater.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000002-0000-0000-0000-000000000003")!, contentBundleID: cloudCover,
                      narrative: "Clouds cover about 67% of Earth at any given moment. They regulate temperature, distribute water, and reflect sunlight back to space. The bright bands near the equator are the Intertropical Convergence Zone — where trade winds meet and warm, moist air rises, creating persistent thunderstorms. The cloud-free subtropics are where most of the world's deserts exist.",
                      autoAdvanceSeconds: nil),
            StoryStep(id: UUID(uuidString: "10000002-0000-0000-0000-000000000004")!, contentBundleID: nightLights,
                      narrative: "At night, Earth's lights tell the story of human civilization. Bright clusters reveal dense cities; corridors of light trace highways and rivers. But some lights are natural: wildfires glowing across Africa, gas flares from oil fields in Siberia, and the shimmering aurora near the poles. Notice the stark contrast between the lights of South Korea and the darkness of North Korea.",
                      autoAdvanceSeconds: nil),
        ]
    )
}
