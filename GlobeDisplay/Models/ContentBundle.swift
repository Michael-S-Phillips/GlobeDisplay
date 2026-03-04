import CoreGraphics
import Foundation

struct ContentBundle: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let category: ContentCategory
    let contentType: ContentType
    let resolution: CGSize
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

// CGSize does not conform to Codable in the standard library.
// This retroactive conformance encodes as a two-element array [width, height].
extension CGSize: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(Double.self)
        let height = try container.decode(Double.self)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(Double(width))
        try container.encode(Double(height))
    }
}
