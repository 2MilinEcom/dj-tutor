import XCTest
@testable import DJCore

final class CompanionTimingTests: XCTestCase {
    func testCountdownStartsOnUserPhraseAndLeavesTimeToPrepare() {
        var timing = CompanionTiming()
        timing.markPhrase(at: 10.1)
        timing.arm(at: 10.2)
        XCTAssertEqual(timing.start, 42)
        XCTAssertEqual(timing.elapsed(at: 41), -1)
        XCTAssertEqual(timing.elapsed(at: 42), 0)
        XCTAssertEqual(timing.beatInBar(at: 43), 2)
        timing.arm(at: 40)
        XCTAssertEqual(timing.start, 74) // Avoid a last-second prompt at 42.
    }
    func testNoPhraseMeansNoTimedLesson() {
        var timing = CompanionTiming()
        timing.arm(at: 100)
        XCTAssertNil(timing.start)
    }
    func testRejoinOrSuspensionRequiresAnotherPhraseAnchor() {
        var timing = CompanionTiming()
        timing.markPhrase(at: 100)
        timing.arm(at: 100)
        XCTAssertTrue(timing.observe(100.2))
        XCTAssertFalse(timing.observe(12))
        XCTAssertNil(timing.anchor)
        XCTAssertNil(timing.start)
        timing.markPhrase(at: 12)
        timing.arm(at: 12)
        XCTAssertFalse(timing.observe(30))
        XCTAssertNil(timing.start)
    }
    func testEchoDropOccursAtExactLessonBoundary() {
        let lesson = CompanionLesson.echo
        XCTAssertNil(lesson.step(at: -0.1))
        XCTAssertEqual(lesson.step(at: 0)?.index, 0)
        XCTAssertEqual(lesson.step(at: 27.9)?.index, 1)
        XCTAssertEqual(lesson.step(at: 28)?.index, 2)
        XCTAssertEqual(lesson.step(at: 31.9)?.index, 2)
        XCTAssertEqual(lesson.step(at: 32)?.index, 3)
        XCTAssertEqual(lesson.step(at: 32)?.remaining, 4)
        XCTAssertNil(lesson.step(at: 48))
    }
    func testStopPreservesAnchorButRemarkCancelsLesson() {
        var timing = CompanionTiming()
        timing.markPhrase(at: -2)
        XCTAssertEqual(timing.beatInBar(at: -2), 1)
        timing.arm(at: 0)
        timing.stop()
        XCTAssertNotNil(timing.anchor)
        timing.arm(at: 0)
        timing.markPhrase(at: 2)
        XCTAssertNil(timing.start)
        XCTAssertEqual(timing.anchor, 2)
    }
}
