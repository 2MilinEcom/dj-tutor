import XCTest
@testable import DJCore

final class TeacherDemoTests: XCTestCase {
    func testFirstMoveActuallyTravelsLeftAndPlayStartsPaused() {
        let demo = TeacherDemo.lesson("blend", step: 0)
        let drag = demo.frames[1]
        XCTAssertEqual(drag.action, .drag)
        XCTAssertEqual(drag.pointerLabel, "DRAG ← LEFT")
        XCTAssertGreaterThan(drag.start.crossfader, drag.pose.crossfader)
        XCTAssertEqual(demo.pose(at: 4).crossfader, 0.5)
        XCTAssertEqual(demo.pose(at: 7.9).crossfader, 0)
        XCTAssertFalse(demo.pose(at: 8).leftPlaying)
        XCTAssertTrue(demo.pose(at: 11.9).leftPlaying)
        XCTAssertEqual(demo.frames[2].pointerLabel, "TAP ▶ PLAY")
    }
    func testEveryActionHasADistinctVisualChangeAndNoPlayPauseGuessing() {
        for lesson in TeacherLesson.all {
            for step in lesson.steps.indices {
                let demo = TeacherDemo.lesson(lesson.id, step: step)
                for frame in demo.frames {
                    switch frame.action {
                    case .play:
                        let left = frame.focus == "leftPlay"
                        XCTAssertFalse(left ? frame.start.leftPlaying : frame.start.rightPlaying)
                        XCTAssertTrue(left ? frame.pose.leftPlaying : frame.pose.rightPlaying)
                    case .pause:
                        let left = frame.focus == "leftPlay"
                        XCTAssertTrue(left ? frame.start.leftPlaying : frame.start.rightPlaying)
                        XCTAssertFalse(left ? frame.pose.leftPlaying : frame.pose.rightPlaying)
                    case .drag: XCTAssertNotEqual(frame.start.crossfader, frame.pose.crossfader)
                    case .cueSet: XCTAssertFalse(frame.start.cue); XCTAssertTrue(frame.pose.cue)
                    case .cueJump: XCTAssertGreaterThan(frame.start.playhead, frame.pose.playhead)
                    case .sync: XCTAssertFalse(frame.start.sync); XCTAssertTrue(frame.pose.sync)
                    case .low:
                        XCTAssertTrue(frame.start.leftLow != frame.pose.leftLow || frame.start.rightLow != frame.pose.rightLow)
                    case .openEQ: XCTAssertFalse(frame.start.mixerOpen); XCTAssertTrue(frame.pose.mixerOpen)
                    case .openFX: XCTAssertFalse(frame.start.fxOpen); XCTAssertTrue(frame.pose.fxOpen)
                    case .echoOn: XCTAssertLessThan(frame.start.echo, frame.pose.echo)
                    case .echoOff: XCTAssertGreaterThan(frame.start.echo, frame.pose.echo)
                    default: break
                    }
                }
            }
        }
    }
    func testEveryLessonStepHasACompleteBoundedWalkthrough() {
        let controls = Set(["crossfader", "leftPlay", "rightPlay", "cue", "sync", "beats", "eq", "leftLow", "rightLow", "echo"])
        for lesson in TeacherLesson.all {
            for step in lesson.steps.indices {
                let demo = TeacherDemo.lesson(lesson.id, step: step)
                XCTAssertGreaterThanOrEqual(demo.frames.count, 3, "\(lesson.id) / \(step)")
                XCTAssertEqual(demo.frameIndex(at: -10), 0)
                XCTAssertEqual(demo.frameIndex(at: demo.duration + 100), demo.frames.count - 1)
                for frame in demo.frames {
                    XCTAssertFalse(frame.caption.isEmpty)
                    XCTAssertTrue(controls.contains(frame.focus))
                }
                for tick in 0...Int(demo.duration * 10) {
                    let pose = demo.pose(at: Double(tick) / 10)
                    for value in [pose.crossfader, pose.leftLow, pose.rightLow, pose.echo] {
                        XCTAssertTrue((0...1).contains(value))
                    }
                }
            }
        }
    }
    func testHandoffAndBassSwapFinishOnTheIncomingDeck() {
        let handoff = TeacherDemo.lesson("blend", step: 4)
        XCTAssertEqual(handoff.pose(at: 0).crossfader, 0.5)
        let moving = handoff.pose(at: 5).crossfader
        XCTAssertGreaterThan(moving, 0.5)
        XCTAssertLessThan(moving, 1)
        XCTAssertEqual(handoff.pose(at: handoff.duration).crossfader, 1)
        let bass = TeacherDemo.lesson("eq", step: 2)
        let landing = bass.pose(at: bass.duration)
        XCTAssertEqual(landing.crossfader, 1)
        XCTAssertEqual(landing.rightLow, 1)
        XCTAssertLessThan(landing.leftLow, landing.rightLow)
        let exit = TeacherDemo.lesson("echo", step: 2)
        XCTAssertEqual(exit.pose(at: exit.duration).echo, 0)
    }
}
