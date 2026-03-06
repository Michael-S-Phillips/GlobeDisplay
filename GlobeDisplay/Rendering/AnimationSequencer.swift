import CoreGraphics
import ImageIO
import Foundation

enum AnimationSequencerError: Error, LocalizedError {
    case emptyDirectory
    case frameLoadFailed(URL)

    var errorDescription: String? {
        switch self {
        case .emptyDirectory:
            return "No .png or .jpg files found in the sequence directory."
        case .frameLoadFailed(let url):
            return "Failed to decode image frame: \(url.lastPathComponent)"
        }
    }
}

/// Drives image-sequence animation by pushing CGImage frames to RenderEngine on a timer.
///
/// Load a directory of numbered frames (e.g. 0001.png, 0002.png, …), then call
/// `play(engine:)` to start the render loop and `pause()` / `stop()` to control it.
@MainActor
final class AnimationSequencer {

    // MARK: - Public state

    /// Frames per second for playback. Change before calling play(engine:).
    var framerate: Double = 15.0

    /// True while the internal timer is running.
    var isPlaying: Bool { animationTask != nil }

    /// Index of the frame that will be pushed on the next tick.
    private(set) var currentFrameIndex: Int = 0

    /// Total number of frames loaded, 0 until load(from:) completes.
    private(set) var frameCount: Int = 0

    // MARK: - Private state

    private var frames: [CGImage] = []

    /// A long-lived Task that drives the frame loop.
    private var animationTask: Task<Void, Never>?

    // MARK: - Loading

    /// Loads all .png and .jpg image files from `directory`, sorted alphabetically.
    ///
    /// Images are decoded into CGImages in-memory so the render loop can push them
    /// synchronously on each tick without blocking on I/O.
    func load(from directory: URL) async throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let imageURLs = contents
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "png" || ext == "jpg" || ext == "jpeg"
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !imageURLs.isEmpty else {
            throw AnimationSequencerError.emptyDirectory
        }

        var loaded: [CGImage] = []
        loaded.reserveCapacity(imageURLs.count)

        for url in imageURLs {
            guard
                let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw AnimationSequencerError.frameLoadFailed(url)
            }
            loaded.append(image)
        }

        frames = loaded
        frameCount = loaded.count
        currentFrameIndex = 0
    }

    // MARK: - Playback control

    /// Starts the animation loop, pushing frames to `engine` at `framerate` fps.
    ///
    /// Calling `play` while already playing first stops the existing loop so that
    /// framerate or engine changes take effect immediately.
    func play(engine: RenderEngine) {
        guard frameCount > 0 else { return }

        // Cancel any existing loop before starting a new one.
        animationTask?.cancel()

        let frameDuration: Duration = .nanoseconds(Int(1_000_000_000.0 / max(framerate, 1.0)))

        animationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }

                let frame = self.frames[self.currentFrameIndex]
                do {
                    try engine.updateAnimationFrame(frame)
                } catch {
                    // Non-fatal: skip the frame and continue.
                }

                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frameCount

                do {
                    try await Task.sleep(for: frameDuration)
                } catch {
                    // Task was cancelled — exit cleanly.
                    break
                }
            }
        }
    }

    /// Stops the animation loop without resetting the frame position.
    func pause() {
        animationTask?.cancel()
        animationTask = nil
    }

    /// Stops the animation loop and resets the frame position to 0.
    func stop() {
        pause()
        currentFrameIndex = 0
    }
}
