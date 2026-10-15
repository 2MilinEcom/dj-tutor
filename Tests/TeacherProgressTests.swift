import XCTest
@testable import DJCore
final class TeacherProgressTests: XCTestCase {
    func testRestartClearsCompletionAndSavedStep() throws {
        let lesson = TeacherLesson.all[0]
        var progress = TeacherProgress()
        for _ in lesson.steps { progress.advance(lesson) }
        XCTAssertTrue(progress.completed.contains(lesson.id))
        progress = try JSONDecoder().decode(TeacherProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertTrue(progress.completed.contains(lesson.id))
        progress.restart(lesson)
        XCTAssertEqual(progress.index(for: lesson), 0)
        XCTAssertFalse(progress.completed.contains(lesson.id))
    }
    func testRestoredProgressCannotIndexPastLessonAndLessonsStayIndependent() {
        var progress = TeacherProgress(steps: ["blend": 999, "controls": -3])
        XCTAssertEqual(progress.index(for: TeacherLesson.all[0]), TeacherLesson.all[0].steps.count - 1)
        XCTAssertEqual(progress.index(for: TeacherLesson.all[1]), 0)
        progress.restart(TeacherLesson.all[0])
        progress.advance(TeacherLesson.all[1])
        XCTAssertEqual(progress.index(for: TeacherLesson.all[0]), 0)
        XCTAssertEqual(progress.index(for: TeacherLesson.all[1]), 1)
    }
}
