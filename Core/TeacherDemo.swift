import Foundation

// Teaching illustrations only: these values never describe or control a live deck.
struct DemoPose {
    var crossfader: Double = 0
    var leftPlaying = true
    var rightPlaying = false
    var leftLow: Double = 1
    var rightLow: Double = 1
    var echo: Double = 0
    var cue = false
    var sync = false
    var playhead: Double = 0
    var fxOpen = false
    var mixerOpen = true
}
enum DemoAction {
    case observe, play, pause, drag, cueSet, cueJump, sync, low, bassSwap, openEQ, openFX, echoOn, echoOff, count
}
struct DemoFrame {
    let caption: String
    let focus: String
    var pose: DemoPose
    var before: DemoPose? = nil
    var action: DemoAction = .observe
    var start: DemoPose { before ?? pose }
    var sectionLabel: String {
        switch focus {
        case "leftPlay", "leftLow", "echo": return "LEFT DECK / A"
        case "rightPlay", "rightLow", "cue", "sync": return "RIGHT DECK / B"
        case "eq": return "MIXER / EQ"
        case "beats": return "LISTEN TO THE MUSIC"
        default: return "CENTER MIXER / CROSSFADER"
        }
    }
    var pointerLabel: String {
        switch action {
        case .play: return "TAP ▶ PLAY"
        case .pause: return "TAP Ⅱ PAUSE"
        case .drag: return pose.crossfader < start.crossfader ? "DRAG ← LEFT" : "DRAG RIGHT →"
        case .cueSet: return "TAP CUE SET"
        case .cueJump: return "TAP CUE JUMP"
        case .sync: return "TAP SYNC"
        case .low: return pose.rightLow < start.rightLow || pose.leftLow < start.leftLow ? "TURN LOW ↶ DOWN" : "TURN LOW ↷ TO CENTER"
        case .bassSwap: return "LEFT LOW DOWN · RIGHT LOW TO CENTER"
        case .openEQ: return "OPEN MIXER / EQ"
        case .openFX: return "OPEN LEFT FX"
        case .echoOn: return "RAISE ECHO SLIGHTLY"
        case .echoOff: return "TURN ECHO OFF"
        case .count: return "LISTEN & COUNT — NO TAP"
        case .observe: return "LOOK / LISTEN — NO CHANGE"
        }
    }
    var changeLabels: (String, String) {
        switch action {
        case .play: return ("Paused", "Playing")
        case .pause: return ("Playing", "Paused")
        case .drag:
            func position(_ v: Double) -> String { v < 0.01 ? "Far left" : v > 0.99 ? "Far right" : abs(v - 0.5) < 0.01 ? "Center" : "Partial blend" }
            return (position(start.crossfader), position(pose.crossfader))
        case .cueSet: return ("Entry chosen", "Cue saved")
        case .cueJump: return ("Away from cue", "Back at cue")
        case .sync: return ("Sync off", "Sync on")
        case .low:
            let reducing = pose.leftLow < start.leftLow || pose.rightLow < start.rightLow
            return reducing ? ("Low at center", "Low reduced") : ("Low reduced", "Low at center")
        case .bassSwap: return ("Left bass leads", "Right bass leads")
        case .openEQ: return ("Mixer closed", "EQ visible")
        case .openFX: return ("FX closed", "FX open")
        case .echoOn: return ("Echo off", "Small echo amount")
        case .echoOff: return ("Echo on", "Echo off")
        case .count: return ("Listen", "Count 1 · 2 · 3 · 4")
        case .observe: return ("Keep this state", "No button press")
        }
    }

}
struct TeacherDemo {
    let frames: [DemoFrame]
    let secondsPerMove: Double = 4
    var duration: Double { Double(frames.count) * secondsPerMove }
    func frameIndex(at time: Double) -> Int { min(frames.count - 1, max(0, Int(max(0, time) / secondsPerMove))) }
    func pose(at time: Double) -> DemoPose {
        let i = frameIndex(at: time)
        let target = frames[i].pose
        let previous = frames[i].start
        let local = max(0, time - Double(i) * secondsPerMove)
        let fraction = min(1, max(0, (local - 0.7) / 1.8))
        let eased = fraction * fraction * (3 - 2 * fraction)
        func blend(_ a: Double, _ b: Double) -> Double { a + (b - a) * eased }
        var result = local < 1.4 ? previous : target
        result.crossfader = blend(previous.crossfader, target.crossfader)
        result.leftLow = blend(previous.leftLow, target.leftLow)
        result.rightLow = blend(previous.rightLow, target.rightLow)
        result.echo = blend(previous.echo, target.echo)
        result.playhead = blend(previous.playhead, target.playhead)
        return result
    }
    static func lesson(_ id: String, step: Int) -> TeacherDemo {
        func f(_ caption: String, _ focus: String, _ pose: DemoPose = DemoPose()) -> DemoFrame {
            DemoFrame(caption: caption, focus: focus, pose: pose)
        }
        let ready = DemoPose(cue: true, sync: true)
        let both = DemoPose(rightPlaying: true, cue: true, sync: true)
        let middle = DemoPose(crossfader: 0.5, rightPlaying: true)
        let landed = DemoPose(crossfader: 1, rightPlaying: true)
        let sequences: [[DemoFrame]]
        switch id {
        case "blend": sequences = [
            [f("In djay, leave the RIGHT deck paused. If it is already paused, leave it alone.", "rightPlay", DemoPose(crossfader: 0.5, leftPlaying: false)), f("In djay, drag the horizontal CROSSFADER handle all the way LEFT.", "crossfader", DemoPose(leftPlaying: false)), f("In djay, tap PLAY on the LEFT deck. Leave the right deck paused. You should hear only the left song.", "leftPlay")],
            [f("Keep the right deck paused while choosing an entry.", "rightPlay"), f("Set its cue at your chosen entry.", "cue", DemoPose(cue: true)), f("Tap right Sync. Check the real BPM displays in djay.", "sync", ready)],
            [f("Keep the crossfader left. Listen for a new section.", "crossfader", ready), f("Count 1–2–3–4 with the music. This illustration is not synced.", "beats", ready), f("At the actual section’s first beat, tap right Play.", "rightPlay", both)],
            [f("Both decks play; the crossfader is still left.", "rightPlay", both), f("Ease toward the center. Listen before going further.", "crossfader", DemoPose(crossfader: 0.35, rightPlaying: true)), f("Hold here and listen for crowded drums or vocals.", "crossfader", DemoPose(crossfader: 0.35, rightPlaying: true))],
            [f("Begin with both tracks in the blend.", "crossfader", middle), f("Gradually move right if the blend sounds good.", "crossfader", landed), f("Only the right deck should now be audible.", "rightPlay", landed)],
            [f("The right track carries the mix; the left is silent.", "crossfader", landed), f("Pause the silent left deck.", "leftPlay", DemoPose(crossfader: 1, leftPlaying: false, rightPlaying: true)), f("Prepare your next track on that silent deck.", "leftPlay", DemoPose(crossfader: 1, leftPlaying: false, rightPlaying: true))]
        ]
        case "controls": sequences = [
            [f("Each deck has its own Play/Pause.", "leftPlay", DemoPose(leftPlaying: false)), f("Tap left Play to start it.", "leftPlay"), f("Tap again to pause it.", "leftPlay", DemoPose(leftPlaying: false)), f("Tap Play to resume.", "leftPlay")],
            [f("Find the incoming deck’s tempo and Sync controls.", "sync"), f("Tap Sync on the right deck to match the active deck.", "sync", ready), f("Matching speed does not choose your musical entry.", "beats", ready)],
            [f("Keep the incoming deck paused.", "rightPlay"), f("Set a cue at your chosen entry.", "cue", DemoPose(cue: true)), f("Cue Jump returns to that saved entry.", "cue", DemoPose(cue: true))]
        ]
        case "phrases": sequences = [
            [f("Listen to a clear drum section.", "leftPlay"), f("Say 1–2–3–4 with its pulse.", "beats"), f("Repeat your count with the music, not this animation.", "beats")],
            [f("Keep one track playing while you listen.", "leftPlay"), f("Count bars and listen for a new section.", "beats"), f("A musical change confirms the phrase; a timer cannot.", "beats")],
            [f("Prepare a cue on the silent right deck.", "cue", ready), f("Start it on the actual section change.", "rightPlay", both), f("Reveal a little of it and listen to the entry.", "crossfader", DemoPose(crossfader: 0.3, rightPlaying: true))]
        ]
        case "eq": sequences = [
            [f("Open djay’s mixer or EQ view.", "eq"), f("Find Low, Mid and High on each deck.", "eq"), f("Low controls bass weight. Center is your starting point.", "rightLow")],
            [f("Keep the incoming deck silent.", "crossfader"), f("Lower the right deck’s Low EQ before bringing it in.", "rightLow", DemoPose(rightLow: 0.2)), f("Tap right PLAY at your chosen musical entry. Keep the crossfader left.", "rightPlay", DemoPose(rightPlaying: true, rightLow: 0.2)), f("Now drag the crossfader RIGHT a little to reveal the incoming track.", "crossfader", DemoPose(crossfader: 0.4, rightPlaying: true, rightLow: 0.2))],
            [f("Begin with incoming bass reduced.", "rightLow", DemoPose(crossfader: 0.4, rightPlaying: true, rightLow: 0.2)), f("At a section change, turn the LEFT Low knob DOWN.", "leftLow", DemoPose(crossfader: 0.4, rightPlaying: true, leftLow: 0.2, rightLow: 0.2)), f("Turn the RIGHT Low knob back UP to its center mark.", "rightLow", DemoPose(crossfader: 0.4, rightPlaying: true, leftLow: 0.2)), f("Complete the crossfade to the new deck.", "crossfader", DemoPose(crossfader: 1, rightPlaying: true, leftLow: 0.2))]
        ]
        case "echo": sequences = [
            [f("Keep the outgoing deck audible.", "crossfader"), f("Choose and set an entry on the silent right deck.", "cue", DemoPose(cue: true)), f("Keep it paused until your landing.", "rightPlay", DemoPose(cue: true))],
            [f("Open FX on the outgoing left deck.", "echo"), f("Choose Echo if available and use a small amount.", "echo", DemoPose(echo: 0.25)), f("If Echo is locked, use a plain fade; no purchase needed.", "crossfader")],
            [f("Use a brief, low echo near the outgoing section’s end.", "echo", DemoPose(echo: 0.25, cue: true)), f("On the next first beat in your music, tap RIGHT Play. Keep the crossfader left.", "rightPlay", DemoPose(rightPlaying: true, echo: 0.25)), f("Then drag the crossfader RIGHT to hand off to the new track.", "crossfader", DemoPose(crossfader: 1, rightPlaying: true, echo: 0.25)), f("Release the effect after the tail. Right stays audible.", "echo", landed)]
        ]
        default: sequences = [[f("Choose a lesson to see its demonstration.", "crossfader")]]
        }
        let actions: [String: [[DemoAction]]] = [
            "blend": [[.observe,.drag,.play], [.observe,.cueSet,.sync], [.observe,.count,.play], [.observe,.drag,.observe], [.observe,.drag,.observe], [.observe,.pause,.observe]],
            "controls": [[.observe,.play,.pause,.play], [.observe,.sync,.count], [.observe,.cueSet,.cueJump]],
            "phrases": [[.observe,.count,.count], [.observe,.count,.count], [.cueSet,.play,.drag]],
            "eq": [[.openEQ,.observe,.observe], [.observe,.low,.play,.drag], [.observe,.low,.low,.drag]],
            "echo": [[.observe,.cueSet,.observe], [.openFX,.echoOn,.observe], [.echoOn,.play,.drag,.echoOff]]
        ]
        let chosen = min(max(0, step), sequences.count - 1)
        let raw = sequences[chosen]
        var frames: [DemoFrame] = []
        for (i, value) in raw.enumerated() {
            var frame = value
            frame.action = actions[id]?[chosen][i] ?? .observe
            var start = i > 0 ? raw[i - 1].pose : frame.pose
            switch frame.action {
            case .observe, .count: start = frame.pose
            case .play:
                if frame.focus == "leftPlay" { start.leftPlaying = false; frame.pose.leftPlaying = true }
                else { start.rightPlaying = false; frame.pose.rightPlaying = true }
            case .pause:
                if frame.focus == "leftPlay" { start.leftPlaying = true; frame.pose.leftPlaying = false }
                else { start.rightPlaying = true; frame.pose.rightPlaying = false }
            case .drag:
                if id == "blend" && chosen == 0 { start.crossfader = 0.5 }
            case .cueSet: start.cue = false; frame.pose.cue = true; start.playhead = 0.25; frame.pose.playhead = 0.25
            case .cueJump: start.playhead = 0.8; frame.pose.playhead = 0.25; start.cue = true; frame.pose.cue = true
            case .sync: start.sync = false; frame.pose.sync = true
            case .low:
                if frame.focus == "leftLow" { start.leftLow = frame.pose.leftLow < 0.5 ? 1 : 0.2 }
                else { start.rightLow = frame.pose.rightLow < 0.5 ? 1 : 0.2 }
            case .bassSwap: start.leftLow = 1; start.rightLow = 0.2; frame.pose.leftLow = 0.2; frame.pose.rightLow = 1
            case .openEQ: start.mixerOpen = false; frame.pose.mixerOpen = true
            case .openFX: start.fxOpen = false; frame.pose.fxOpen = true
            case .echoOn: start.echo = 0; frame.pose.echo = 0.25; start.fxOpen = true; frame.pose.fxOpen = true
            case .echoOff: start.echo = 0.25; frame.pose.echo = 0; start.fxOpen = true; frame.pose.fxOpen = true
            }
            frame.before = start
            frames.append(frame)
        }
        return TeacherDemo(frames: frames)
    }
}
