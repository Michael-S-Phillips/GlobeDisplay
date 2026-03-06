import CoreGraphics
import Foundation

struct ContentBundle: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let category: ContentCategory
    let contentType: ContentType
    let resolution: CodableSize
    let source: ContentSource
    let assets: ContentAssets
    let attribution: String
    let license: String
}

enum ContentCategory: String, Codable, CaseIterable, Sendable {
    case planets, earth, atmosphere, ocean, cryosphere
    case space, land, biosphere, humanImpact, education

    var displayName: String {
        switch self {
        case .planets:      "Solar System"
        case .earth:        "Earth"
        case .atmosphere:   "Atmosphere"
        case .ocean:        "Ocean"
        case .cryosphere:   "Ice & Snow"
        case .space:        "Deep Space"
        case .land:         "Land"
        case .biosphere:    "Life"
        case .humanImpact:  "Human Impact"
        case .education:    "Education"
        }
    }

    var systemImage: String {
        switch self {
        case .planets:      "globe.americas.fill"
        case .earth:        "globe"
        case .atmosphere:   "cloud.fill"
        case .ocean:        "water.waves"
        case .cryosphere:   "snowflake"
        case .space:        "sparkles"
        case .land:         "mountain.2.fill"
        case .biosphere:    "leaf.fill"
        case .humanImpact:  "person.3.fill"
        case .education:    "graduationcap.fill"
        }
    }
}

enum ContentType: String, Codable, Sendable {
    case staticImage
    case imageSequence
    case video
}

enum ContentSource: String, Codable, Sendable {
    case bundled, downloaded, userImported
}

struct ContentAssets: Codable, Sendable {
    var primaryImageName: String? = nil
    var sequenceDirectory: String? = nil
    var videoPath: String? = nil
    var frameCount: Int? = nil
    var framerate: Double? = nil
    /// Remote URL for downloading this content bundle as a ZIP archive.
    var downloadURL: URL? = nil

    init(primaryImageName: String? = nil) {
        self.primaryImageName = primaryImageName
    }
}

/// A Codable wrapper for CGSize, used to persist content resolution.
/// Avoids a retroactive conformance on CGSize that could conflict with
/// future SDK additions.
struct CodableSize: Codable, Sendable {
    var width: Double
    var height: Double

    var cgSize: CGSize { CGSize(width: width, height: height) }

    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}
