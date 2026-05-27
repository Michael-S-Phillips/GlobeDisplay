import XCTest
import CoreMedia
@testable import GlobeDisplay

final class VideoPlaybackControllerTests: XCTestCase {

    func test_timeForProgress_mapsToFractionOfDuration() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let t = VideoPlaybackController.timeForProgress(0.5, duration: duration)
        XCTAssertEqual(CMTimeGetSeconds(t), 5.0, accuracy: 0.001)
    }

    func test_timeForProgress_clampsAboveOne() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let t = VideoPlaybackController.timeForProgress(2.0, duration: duration)
        XCTAssertEqual(CMTimeGetSeconds(t), 10.0, accuracy: 0.001)
    }

    func test_progressForTime_isFraction() {
        let current = CMTime(seconds: 3, preferredTimescale: 600)
        let duration = CMTime(seconds: 12, preferredTimescale: 600)
        XCTAssertEqual(VideoPlaybackController.progressForTime(current, duration: duration), 0.25, accuracy: 0.001)
    }

    func test_progressForTime_zeroDurationIsZero() {
        let zero = CMTime(seconds: 0, preferredTimescale: 600)
        XCTAssertEqual(VideoPlaybackController.progressForTime(zero, duration: zero), 0.0, accuracy: 0.001)
    }
}
