import SwiftUI

struct TeacherDemoView: View {
    let lesson: TeacherLesson
    let step: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playing = false
    @State private var offset: Double = 0
    @State private var anchor = Date()
    @State private var practicing = false
    @State private var animationEnd: Double?
    private let mint = Color(red: 0.43, green: 0.98, blue: 0.82)
    private var demo: TeacherDemo { TeacherDemo.lesson(lesson.id, step: step) }
    private func elapsed(_ now: Date) -> Double {
        min(animationEnd ?? demo.duration, max(0, offset + (playing ? now.timeIntervalSince(anchor) : 0)))
    }
    var body: some View {
        Group {
            if practicing {
                SongPracticeView(lesson: lesson, step: step, replay: {
                    offset = 0; playing = false; practicing = false
                }, finish: { dismiss() })
            } else { walkthrough }
        }
    }
    private var walkthrough: some View {
        NavigationStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
                let time = elapsed(context.date)
                let index = demo.frameIndex(at: time)
                let frame = demo.frames[index]
                let pose = demo.pose(at: time)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Label("ANIMATED WALKTHROUGH", systemImage: "play.rectangle").font(.caption2.bold()).tracking(1)
                            Spacer()
                            Text("\(index + 1)/\(demo.frames.count)").font(.caption.monospacedDigit())
                        }.foregroundStyle(mint)
                        Text(lesson.steps[step].title).font(.title2.bold())
                        Text("Watch here. Make the actual moves in djay. The pictured controls are illustrations; use Next instruction when you’re ready.")
                            .font(.caption).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DO THIS IN DJAY · instruction \(index + 1)").font(.caption2.bold()).foregroundStyle(mint)
                            Text(frame.pointerLabel).font(.title2.bold()).foregroundStyle(mint)
                            Text(frame.caption).font(.callout).fixedSize(horizontal: false, vertical: true)
                            if frame.action != .observe && frame.action != .count {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading) {
                                        Text("START").font(.caption2.bold()).foregroundStyle(.secondary)
                                        Text(frame.changeLabels.0).font(.headline)
                                    }
                                    Image(systemName: "arrow.right").foregroundStyle(mint)
                                    VStack(alignment: .leading) {
                                        Text("FINISH").font(.caption2.bold()).foregroundStyle(mint)
                                        Text(frame.changeLabels.1).font(.headline)
                                    }
                                }
                                Text(time - Double(index) * demo.secondsPerMove < 0.7 ? "1 · Starting position" : time - Double(index) * demo.secondsPerMove < 2.5 ? "2 · Watch the move" : "3 · Result — copy it in djay")
                                    .font(.caption.bold()).foregroundStyle(mint)
                            }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
                        Label(frame.sectionLabel, systemImage: "scope")
                            .font(.caption.bold()).foregroundStyle(mint)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(spacing: 18) {
                            HStack(alignment: .top, spacing: 12) {
                                deck("LEFT / A", side: "left", playing: pose.leftPlaying, low: pose.leftLow, pose: pose, frame: frame, time: time)
                                deck("RIGHT / B", side: "right", playing: pose.rightPlaying, low: pose.rightLow, pose: pose, frame: frame, time: time)
                            }
                            VStack(spacing: 10) {
                                Text(frame.focus == "crossfader" ? frame.pointerLabel : "CROSSFADER").font(.caption2.bold()).foregroundStyle(.secondary)
                                GeometryReader { geometry in
                                    let width = max(1, geometry.size.width - 26)
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.14)).frame(height: 5)
                                        Capsule().fill(mint.opacity(0.4)).frame(width: width * pose.crossfader + 13, height: 5)
                                        RoundedRectangle(cornerRadius: 5).fill(mint).frame(width: 26, height: 28)
                                            .overlay(Image(systemName: "line.3.horizontal").font(.caption2).foregroundStyle(.black))
                                            .overlay(alignment: .bottom) {
                                                if frame.focus == "crossfader" && frame.action == .drag {
                                                    Image(systemName: "hand.point.up.fill").font(.title2).foregroundStyle(.white)
                                                        .shadow(color: .black, radius: 3).offset(y: 23)
                                                }
                                            }
                                            .offset(x: width * pose.crossfader)
                                    }.frame(height: 30)
                                }.frame(height: 30)
                                HStack { Text("A"); Spacer(); Text("B") }.font(.caption2.bold())
                                if frame.focus == "crossfader" && frame.action == .drag {
                                    Image(systemName: frame.pose.crossfader < frame.start.crossfader ? "arrow.left" : "arrow.right")
                                        .font(.system(size: 34, weight: .bold)).foregroundStyle(mint)
                                    Text(frame.changeLabels.0 + " → " + frame.changeLabels.1).font(.caption.bold()).foregroundStyle(mint)
                                }
                            }.padding(12).background(highlight(frame.focus == "crossfader"))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Crossfader, \(Int(pose.crossfader * 100)) percent toward right")
                            if frame.focus == "beats" {
                                HStack(spacing: 12) {
                                    ForEach(1...4, id: \.self) { beat in
                                        Text("\(beat)").font(.title3.bold().monospacedDigit()).frame(maxWidth: .infinity).padding(.vertical, 8)
                                            .background(Int(time * 2) % 4 + 1 == beat ? mint.opacity(0.25) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                pointer(frame.pointerLabel, arrow: false)
                                Text("Example count only — follow your music’s pulse.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(14).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
                        Button("Try this with songs", systemImage: "music.note.list") {
                            playing = false; practicing = true
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black).frame(maxWidth: .infinity)
                    }.padding(18).frame(maxWidth: 520).frame(maxWidth: .infinity)
                }.background(Color(red: 0.035, green: 0.045, blue: 0.065))
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 12) {
                        if index == demo.frames.count - 1 {
                            Button("Try this with songs", systemImage: "music.note.list") {
                                playing = false; practicing = true
                            }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                        }
                        Text("GUIDE CONTROLS — these do not operate djay").font(.caption2.bold()).foregroundStyle(.secondary)
                        ProgressView(value: Double(index + 1), total: Double(demo.frames.count)).tint(mint)
                        HStack {
                            Button("Previous") { move(to: max(0, index - 1)) }
                                .disabled(index == 0)
                            Spacer()
                            Button("Next instruction", systemImage: "arrow.right") {
                                move(to: min(demo.frames.count - 1, index + 1))
                            }.disabled(index == demo.frames.count - 1)
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                        if frame.action != .observe {
                        Button {
                            if playing { offset = time; playing = false; animationEnd = nil }
                            else {
                                offset = Double(index) * demo.secondsPerMove
                                animationEnd = min(demo.duration, offset + demo.secondsPerMove) - 0.001
                                anchor = Date(); playing = true
                            }
                        } label: {
                            Label(playing ? "Pause guide animation" : "Replay this movement", systemImage: playing ? "pause.rectangle" : "play.rectangle")
                        }.buttonStyle(.bordered).font(.caption)
                        }
                        Button("Start over", systemImage: "arrow.counterclockwise") { move(to: 0) }.font(.caption)

                        }.padding(18).background(Color(red: 0.035, green: 0.045, blue: 0.065))
                    }
                    .onChange(of: playing && time >= (animationEnd ?? demo.duration)) { _, finished in
                        if finished { offset = time; playing = false; animationEnd = nil }
                    }
            }
            .navigationTitle("Show me").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(mint).preferredColorScheme(.dark)
            .onAppear { move(to: demo.frameIndex(at: offset)) }
            .onDisappear { playing = false }
    }
    private func move(to index: Int) {
        offset = Double(index) * demo.secondsPerMove
        animationEnd = nil; playing = false
        if demo.frames[index].action != .observe && !reduceMotion {
            animationEnd = offset + demo.secondsPerMove - 0.001
            anchor = Date(); playing = true
        }
    }
    private func highlight(_ active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12).fill(active ? mint.opacity(0.12) : Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? mint : .clear, lineWidth: 2))
    }
    private func touchMarker(_ active: Bool) -> some View {
        Group {
            if active {
                Image(systemName: "hand.point.up.fill").font(.title3).foregroundStyle(.white)
                    .shadow(color: .black, radius: 2).padding(.trailing, 5)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private func pointer(_ label: String, arrow: Bool = true) -> some View {
        VStack(spacing: 3) {
            if arrow { Image(systemName: "arrow.up").font(.title3.bold()) }
            Text(label).font(.caption.bold()).multilineTextAlignment(.center)
        }.foregroundStyle(mint).frame(maxWidth: .infinity).padding(.vertical, 6)
            .accessibilityLabel("Pointing to control: " + label)
    }
    private func playback(side: String, playing: Bool, frame: DemoFrame, time: Double) -> some View {
        let focus = frame.focus
        let result = (frame.action == .play && playing) || (frame.action == .pause && !playing)
        let isTarget = focus == side + "Play"
        return VStack(spacing: 10) {
            if focus == "leftPlay" || focus == "rightPlay" {
            ZStack {
                Circle().fill(Color.black).overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 3))
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 2).padding(9)
                Circle().fill(side == "left" ? mint.opacity(0.7) : Color.purple.opacity(0.8)).padding(25)
                Rectangle().fill(Color.white).frame(width: 3, height: 14).offset(y: -25)
                    .rotationEffect(.degrees(playing && !reduceMotion ? time * 100 : 0))
                Circle().fill(.black).frame(width: 6, height: 6)
            }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 60).accessibilityHidden(true)
            Label(isTarget && result ? (playing ? "PLAYING" : "PAUSED") : (playing ? "PAUSE" : "PLAY"), systemImage: isTarget && result ? "checkmark.circle.fill" : playing ? "pause.fill" : "play.fill")
                .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10).background(highlight(focus == side + "Play"))
                .overlay(alignment: .trailing) { touchMarker(isTarget && !result && (frame.action == .play || frame.action == .pause)) }
            if isTarget {
                pointer(result ? (playing ? "RESULT: NOW PLAYING" : "RESULT: NOW PAUSED") : frame.pointerLabel, arrow: !result)
            }
            Text(playing ? "PLAYING · track running" : "PAUSED · track stopped").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(playing ? "PLAYING" : "PAUSED").font(.caption.bold()).foregroundStyle(.secondary)
            }
        }
    }
    private func deck(_ title: String, side: String, playing: Bool, low: Double, pose: DemoPose, frame: DemoFrame, time: Double) -> some View {
        let focus = frame.focus
        let active = focus == side + "Play" || focus == side + "Low" || (side == "right" && ["cue", "sync"].contains(focus)) || (side == "left" && focus == "echo") || focus == "eq"
        return VStack(spacing: 12) {
            Text(title).font(.caption2.bold()).tracking(1).foregroundStyle(side == "left" ? mint : .purple)
            playback(side: side, playing: playing, frame: frame, time: time)
            if focus == "cue" {
                if side == "right" {
                    Text(pose.cue ? "CUE SAVED" : "CUE NOT SET").font(.caption2.bold()).foregroundStyle(mint)
                    ProgressView(value: pose.playhead, total: 1).tint(mint)
                    Text(frame.action == .cueJump ? "Track marker returns to saved cue" : "Save this track position").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 5) {
                    ForEach(["CUE SET", "CUE JUMP"], id: \.self) { control in
                        let target = side == "right" && (frame.action == .cueJump ? control == "CUE JUMP" : control == "CUE SET")
                        VStack(spacing: 3) {
                            Text(control).font(.system(size: 9, weight: .bold))
                                .frame(maxWidth: .infinity).padding(.vertical, 9).background(highlight(target))
                                .overlay(alignment: .trailing) { touchMarker(target) }
                            if target { pointer(frame.pointerLabel) }
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            if focus == "sync" {
                Text(pose.sync && side == "right" ? "SYNC ON" : "SYNC")
                    .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(highlight(side == "right"))
                    .overlay(alignment: .trailing) { touchMarker(side == "right" && frame.action == .sync) }
                if side == "right" { pointer(frame.pointerLabel) }
            }
            if (focus == "eq" || focus == "leftLow" || focus == "rightLow") && pose.mixerOpen {
            HStack(spacing: 5) {
                ForEach(["LOW", "MID", "HIGH"], id: \.self) { band in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.18), lineWidth: 3)
                            Capsule().fill(mint).frame(width: 2, height: 8).offset(y: -7)
                                .rotationEffect(.degrees(band == "LOW" ? (low - 1) * 140 : 0))
                        }.frame(width: 24, height: 24)
                        Text(band).font(.system(size: 8, weight: .bold))
                        if band == "LOW" && focus == side + "Low" && frame.action == .low {
                            Image(systemName: "hand.point.up.fill").foregroundStyle(mint)
                            Text("Turn LOW").font(.system(size: 9, weight: .bold)).foregroundStyle(mint)
                        }
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.vertical, 9).background(highlight(focus == "eq" || focus == side + "Low"))
                .accessibilityElement(children: .ignore).accessibilityLabel("\(side) Low EQ, \(low < 0.5 ? "reduced" : "center")")
            }
            if focus == "eq" {
                Text(pose.mixerOpen ? "MIXER OPEN · EQ visible" : "MIXER CLOSED").font(.caption2.bold()).foregroundStyle(mint)
                pointer(frame.pointerLabel)
            }
            if side == "left" && focus == "echo" {
                Text(!pose.fxOpen ? "FX CLOSED" : pose.echo > 0 ? "ECHO · LOW AMOUNT" : "FX OPEN · ECHO OFF").font(.system(size: 9, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 9).background(highlight(focus == "echo"))
                    .overlay(alignment: .trailing) { touchMarker(true) }
                ProgressView(value: pose.echo, total: 1).tint(mint)
                pointer(frame.pointerLabel)
            }
        }.padding(8).frame(maxWidth: .infinity)
            .background(highlight(active))
            .opacity(active || ["crossfader", "beats"].contains(focus) ? 1 : 0.4)
    }
}

private struct SongPracticeView: View {
    let lesson: TeacherLesson
    let step: Int
    let replay: () -> Void
    let finish: () -> Void
    @AppStorage("practiceLeftSong") private var leftSong = "Hurts Me"
    @AppStorage("practiceRightSong") private var rightSong = "FE!N"
    @State private var editingSongs = false
    @State private var result: String?
    private let mint = Color(red: 0.43, green: 0.98, blue: 0.82)
    private var current: TeacherLesson.Step { lesson.steps[step] }
    private func title(_ value: String, fallback: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("WATCH → TRY → LISTEN", systemImage: "music.note.list")
                        .font(.caption.bold()).foregroundStyle(mint)
                    Text("Your turn with real songs.").font(.title2.bold())
                    Text("Play these in djay, then copy the move you just watched. DJ TUT provides the practice prompts; it doesn’t load or play these songs.")
                        .font(.callout).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        songCard(side: "LEFT / A", song: title(leftSong, fallback: "Your left track"), color: mint)
                        songCard(side: "RIGHT / B", song: title(rightSong, fallback: "Your right track"), color: .purple)
                        HStack {
                            Button("Change songs") { editingSongs.toggle() }
                            Spacer()
                            Button("Swap decks", systemImage: "arrow.left.arrow.right") {
                                let previous = leftSong; leftSong = rightSong; rightSong = previous; result = nil
                            }
                        }.font(.caption).buttonStyle(.bordered)
                        if editingSongs {
                            TextField("Left deck song", text: $leftSong).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Left deck song")
                                .onChange(of: leftSong) { _, value in leftSong = String(value.prefix(80)); result = nil }
                            TextField("Right deck song", text: $rightSong).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Right deck song")
                                .onChange(of: rightSong) { _, value in rightSong = String(value.prefix(80)); result = nil }
                            Button("Save practice pair") { editingSongs = false }.buttonStyle(.bordered)
                            Text("Names stay on this iPad. This does not change the songs loaded in djay.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(16).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                    Text("1 · Pick an easy section").font(.headline).foregroundStyle(mint)
                    Text("Use a clear drum or instrumental section first. Keep listening volume comfortable. With this pair, avoid bringing two lead vocals in together. Choose your entry by listening; no exact BPM or timestamp is assumed.")
                        .font(.callout)
                    Text("2 · Try: " + current.title).font(.headline).foregroundStyle(mint)
                    Text(current.action).font(.system(size: 18)).fixedSize(horizontal: false, vertical: true)
                    Text("3 · Listen for this").font(.headline).foregroundStyle(mint)
                    Text(current.check).font(.callout)
                    Text("How did your attempt feel?").font(.headline)
                    VStack(spacing: 8) {
                        outcome("Felt clear", icon: "checkmark.circle")
                        outcome("Sounded crowded", icon: "waveform")
                        outcome("Missed the move", icon: "arrow.counterclockwise")
                    }
                    if let result {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(result == "Felt clear" ? "Try it once more" : "A smaller retry").font(.headline)
                            Text(result == "Felt clear" ? "Repeat the same move at another clear section. If it still feels comfortable, return to the lesson and choose Next move." : result == "Sounded crowded" ? "Ease back to one audible deck. Try a less busy section or shorten the overlap. Change only one thing on the next attempt." : current.fix)
                            Text("For a full retry: keep one deck audible; pause the silent incoming deck and return it to its cue yourself in djay.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Try the same move again") { self.result = nil }.buttonStyle(.bordered)
                        }.padding(16).background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Text("Your feedback guides the next prompt. The coach hasn’t heard or graded the attempt.")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Button("Watch demo again", systemImage: "play.rectangle") { replay() }.buttonStyle(.bordered)
                        Spacer()
                        Button("Back to lesson") { finish() }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                    }
                }.padding(18).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
                .background(Color(red: 0.035, green: 0.045, blue: 0.065))
                .navigationTitle("Practice with songs").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
        }.tint(mint).preferredColorScheme(.dark)
    }
    private func songCard(side: String, song: String, color: Color) -> some View {
        HStack {
            Image(systemName: "opticaldisc.fill").font(.title).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(side).font(.caption2.bold()).foregroundStyle(color)
                Text(song).font(.headline)
            }
            Spacer()
        }.accessibilityElement(children: .combine)
    }
    private func outcome(_ label: String, icon: String) -> some View {
        Button { result = label } label: {
            Label(label, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.bordered).tint(result == label ? mint : .gray)
    }
}
