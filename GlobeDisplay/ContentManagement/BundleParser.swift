import Foundation

/// Parses a NOAA SOS-format directory into a `ContentBundle`.
///
/// An SOS bundle directory contains:
/// - Numbered image files (`0001.png`, `0002.png`, …) → `.imageSequence`
/// - A single image file (`.jpg` or `.png`) → `.staticImage`
/// - A single `.mp4` video file → `.video`
/// - Optional metadata: a `.sos` file (key=value pairs) or a `label.json` file
@MainActor
enum BundleParser {

    // MARK: - Errors

    enum ParseError: Error, LocalizedError {
        case notADirectory(URL)
        case noRecognisedContent(URL)
        case metadataDecodeFailed(URL, underlyingError: Error)

        var errorDescription: String? {
            switch self {
            case .notADirectory(let url):
                "Path is not a directory: \(url.path)"
            case .noRecognisedContent(let url):
                "No recognised image, sequence, or video content in: \(url.path)"
            case .metadataDecodeFailed(let url, let err):
                "Failed to decode metadata at \(url.path): \(err.localizedDescription)"
            }
        }
    }

    // MARK: - Public API

    /// Parses the directory at `directory` and returns a `ContentBundle`.
    ///
    /// - Parameter directory: URL of the SOS bundle directory.
    /// - Returns: A fully populated `ContentBundle` with `.userImported` source.
    /// - Throws: `ParseError` if the directory is invalid or contains no recognised content.
    static func parse(directory: URL) throws -> ContentBundle {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw ParseError.notADirectory(directory)
        }

        let dirContents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        // Detect content type from file listing
        let (contentType, assets) = try detectContent(in: dirContents, directoryURL: directory)

        // Read metadata from .sos or label.json, falling back to directory name
        let metadata = readMetadata(from: dirContents, directoryURL: directory)

        let title = metadata.name ?? directoryName(from: directory)
        let attribution = metadata.credit ?? ""
        let description = metadata.description ?? ""
        let category = resolveCategory(
            sosCategory: metadata.category,
            title: title
        )

        return ContentBundle(
            id: UUID(),
            title: title,
            description: description,
            category: category,
            contentType: contentType,
            resolution: CodableSize(width: 2048, height: 1024),
            source: .userImported,
            assets: assets,
            attribution: attribution,
            license: ""
        )
    }

    // MARK: - Content Detection

    private static func detectContent(
        in files: [URL],
        directoryURL: URL
    ) throws -> (ContentType, ContentAssets) {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]

        // Check for .mp4 video
        if let videoFile = files.first(where: { $0.pathExtension.lowercased() == "mp4" }) {
            var assets = ContentAssets()
            assets.videoPath = videoFile.lastPathComponent
            return (.video, assets)
        }

        // Gather all image files
        let imageFiles = files.filter {
            imageExtensions.contains($0.pathExtension.lowercased())
        }

        if imageFiles.isEmpty {
            throw ParseError.noRecognisedContent(directoryURL)
        }

        // Detect numbered sequence: files whose name (sans extension) consists entirely of digits
        let sequenceFiles = imageFiles
            .filter { Int($0.deletingPathExtension().lastPathComponent) != nil }
            .sorted {
                let a = Int($0.deletingPathExtension().lastPathComponent) ?? 0
                let b = Int($1.deletingPathExtension().lastPathComponent) ?? 0
                return a < b
            }

        if sequenceFiles.count > 1 {
            var assets = ContentAssets()
            assets.sequenceDirectory = directoryURL.lastPathComponent
            assets.frameCount = sequenceFiles.count
            assets.framerate = 15.0
            return (.imageSequence, assets)
        }

        // Single image (could be the only numbered file or any non-numbered image)
        let singleFile = imageFiles.first!
        var assets = ContentAssets()
        assets.primaryImageName = singleFile.deletingPathExtension().lastPathComponent
        return (.staticImage, assets)
    }

    // MARK: - Metadata Parsing

    private struct BundleMetadata {
        var name: String?
        var credit: String?
        var category: String?
        var description: String?
    }

    private static func readMetadata(from files: [URL], directoryURL: URL) -> BundleMetadata {
        // Prefer .sos file
        if let sosFile = files.first(where: { $0.pathExtension.lowercased() == "sos" }) {
            return parseSosFile(sosFile)
        }

        // Fall back to label.json
        if let jsonFile = files.first(where: { $0.lastPathComponent.lowercased() == "label.json" }) {
            return parseJsonFile(jsonFile)
        }

        return BundleMetadata()
    }

    /// Parses a plain-text `.sos` metadata file with `key=value` lines.
    private static func parseSosFile(_ url: URL) -> BundleMetadata {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return BundleMetadata()
        }

        var metadata = BundleMetadata()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.contains("=") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "name":        metadata.name = value
            case "credit":      metadata.credit = value
            case "category":    metadata.category = value
            case "description": metadata.description = value
            default:            break
            }
        }
        return metadata
    }

    /// Parses a `label.json` metadata file: `{"name":"…","credit":"…","category":"…"}`.
    private static func parseJsonFile(_ url: URL) -> BundleMetadata {
        guard let data = try? Data(contentsOf: url) else { return BundleMetadata() }

        struct LabelJSON: Decodable {
            var name: String?
            var credit: String?
            var category: String?
            var description: String?
        }

        guard let decoded = try? JSONDecoder().decode(LabelJSON.self, from: data) else {
            return BundleMetadata()
        }

        return BundleMetadata(
            name: decoded.name,
            credit: decoded.credit,
            category: decoded.category,
            description: decoded.description
        )
    }

    // MARK: - Category Resolution

    /// Maps a SOS category string (or the bundle title) to a `ContentCategory`.
    private static func resolveCategory(sosCategory: String?, title: String) -> ContentCategory {
        // First, try the explicit category from metadata
        if let raw = sosCategory?.lowercased().trimmingCharacters(in: .whitespaces) {
            switch raw {
            case "atmosphere":  return .atmosphere
            case "ocean":       return .ocean
            case "cryosphere":  return .cryosphere
            case "land":        return .land
            case "biosphere":   return .biosphere
            case "planets":     return .planets
            case "space":       return .space
            case "humanimpact", "human_impact": return .humanImpact
            case "education":   return .education
            default:            break
            }
        }

        // Infer from planet names in the title
        let planetNames = ["mercury", "venus", "mars", "jupiter", "saturn",
                           "uranus", "neptune", "pluto", "moon", "lunar"]
        let lowerTitle = title.lowercased()
        if planetNames.contains(where: { lowerTitle.contains($0) }) {
            return .planets
        }

        return .earth
    }

    // MARK: - Helpers

    private static func directoryName(from url: URL) -> String {
        url.lastPathComponent
    }
}
