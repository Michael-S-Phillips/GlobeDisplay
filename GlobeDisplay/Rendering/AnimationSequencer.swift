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

/// How an image sequence advances when it reaches an end.
enum PlaybackMode: String, CaseIterable, Sendable {
    case loop      // wrap to the start
    case once      // stop at the final frame
    case pingPong  // bounce between ends
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

    /// What happens when playback reaches an end. Default loops (legacy behavior).
    var playbackMode: PlaybackMode = .loop

    /// True while the internal timer is running.
    var isPlaying: Bool { animationTask != nil }

    /// Index of the frame that will be pushed on the next tick.
    private(set) var currentFrameIndex: Int = 0

    /// Total number of frames loaded, 0 until load(from:) completes.
    private(set) var frameCount: Int = 0

    // MARK: - Private state

    private var frames: [CGImage] = []

    /// Playback direction: +1 forward, -1 reverse. Only changes in .pingPong mode.
    private var direction: Int = 1

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

                let r = AnimationSequencer.step(
                    from: self.currentFrameIndex, count: self.frameCount,
                    direction: self.direction, mode: self.playbackMode
                )
                self.currentFrameIndex = r.next
                self.direction = r.direction
                if r.finished { self.pause(); break }

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

    // MARK: - Frame stepping & seeking

    /// Computes the next frame index given the current position and playback mode.
    /// Pure and nonisolated so it can be unit-tested without a render engine.
    nonisolated static func step(
        from index: Int, count: Int, direction: Int, mode: PlaybackMode
    ) -> (next: Int, direction: Int, finished: Bool) {
        guard count > 1 else { return (index, direction, mode == .once) }
        switch mode {
        case .loop:
            return ((index + 1) % count, direction, false)
        case .once:
            return index + 1 >= count ? (index, direction, true) : (index + 1, direction, false)
        case .pingPong:
            let tentative = index + direction
            if tentative >= count { return (count - 2, -1, false) }
            if tentative < 0 { return (1, 1, false) }
            return (tentative, direction, false)
        }
    }

    /// Moves the playhead to a fractional position (0...1). Valid while playing or paused.
    func seek(toProgress progress: Double) {
        guard frameCount > 1 else { currentFrameIndex = 0; return }
        let clamped = min(max(progress, 0.0), 1.0)
        currentFrameIndex = Int((Double(frameCount - 1) * clamped).rounded())
    }

    /// Current playhead position as a fraction (0...1).
    var progress: Double {
        frameCount > 1 ? Double(currentFrameIndex) / Double(frameCount - 1) : 0.0
    }

    #if DEBUG
    /// Test seam: populate `frameCount` without decoding real images.
    func setFramesForTesting(count: Int) {
        frames = Array(repeating: AnimationSequencer.blankFrame(), count: count)
        frameCount = count
        currentFrameIndex = 0
    }

    nonisolated private static func blankFrame() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
    #endif
}
