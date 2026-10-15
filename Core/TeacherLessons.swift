import Foundation

struct TeacherLesson: Identifiable {
    struct Step {
        let title: String
        let action: String
        let why: String
        let check: String
        let find: String
        let fix: String
    }
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let steps: [Step]
    static let all: [TeacherLesson] = [
        TeacherLesson(id: "blend", title: "My first blend", subtitle: "Two tracks → one smooth handoff", symbol: "slider.horizontal.3", steps: [
            Step(title: "Hear one deck", action: "In djay, move the crossfader fully left and press Play on the left deck. Leave the right deck paused.", why: "You start with one clear sound, so you can hear what each move changes.", check: "Only the left track should be audible.", find: "Look for the horizontal slider between the decks. Left favors the left deck; right favors the right deck.", fix: "Check that the left deck is playing and its channel volume is up. Keep listening volume comfortable."),
            Step(title: "Prepare the second track", action: "On the paused right deck, choose the start of the section you want to bring in. Tap Cue Set there, then Sync on that deck.", why: "The cue gives you a repeatable entry. Sync helps match tempo; its beat alignment depends on djay’s Sync mode and beatgrids.", check: "The right deck is ready but still silent. You do not need to type any BPM into this coach.", find: "Cue Set and Cue Jump are near each deck’s playback controls. If hidden, open its Tools panel or change the deck view.", fix: "If Sync makes the tempo feel wrong, stop and compare the BPM displays. Half-time/double-time readings can be misleading; do not force a large tempo change."),
            Step(title: "Listen for a new section", action: "Count along: 1, 2, 3, 4. Listen for a new drum pattern, a break, or a melody entering. Start the right deck on that new section’s first beat.", why: "Musical phrases make an entry feel deliberate. Sync does not choose the musical phrase for you.", check: "The right deck is playing behind the left while the crossfader stays left.", find: "Use the right deck’s Play button. Cue Jump takes you back if you want to retry.", fix: "Keep the right side silent, pause it, return to your cue and try the next section. Missing an entry is normal."),
            Step(title: "Bring it in gently", action: "Slowly move the crossfader a little toward the center. Listen before moving further.", why: "A small blend lets you judge whether the rhythms and vocals work together.", check: "You can hear both tracks without a sudden jump in loudness.", find: "Use the horizontal crossfader. This is different from the vertical channel volume faders.", fix: "If vocals collide or the sound gets crowded, move left again and wait for a less busy section."),
            Step(title: "Give the new track the room", action: "If the blend sounds good, move the crossfader gradually to the right. Leave only the right deck audible.", why: "A clear handoff lets the listener follow the new groove instead of hearing two tracks compete.", check: "The right track carries the mix. The left is silent even if its playhead is still moving.", find: "Move the crossfader to the far right. Leave the master volume steady.", fix: "If the low end is muddy, shorten the overlap. You can learn a bass swap in the EQ lesson."),
            Step(title: "Reset and listen", action: "Pause the silent left deck. Listen to the new track, then repeat the exercise with the decks reversed.", why: "Resetting the silent deck gives you room to prepare your next transition.", check: "You completed a handoff. Judge it by what you heard; the coach cannot hear or grade your mix.", find: "Each deck has its own Play/Pause control.", fix: "If it felt rushed, repeat using a longer instrumental section and a slower fader movement.")]),
        TeacherLesson(id: "controls", title: "Know the controls", subtitle: "Understand what each move does", symbol: "dial.low", steps: [
            Step(title: "Decks and playback", action: "Find Play/Pause on each deck. Play one track, pause it, then restart it.", why: "Each deck is a separate player. Loading a song does not mean it is audible.", check: "You can tell which deck is playing.", find: "The two deck areas sit left and right. Their layouts depend on the view chosen in djay’s Dashboard.", fix: "If playback is moving but silent, check the channel volume and crossfader position."),
            Step(title: "Tempo and Sync", action: "Find the BPM display and tempo slider. Notice them, then use Sync on the incoming deck while the other deck is audible.", why: "BPM is speed. Beat alignment and musical phrase alignment are different skills.", check: "You understand why two songs at the same BPM can still enter at the wrong place.", find: "For Sync modes, look in djay Settings → General → Sync Mode. Names can vary by version.", fix: "BPM-only mode matches speed without aligning the beatgrid. Inspect the grid if the drums still clash."),
            Step(title: "Cue versus Play", action: "Pause a deck, set a cue, move away, then use Cue Jump to return.", why: "A cue is a saved starting location, not a mixing effect.", check: "You can return to your chosen entry.", find: "Look near Play for Cue Set and Cue Jump, or open the deck’s cue tools.", fix: "Use a paused deck for this exercise so jumping does not interrupt the audible track.")]),
        TeacherLesson(id: "phrases", title: "Find the right timing", subtitle: "Hear beats, bars and phrases", symbol: "metronome", steps: [
            Step(title: "Count a bar", action: "Listen to one track. Say 1, 2, 3, 4 with the pulse, then repeat.", why: "In common 4/4 dance music, four beats make a bar. A steady count is more useful than watching a timer.", check: "Your count stays steady for several bars.", find: "Listen to the rhythm rather than trying to count every vocal syllable.", fix: "Try a clear drum section. If the count feels twice as fast or slow, try half-time or double-time."),
            Step(title: "Hear a phrase", action: "Count eight bars and listen for a musical change. Repeat without changing either deck.", why: "Many arrangements change over 8, 16 or 32 bars, but not every track follows that pattern.", check: "You can point out a section change by ear.", find: "A new bass pattern, vocal entrance or break can signal a new section.", fix: "Do not assume every eighth bar is a phrase. Let the arrangement confirm your count."),
            Step(title: "Choose the entry", action: "Prepare a cue on the other deck. Try starting it at the next audible section change while it remains silent, then blend a little.", why: "You are matching the arrangement as well as the beats.", check: "The new track’s entrance feels intentional.", find: "Use Cue Jump to retry the entry and the crossfader to reveal it.", fix: "If two vocals overlap, move the entry to an instrumental section or use a shorter handoff.")]),
        TeacherLesson(id: "eq", title: "Clean up the bass", subtitle: "Less mud, more space", symbol: "waveform", steps: [
            Step(title: "Find low EQ", action: "Open the mixer/EQ controls in djay. Find Low, Mid and High for each deck.", why: "EQ adjusts frequency ranges. Low mostly affects bass and the weight of the kick.", check: "You can distinguish the EQ controls from channel and master volume.", find: "Use djay’s Dashboard to choose a view with mixer controls if your current view hides them.", fix: "Return EQ controls to their center position when you are unsure."),
            Step(title: "Leave space for A", action: "With the incoming deck still silent, lower its Low EQ. Start it in time and gently bring it into the mix.", why: "Reducing the incoming bass leaves space for the outgoing low end.", check: "The overlap feels clearer than playing both bass lines at full strength.", find: "Adjust Low on the incoming deck, not the master output.", fix: "If you lose too much body, back off the cut and reduce the length of the overlap."),
            Step(title: "Swap the low end", action: "At a section change, lower the outgoing deck’s Low while returning the incoming Low toward center. Then finish the crossfade.", why: "A bass swap transfers the low-end focus between tracks.", check: "The new track has weight without a big bass pileup.", find: "Use both decks’ Low EQ controls and listen in small steps.", fix: "If it becomes thin, both Low controls may be down. Restore the incoming one gradually.")]),
        TeacherLesson(id: "echo", title: "Make an echo exit", subtitle: "A short, deliberate transition", symbol: "sparkles", steps: [
            Step(title: "Prepare a clean landing", action: "Cue the incoming deck at the section you want to hear next. Keep it silent while the outgoing track plays.", why: "A good exit needs a prepared entry. Effects cannot fix an unclear landing.", check: "You know where the incoming track will begin.", find: "Use the incoming deck’s cue controls. No exact timestamps are assumed by this coach.", fix: "If you are unsure, practice a plain crossfade first."),
            Step(title: "Use a little echo", action: "Open the outgoing deck’s FX controls and select Echo if it is available. Try a low effect amount before the handoff.", why: "Echo repeats a short piece of the outgoing sound. Too much can obscure the new track.", check: "The echo adds a tail without taking over.", find: "Look in the deck’s Tools/FX panel. Availability depends on your djay version and plan.", fix: "If Echo is locked, use a plain fade instead. This lesson does not require buying an effect."),
            Step(title: "Exit, then land", action: "Near the outgoing section’s end, apply a brief echo, start the incoming track on the next one, and move the crossfader to it. Release the effect after the tail.", why: "A short tail can connect a sharp energy change without a long vocal overlap.", check: "The incoming track lands clearly. Listen rather than relying on an automatic countdown.", find: "Use FX on the outgoing deck, Play on the incoming deck, then the crossfader.", fix: "If the tail is messy, reduce the echo amount or shorten the overlap and try again.")])
    ]
}

struct TeacherProgress: Codable {
    var steps: [String: Int] = [:]
    var completed: Set<String> = []
    func index(for lesson: TeacherLesson) -> Int { min(max(0, steps[lesson.id] ?? 0), lesson.steps.count - 1) }
    mutating func advance(_ lesson: TeacherLesson) {
        let index = index(for: lesson)
        if index < lesson.steps.count - 1 { steps[lesson.id] = index + 1 }
        else { completed.insert(lesson.id) }
    }
    mutating func back(_ lesson: TeacherLesson) { steps[lesson.id] = max(0, index(for: lesson) - 1); completed.remove(lesson.id) }
    mutating func restart(_ lesson: TeacherLesson) { steps[lesson.id] = 0; completed.remove(lesson.id) }
}
