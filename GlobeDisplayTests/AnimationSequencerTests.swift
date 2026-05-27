import XCTest
@testable import GlobeDisplay

final class AnimationSequencerTests: XCTestCase {

    // MARK: - step (pure, nonisolated)

    func test_step_loop_wrapsAtEnd() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .loop)
        XCTAssertEqual(r.next, 0)
        XCTAssertEqual(r.direction, 1)
        XCTAssertFalse(r.finished)
    }

    func test_step_loop_advancesInMiddle() {
        let r = AnimationSequencer.step(from: 2, count: 5, direction: 1, mode: .loop)
        XCTAssertEqual(r.next, 3)
        XCTAssertFalse(r.finished)
    }

    func test_step_once_stopsAtLastFrame() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .once)
        XCTAssertEqual(r.next, 4)
        XCTAssertTrue(r.finished)
    }

    func test_step_pingPong_reversesAtEnd() {
        let r = AnimationSequencer.step(from: 4, count: 5, direction: 1, mode: .pingPong)
        XCTAssertEqual(r.next, 3)
        XCTAssertEqual(r.direction, -1)
        XCTAssertFalse(r.finished)
    }

    func test_step_pingPong_reversesAtStart() {
        let r = AnimationSequencer.step(from: 0, count: 5, direction: -1, mode: .pingPong)
        XCTAssertEqual(r.next, 1)
        XCTAssertEqual(r.direction, 1)
    }

    // MARK: - seek / progress (MainActor instance)

    @MainActor
    func test_seek_clampsAndMapsToIndex() async {
        let seq = AnimationSequencer()
        seq.setFramesForTesting(count: 11)   // indices 0...10
        seq.seek(toProgress: 0.5)
        XCTAssertEqual(seq.currentFrameIndex, 5)
        seq.seek(toProgress: 2.0)            // clamps high
        XCTAssertEqual(seq.currentFrameIndex, 10)
        seq.seek(toProgress: -1.0)           // clamps low
        XCTAssertEqual(seq.currentFrameIndex, 0)
    }

    @MainActor
    func test_progress_roundTrips() async {
        let seq = AnimationSequencer()
        seq.setFramesForTesting(count: 11)
        seq.seek(toProgress: 0.5)
        XCTAssertEqual(seq.progress, 0.5, accuracy: 0.001)
    }
}
