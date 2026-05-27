import AVFoundation
import CoreVideo
import Metal
import QuartzCore

/// Streams an MP4/H.264 dataset into the RenderEngine base texture in real time.
/// AVPlayer drives decoding; each draw call pulls the latest pixel buffer.
@MainActor
final class VideoPlaybackController {

    private let player = AVPlayer()
    private var output: AVPlayerItemVideoOutput?
    private var textureCache: CVMetalTextureCache?
    private let device: MTLDevice

    /// When true, the video restarts from 0 on reaching the end.
    var loopEnabled: Bool = true

    private var endObserver: NSObjectProtocol?

    init(device: MTLDevice) {
        self.device = device
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    /// Stops playback and removes the end-of-item observer. Call before discarding.
    func stop() {
        player.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    // MARK: - Pure time helpers (unit-tested)

    nonisolated static func timeForProgress(_ progress: Double, duration: CMTime) -> CMTime {
        let clamped = min(max(progress, 0.0), 1.0)
        return CMTime(seconds: CMTimeGetSeconds(duration) * clamped, preferredTimescale: 600)
    }

    nonisolated static func progressForTime(_ current: CMTime, duration: CMTime) -> Double {
        let d = CMTimeGetSeconds(duration)
        guard d > 0 else { return 0.0 }
        return CMTimeGetSeconds(current) / d
    }

    // MARK: - Lifecycle

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
        item.add(videoOutput)
        output = videoOutput
        player.replaceCurrentItem(with: item)

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.loopEnabled else { return }
                self.player.seek(to: .zero)
                self.player.play()
            }
        }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func setRate(_ rate: Float) { player.rate = rate }

    func seek(toProgress progress: Double) {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return }
        player.seek(to: Self.timeForProgress(progress, duration: duration))
    }

    var progress: Double {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return 0 }
        return Self.progressForTime(player.currentTime(), duration: duration)
    }

    /// Pulls the current video frame into `engine`'s base texture. Call once per draw.
    func copyCurrentFrame(to engine: RenderEngine) {
        guard let output, let textureCache else { return }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTexture
        )
        guard status == kCVReturnSuccess,
              let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture)
        else { return }
        engine.baseTexture = texture
    }
}
