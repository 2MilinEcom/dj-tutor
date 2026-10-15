import SwiftUI

struct TeachingAnswer: Codable {
    let answer: String
    let action: String
    let check: String
    let followUp: String
}
struct TeachingTurn: Identifiable, Codable {
    var id = UUID()
    let role: String
    let text: String
    let answer: TeachingAnswer?
}
@MainActor final class TeachingService: ObservableObject {
    @Published var turns: [TeachingTurn] = []
    @Published var busy = false
    @Published var error: String?
    @Published var connected = false
    init() {
        #if DEBUG
        // Private pilot provisioning: import only a short-lived app bearer, never a provider key.
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(".teacher-session.json")
        if let data = try? Data(contentsOf: file),
           let value = try? JSONDecoder().decode(SessionSeed.self, from: data) {
            try? Vault.write("coachSession", Data(value.token.utf8))
            if value.aiTeachingApproved == true {
                UserDefaults.standard.set(true, forKey: "teacherAIConsent")
            }
            try? FileManager.default.removeItem(at: file)
        }
        #endif
        connected = Vault.read("coachSession") != nil
    }
    private struct SessionSeed: Codable { let token: String; let aiTeachingApproved: Bool? }
    func ask(_ question: String, lesson: TeacherLesson, step: Int, feedback: String = "question") async {
        guard !busy, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        busy = true; error = nil
        defer { busy = false }
        let history = turns.suffix(4).map { ["role": $0.role, "text": String($0.text.prefix(1200))] }
        turns.append(TeachingTurn(role: "user", text: String(question.prefix(800)), answer: nil))
        turns = Array(turns.suffix(12))
        do {
            guard let url = URL(string: AppConfig.value("CoachBaseURL")), url.scheme == "https",
                  let data = Vault.read("coachSession"), let bearer = String(data: data, encoding: .utf8) else {
                throw AppError(message: "AI connection needs a pilot session. The lessons and explanations work offline.")
            }
            var request = URLRequest(url: url.appendingPathComponent("teach"))
            request.httpMethod = "POST"; request.timeoutInterval = 35
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["question": String(question.prefix(800)), "topic": lesson.id, "step": step, "feedback": feedback, "history": history])
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                if status == 401 { connected = false; throw AppError(message: "Your private AI session has expired. It needs refreshing from the Mac; lessons still work offline.") }
                if status == 429 { throw AppError(message: "The pilot’s AI question limit has been reached. You can keep using every offline lesson.") }
                throw AppError(message: "AI is unavailable. Keep the Mac coach connection running, or use the offline help below.")
            }
            let answer = try JSONDecoder().decode(TeachingAnswer.self, from: responseData)
            connected = true
            let text = "\(answer.answer)\n\(answer.action)\n\(answer.check)"
            turns.append(TeachingTurn(role: "assistant", text: text, answer: answer))
        } catch { self.error = error.localizedDescription }
    }
}

struct DjayCompanion: View {
    @EnvironmentObject private var lab: AudioLab
    @EnvironmentObject private var clock: LinkClock
    @AppStorage("teacherProgress") private var savedProgress = ""
    @AppStorage("teacherAIConsent") private var aiConsent = false
    @StateObject private var teacher = TeachingService()
    @AppStorage("teacherLesson") private var selected = "blend"
    @State private var progress = TeacherProgress()
    @State private var tab = 0
    @State private var question = ""
    @State private var helpMode: String?
    @State private var showSetup = false
    @State private var showDemo = false
    @State private var recovery = false
    @FocusState private var questionFocused: Bool
    private let mint = Color(red: 0.43, green: 0.98, blue: 0.82)
    private var lesson: TeacherLesson { TeacherLesson.all.first(where: { $0.id == selected }) ?? TeacherLesson.all[0] }
    private var index: Int { progress.index(for: lesson) }
    private var step: TeacherLesson.Step { lesson.steps[index] }
    private var done: Bool { progress.completed.contains(lesson.id) }
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        Picker("Teacher mode", selection: $tab) {
                            Text("Teach me").tag(0)
                            Text("Ask AI").tag(1)
                        }.pickerStyle(.segmented)
                        if tab == 0 { lessonView }
                        else { chatView }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(18).frame(maxWidth: 520).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: teacher.turns.count) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: teacher.busy) { _, busy in if !busy { withAnimation { reader.scrollTo("bottom", anchor: .bottom) } } }
            }.background(Color(red: 0.035, green: 0.045, blue: 0.065))
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(mint)
        .sheet(isPresented: $showSetup) { setupView }
        .sheet(isPresented: $showDemo) {
            if #available(iOS 18.0, *) {
                TeacherDemoView(lesson: lesson, step: index).presentationSizing(.page)
            } else {
                TeacherDemoView(lesson: lesson, step: index).presentationDetents([.large])
            }
        }
        .onAppear {
            lab.yieldAudioToDjay(); clock.setActive(false)
            if !TeacherLesson.all.contains(where: { $0.id == selected }) { selected = "blend" }
            if let data = savedProgress.data(using: .utf8), let value = try? JSONDecoder().decode(TeacherProgress.self, from: data) { progress = value }
        }
        .onDisappear { lab.companionActive = false }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["DJTUT_VALIDATE_TEACHER"] == "1" {
                await TeacherAcceptance.run(teacher)
            }
            #endif
        }
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("DJ TUT / YOUR TEACHER").font(.caption2.bold()).tracking(2).foregroundStyle(mint)
                Text("Your next move.").font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Prompts while you practice in djay.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { showSetup = true } label: { Image(systemName: "info.circle").font(.title2) }.accessibilityLabel("About the teaching overlay")
        }
    }
    private var lessonView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Choose a lesson", selection: $selected) {
                ForEach(TeacherLesson.all) { lesson in
                    Text(lesson.title + (progress.completed.contains(lesson.id) ? " ✓" : "")).tag(lesson.id)
                }
            }.pickerStyle(.menu).onChange(of: selected) { _, _ in helpMode = nil; recovery = false }
            HStack {
                Image(systemName: lesson.symbol).foregroundStyle(mint)
                Text(lesson.subtitle).font(.caption)
                Spacer()
                Text("\(index + 1)/\(lesson.steps.count)").font(.caption.monospacedDigit())
            }
            ProgressView(value: done ? Double(lesson.steps.count) : Double(index), total: Double(lesson.steps.count)).tint(mint)
            VStack(alignment: .leading, spacing: 14) {
                Text(recovery ? "Let’s reset the attempt" : done ? "Lesson practiced" : step.title).font(.title2.bold())
                if recovery {
                    Text("In djay, return to one audible deck. For the first-blend drill: keep the left track playing, ease the crossfader left, pause the right deck and return it to its cue.")
                    Text("I’ve restarted the lesson. I haven’t moved or rewound djay’s controls.").font(.caption).foregroundStyle(.secondary)
                    Button("Ready — start again") { recovery = false }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                } else if done {
                    Text("Nice work staying with it. Choose another lesson or repeat this one. Completion is based on your progress taps, not an assessment of your audio.")
                    Button("Practice again") { progress.restart(lesson); save() }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                } else {
                    Text(step.action).font(.system(size: 18)).fixedSize(horizontal: false, vertical: true)
                    Label("What to check", systemImage: "ear").font(.caption.bold()).foregroundStyle(mint)
                    Text(step.check).font(.callout).foregroundStyle(.secondary)
                    Button("Show me", systemImage: "play.rectangle.fill") { showDemo = true }
                        .buttonStyle(.bordered).tint(mint)
                    Text("Watch an animated example, then copy the move in djay.").font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Button("Back") { progress.back(lesson); helpMode = nil; save() }.buttonStyle(.bordered).disabled(index == 0)
                        Spacer()
                        Button(index == lesson.steps.count - 1 ? "Finish lesson" : "Next move") {
                            progress.advance(lesson); helpMode = nil; save()
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                    }
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color.purple.opacity(0.22), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            HStack(spacing: 8) {
                helpButton("Why?", mode: "explain", icon: "lightbulb")
                helpButton("Find it", mode: "find", icon: "viewfinder")
                helpButton("Fix it", mode: "fix", icon: "wrench")
            }
            Button("I messed up — restart lesson", systemImage: "arrow.counterclockwise") {
                progress.restart(lesson); save(); helpMode = nil; recovery = true
            }.buttonStyle(.bordered).tint(.orange)
            if let helpMode {
                VStack(alignment: .leading, spacing: 10) {
                    Text(helpMode == "explain" ? "Why this matters" : helpMode == "find" ? "Where to look" : "Try this first").font(.headline)
                    Text(helpMode == "explain" ? step.why : helpMode == "find" ? step.find : step.fix)
                    Button("Ask AI about this") {
                        question = helpMode == "find" ? "I can’t find this control. Where should I look?" : helpMode == "fix" ? "This move doesn’t sound right. Help me work out what to check." : "Explain this move in simpler terms."
                        tab = 1
                    }.buttonStyle(.bordered)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            }
            Button { tab = 1 } label: { Label("Ask your AI teacher", systemImage: "sparkles") }.buttonStyle(.bordered)
            Text("No BPM entry or phrase marker needed. You make the moves in djay; this overlay teaches from the lesson and what you tell it.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func helpButton(_ title: String, mode: String, icon: String) -> some View {
        Button { helpMode = helpMode == mode ? nil : mode } label: {
            VStack(spacing: 5) { Image(systemName: icon); Text(title).font(.caption.bold()) }.frame(maxWidth: .infinity).padding(.vertical, 10)
        }.buttonStyle(.bordered).tint(helpMode == mode ? mint : .gray)
    }
    private var chatView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Learning: \(lesson.title) · step \(index + 1)").font(.caption).foregroundStyle(mint)
            Button("Show this lesson’s move", systemImage: "play.rectangle.fill") { showDemo = true }
                .buttonStyle(.bordered)
            Toggle("Send my question and lesson context to AI", isOn: $aiConsent).font(.caption)
            Text("OpenAI receives your typed question and recent Q&A through the Mac coach connection. No music or screen is captured. Don’t include passwords or private information.").font(.caption2).foregroundStyle(.secondary)
            if teacher.turns.isEmpty {
                Text("Ask about a control, a mixing problem, or what to try next. I can teach from your description; I can’t see or hear djay.").font(.callout)
                ForEach(["Explain this step simply", "Why do the drums clash?", "How do I avoid overlapping vocals?"], id: \.self) { prompt in
                    Button(prompt) { question = prompt }.buttonStyle(.bordered)
                }
            }
            ForEach(teacher.turns) { turn in
                VStack(alignment: .leading, spacing: 10) {
                    Text(turn.role == "user" ? "YOU" : "AI TEACHER").font(.caption2.bold()).tracking(1).foregroundStyle(turn.role == "user" ? .secondary : mint)
                    if let answer = turn.answer {
                        Text(answer.answer)
                        Text("Try next").font(.caption.bold()).foregroundStyle(mint)
                        Text(answer.action)
                        Text(answer.check).font(.callout).foregroundStyle(.secondary)
                        Text(answer.followUp).font(.callout).foregroundStyle(mint)
                        Button("Reply to teacher") { question = ""; questionFocused = true }.font(.callout)
                    } else { Text(turn.text) }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(turn.role == "user" ? Color.white.opacity(0.04) : Color.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
            }
            if teacher.busy { ProgressView("Your teacher is thinking…").font(.caption) }
            if let error = teacher.error { Text(error).font(.caption).foregroundStyle(.orange) }
            TextField("What would you like help with?", text: $question, axis: .vertical)
                .lineLimit(2...5).padding(12).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)).focused($questionFocused)
                .onChange(of: question) { _, value in if value.count > 800 { question = String(value.prefix(800)) } }
            HStack {
                Button("Back to lesson") { tab = 0; questionFocused = false }.buttonStyle(.bordered)
                Spacer()
                Button("Ask", systemImage: "arrow.up") {
                    let prompt = question; question = ""; questionFocused = false
                    Task { await teacher.ask(prompt, lesson: lesson, step: index) }
                }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(!aiConsent || teacher.busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !teacher.turns.isEmpty { Button("Clear conversation") { teacher.turns = []; teacher.error = nil }.font(.caption).disabled(teacher.busy) }
        }
    }
    private var setupView: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 20) {
                Text("djay plays. DJ TUT teaches.").font(.title.bold())
                Text("Keep this window in Slide Over or beside djay. Choose a lesson and follow one move at a time. Why, Find it and Fix it work without an AI connection.")
                Text("Ask AI sends only your typed question, current lesson and recent Q&A after you opt in. The teacher cannot watch your screen, hear your music, move djay controls, or score your performance.")
                Text("The pilot AI connection requires your Mac coach and its temporary HTTPS connection to stay running. Its short-lived sign-in may need refreshing. Offline lessons always remain available.").font(.caption).foregroundStyle(.secondary)
                Link("Open djay’s official iPad/iPhone guide", destination: URL(string: "https://help.algoriddim.com/user-manual/djay-ios")!)
            }.padding(22) }.navigationTitle("Your teaching overlay")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSetup = false } } }
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(progress), let text = String(data: data, encoding: .utf8) { savedProgress = text }
    }
}

#if DEBUG
@MainActor private enum TeacherAcceptance {
    static var hasRun = false
    static func run(_ teacher: TeachingService) async {
        guard !hasRun else { return }; hasRun = true
        let credentialPresent = Vault.read("coachSession") != nil
        await teacher.ask("Explain what the crossfader does in djay on iPad. I am a beginner.", lesson: TeacherLesson.all[0], step: 0)
        let response = teacher.turns.last?.answer
        let passed = credentialPresent && teacher.error == nil && response != nil
        let report: [String: Any] = ["passed": passed, "sessionInKeychain": credentialPresent,
            "answer": response?.answer ?? "", "action": response?.action ?? "", "check": response?.check ?? "", "error": teacher.error ?? ""]
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("teacher-acceptance.json")
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) { try? data.write(to: url, options: .atomic) }
        teacher.turns = [] // The synthetic verification question is not the learner's conversation.
    }
}
#endif
