import Foundation

/// Shared beat time is not song position. The learner supplies a musical phrase anchor.
struct CompanionTiming {
    private(set) var anchor: Double?
    private(set) var start: Double?
    private(set) var lastBeat: Double?
    mutating func markPhrase(at beat: Double) { anchor = beat.rounded(); start = nil; lastBeat = beat }
    mutating func arm(at beat: Double) {
        guard let anchor else { return }
        // Always leave at least four beats to prepare, then start on an anchored 8-bar phrase.
        start = anchor + ceil((beat + 4 - anchor) / 32) * 32
        lastBeat = beat
    }
    mutating func stop() { start = nil }
    mutating func reset() { anchor = nil; start = nil; lastBeat = nil }
    /// Peer rejoining or a changed timeline invalidates song alignment; never silently resume.
    mutating func observe(_ beat: Double) -> Bool {
        defer { lastBeat = beat }
        if let lastBeat, beat < lastBeat - 0.5 || beat - lastBeat > 4 { reset(); return false }
        return true
    }
    func elapsed(at beat: Double) -> Double? { start.map { beat - $0 } }
    func beatInBar(at beat: Double) -> Int {
        let offset = Int(floor(beat - (anchor ?? 0)))
        return ((offset % 4) + 4) % 4 + 1
    }
}

enum CompanionLesson: String, CaseIterable, Identifiable {
    case echo = "Echo out → drop"
    case blend = "Bass swap blend"
    var id: String { rawValue }
    struct Step {
        let beats: Double
        let title: String
        let instruction: String
    }
    var preparation: String {
        switch self {
        case .echo: return "In djay, cue deck B at the start of the section you want to drop. Keep its channel fader down. Listen to A and mark a phrase start below."
        case .blend: return "In djay, match the decks with Sync. Cue B at a phrase start, turn B’s low EQ down, and keep its channel fader down. Mark A’s phrase start below."
        }
    }
    var steps: [Step] {
        switch self {
        case .echo: return [
            Step(beats: 16, title: "Keep the groove", instruction: "Leave A playing. Check B’s cue and keep B silent. Count four bars."),
            Step(beats: 12, title: "Build the handoff", instruction: "Gently raise A’s high-pass filter. Keep the vocal clear; do not force a long overlap."),
            Step(beats: 4, title: "Echo the last bar", instruction: "Apply a short beat-synced echo to A. Prepare to launch B on the next one."),
            Step(beats: 4, title: "Drop B now", instruction: "Press Play on B, raise its channel fader, and lower A. Release A’s echo after its tail."),
            Step(beats: 12, title: "Let B land", instruction: "Keep B steady. Reset A’s filter and echo for the next mix.")]
        case .blend: return [
            Step(beats: 16, title: "Launch B on the one", instruction: "Start B from its cue. Slowly raise B’s channel fader with its low EQ down."),
            Step(beats: 16, title: "Make space", instruction: "Listen for competing vocals. Hold the blend only if the phrases work together."),
            Step(beats: 16, title: "Swap the bass", instruction: "Gradually lower A’s low EQ while bringing B’s low EQ back to center."),
            Step(beats: 16, title: "Finish the handoff", instruction: "Lower A’s channel fader. Let B play and reset A’s EQ.")]
        }
    }
    func step(at elapsed: Double) -> (index: Int, remaining: Double)? {
        guard elapsed >= 0 else { return nil }
        var end = 0.0
        for (index, step) in steps.enumerated() {
            end += step.beats
            if elapsed < end { return (index, end - elapsed) }
        }
        return nil
    }
}
