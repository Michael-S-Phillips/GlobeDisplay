import CoreGraphics
import Foundation

struct ContentBundle: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
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
