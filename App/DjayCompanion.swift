import SwiftUI

struct TimedCompanion: View {
    @EnvironmentObject private var clock: LinkClock
    @EnvironmentObject private var lab: AudioLab
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = false
    @State private var setup = false
    #if DJAY_COMPANION
    @State private var manual = true
    private let supportsLink = false
    #else
    @State private var manual = false
    private let supportsLink = true
    #endif
    @State private var manualBPM = 120.0
    @State private var manualEpoch = Date()
    @State private var taps: [Date] = []
    @State private var timing = CompanionTiming()
    @State private var lesson = CompanionLesson.echo
    @State private var currentBeat = 0.0
    @State private var help = false
    @State private var visible = false
    @State private var notice: String?
    private let accent = Color(red: 0.43, green: 0.98, blue: 0.82)
    private var ready: Bool { manual || clock.connected }
    private var elapsed: Double? { timing.elapsed(at: currentBeat) }
    private var phase: (index: Int, remaining: Double)? { elapsed.flatMap { lesson.step(at: $0) } }
    private var finished: Bool { if let elapsed { return elapsed >= lesson.steps.reduce(0) { $0 + $1.beats } }; return false }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DJ TUT / COMPANION").font(.caption2.bold()).tracking(2).foregroundStyle(accent)
                            Text("Your next move.").font(.system(size: 30, weight: .bold, design: .rounded))
                        }
                        Spacer(minLength: 4)
                        Button { setup = true } label: { Image(systemName: "questionmark.circle").font(.title2) }.accessibilityLabel("Set up with djay")
                    }
                    HStack(spacing: 8) {
                        Circle().fill(ready ? accent : .orange).frame(width: 7, height: 7)
                        Text(manual ? "Manual timing · not synced" : clock.connected ? "Link connected · beat timing" : clock.enabled ? "Waiting for a Link peer" : "Connect with Ableton Link")
                            .font(.caption.bold())
                        Spacer(minLength: 0)
                    }
                    Text(manual ? "Set the BPM shown in djay and tap a phrase start. Re-align if the timing drifts." : "Enable Link in both apps. DJ TUT follows shared timing; song sections and deck controls stay in djay.")
                        .font(.caption).foregroundStyle(.secondary)
                    if supportsLink { HStack {
                        Button("Ableton Link") { settings = true }.buttonStyle(.bordered)
                        Button(manual ? "Use Link" : "Manual timing") {
                            manual.toggle(); timing.reset(); notice = nil; manualEpoch = Date()
                        }.buttonStyle(.bordered)
                    }
                    Text("Ableton Link · \(clock.enabled ? "Enabled" : "Disabled")").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Manual coach · automatic sync is unavailable in this free signing build.").font(.caption2).foregroundStyle(.secondary)
                    }
                    if manual {
                        HStack {
                            Stepper(value: $manualBPM, in: 40...250, step: 0.5) { Text(String(format: "%.1f BPM", manualBPM)).monospacedDigit() }
                            Button("Tap BPM", action: tapTempo).buttonStyle(.bordered)
                        }.onChange(of: manualBPM) { _, _ in timing.reset(); manualEpoch = Date() }
                    }
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(ready ? String(format: "%.1f", manual ? manualBPM : clock.bpm) : "—").font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("BPM").font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(timing.anchor == nil ? "Shared beat" : "Your phrase grid").font(.caption2).foregroundStyle(.secondary)
                                Text(ready ? "\(timing.beatInBar(at: currentBeat)) / 4" : "— / 4").font(.title2.bold()).monospacedDigit()
                            }
                        }
                        HStack(spacing: 10) {
                            ForEach(1...4, id: \.self) { beat in
                                Capsule().fill(ready && timing.beatInBar(at: currentBeat) == beat ? accent : Color.white.opacity(0.09)).frame(height: 9)
                            }
                        }.accessibilityLabel("Beat \(timing.beatInBar(at: currentBeat)) of four")
                        Button(timing.anchor == nil ? "Mark phrase start on the ONE" : "Re-mark phrase start") {
                            timing.markPhrase(at: currentBeat); notice = nil
                        }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).disabled(!ready)
                        Text("Tap on the first beat of a new 8-bar phrase in the playing track. Link alone cannot find that phrase.").font(.caption2).foregroundStyle(.secondary)
                    }.padding(18).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
                    Picker("Transition lesson", selection: $lesson) {
                        ForEach(CompanionLesson.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).tint(accent).disabled(timing.start != nil && !finished)
                        .onChange(of: lesson) { _, _ in timing.stop() }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GUIDED TRANSITION").font(.caption2.bold()).tracking(2).foregroundStyle(accent)
                        if let phase {
                            Text(lesson.steps[phase.index].title).font(.title2.bold())
                            Text(lesson.steps[phase.index].instruction).font(.body)
                            HStack {
                                Text("\(max(1, Int(ceil(phase.remaining))))").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                                Text("beats to next move").font(.caption).foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(phase.index + 1), total: Double(lesson.steps.count)).tint(accent)
                        } else if let elapsed, elapsed < 0 {
                            Text("Get ready in \(Int(ceil(-elapsed))) beats").font(.title2.bold()).monospacedDigit()
                            Text("The lesson starts at your next anchored 8-bar phrase. Keep A playing; B should be cued and silent.")
                        } else if finished {
                            Text("Handoff complete").font(.title2.bold())
                            Text("How did it sound? If the drop missed the phrase, re-mark the one and try again.")
                        } else {
                            Text(lesson.rawValue).font(.title2.bold())
                            Text(lesson.preparation)
                            Text("For Hurts Me → FE!N, try the echo-out lesson. Choose B’s drop cue by ear; this coach has not analyzed those recordings.").font(.caption).foregroundStyle(.secondary)
                        }
                        if timing.start == nil || finished {
                            Button("Start guided transition") { timing.arm(at: currentBeat); notice = nil }
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .disabled(!ready || timing.anchor == nil)
                        } else {
                            Button("Stop lesson") { timing.stop() }.buttonStyle(.bordered)
                        }
                        HStack {
                            Button("Why this move?") { help = true }.buttonStyle(.bordered)
                            Button("I missed the cue") { timing.reset(); notice = "Keep the music playing in djay. Mark the next phrase start, then restart the lesson." }.buttonStyle(.bordered)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [Color.purple.opacity(0.18), Color.white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
                    if let notice { Text(notice).font(.caption).foregroundStyle(.orange) }
                    Text(manual ? "You operate djay. This coach uses your BPM and phrase marker; it does not read djay’s playback or controls. Lessons run on this device without cloud requests." : "You operate djay. The coach reads Link timing, not audio, track titles, faders or effects. Lessons run on this device without cloud requests.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
            }.background(Color(red: 0.035, green: 0.045, blue: 0.065))
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $settings) {
            NavigationStack {
                LinkPreferences(clock: clock)
                    .navigationTitle("Ableton Link")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { settings = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $setup) {
            NavigationStack {
                ScrollView { VStack(alignment: .leading, spacing: 20) {
                    Text("djay plays. DJ TUT teaches.").font(.title.bold())
                    Text("1. In djay, connect Spotify Premium and load your two tracks.")
                    Text(supportsLink ? "2. In djay Settings → Ableton Link, enable Link. Play A with its fader raised and use Beat and Tempo Sync." : "2. Play deck A in djay and note its displayed BPM. Cue deck B at the section you want to drop, with B’s fader down.")
                    Text(supportsLink ? "3. Here, open Ableton Link and enable it. Allow Local Network access when asked. Connected means a Link peer was found; it does not identify the peer as djay." : "3. This free signing build uses Manual timing. Set or tap the BPM shown in djay; automatic Link sync is unavailable in this build.")
                    Text("4. On your iPad, hold the window controls at the top of DJ TUT and choose Enter Slide Over. Or arrange DJ TUT and djay side by side. Keep both visible for live timing.")
                    Text("5. Mark the one at an audible phrase start, then start the lesson. Follow the prompts using djay’s own controls.")
                    Text("If Link stays disconnected, use Manual timing. Physical-device Link builds require Apple’s multicast entitlement in the signing profile; adding a checkbox to the project does not grant it.").font(.caption).foregroundStyle(.secondary)
                }.padding(22) }.navigationTitle("Set up with djay")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { setup = false } } }
            }
        }
        .alert("Why this move?", isPresented: $help) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(lesson == .echo ? "A short echo lets the outgoing rhythm fade while the new track lands cleanly. Starting B on a phrase boundary helps the change feel intentional. Judge the cue and echo length by ear." : "Turning down B’s bass leaves room for A’s low end. Swapping the bass avoids two kick and bass patterns competing. Matching beats alone does not guarantee that melodies or vocals fit.")
        }
        .onAppear { visible = true; lab.yieldAudioToDjay(); clock.setActive(supportsLink && scenePhase != .background) }
        .onDisappear { visible = false; lab.companionActive = false; clock.setActive(false); timing.reset() }
        .onChange(of: scenePhase) { _, phase in
            // An unfocused but visible Slide Over window may be foreground-inactive.
            clock.setActive(supportsLink && visible && phase != .background)
            if phase == .background { timing.reset(); notice = "Timing paused while the coach was hidden. Mark the phrase again when both apps are visible." }
        }
        .onChange(of: clock.connected) { _, connected in
            if !manual { timing.reset(); notice = connected ? "Link peer connected. Mark a phrase start in the playing track." : "Connection lost. Lesson stopped; reconnect and mark the phrase again." }
        }
        .onReceive(clock.$beat) { beat in
            guard visible, scenePhase != .background else { return }
            currentBeat = manual ? Date().timeIntervalSince(manualEpoch) * manualBPM / 60 : beat
            if ready && !timing.observe(currentBeat) { notice = "The beat timeline changed. Mark the phrase start again." }
        }
    }
    private func tapTempo() {
        let now = Date()
        if let last = taps.last, now.timeIntervalSince(last) > 2 { taps.removeAll() }
        taps.append(now); taps = Array(taps.suffix(5))
        if taps.count > 1, let first = taps.first {
            manualBPM = min(250, max(40, 60 * Double(taps.count - 1) / now.timeIntervalSince(first)))
        }
    }
}
