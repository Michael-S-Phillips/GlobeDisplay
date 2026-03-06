import AVFoundation
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

enum VideoFrameExtractorError: Error, LocalizedError {
    case unreadableAsset
    case zeroDuration
    case noFramesExtracted

    var errorDescription: String? {
        switch self {
        case .unreadableAsset:    "Video asset is not readable."
        case .zeroDuration:       "Video has zero duration."
        case .noFramesExtracted:  "No frames could be extracted from the video."
        }
    }
}

/// Extracts a representative set of frames from a video file and saves them
/// as numbered JPEGs for use with `AnimationSequencer`.
///
/// Designed to run off the main actor (all methods are nonisolated).
nonisolated enum VideoFrameExtractor {

    /// Extracts frames from `videoURL` and writes them as `0001.jpg`, `0002.jpg`, …
    /// into `outputDirectory`.
    ///
    /// - Parameters:
    ///   - videoURL: Path to the local video file (.mov, .mp4, etc.).
    ///   - outputDirectory: Directory to write JPEG frames into (created if needed).
    ///   - targetFPS: How many frames per second of source video to sample.
    ///   - maxFrames: Hard cap on total frames to keep memory bounded.
    /// - Returns: The number of frames written.
    static func extractFrames(
        from videoURL: URL,
        to outputDirectory: URL,
        targetFPS: Double = 5.0,
        maxFrames: Int = 120
    ) async throws -> Int {

        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else { throw VideoFrameExtractorError.zeroDuration }

        // Clamp frame count so we don't OOM on long videos.
        let rawCount = Int((durationSeconds * targetFPS).rounded())
        let frameCount = max(1, min(rawCount, maxFrames))

        // Evenly-spaced sample times across the video.
        let interval = durationSeconds / Double(frameCount)
        let times: [CMTime] = (0..<frameCount).map { i in
            CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // Allow a small tolerance so we don't get stuck waiting for exact keyframes.
        let tolerance = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter  = tolerance

        try FileManager.default.createDirectory(at: outputDirectory,
                                                withIntermediateDirectories: true)

        var written = 0
        for (i, time) in times.enumerated() {
            guard let (cgImage, _) = try? await generator.image(at: time) else {
                continue   // skip unreadable frames; don't abort the whole sequence
            }

            let frameURL = outputDirectory
                .appendingPathComponent(String(format: "%04d.jpg", i + 1))
            writeJPEG(cgImage, to: frameURL)
            written += 1
        }

        guard written > 0 else { throw VideoFrameExtractorError.noFramesExtracted }
        return written
    }

    // MARK: - Private helpers

    private static func writeJPEG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else { return }

        CGImageDestinationAddImage(
            dest, image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        CGImageDestinationFinalize(dest)
    }
}
