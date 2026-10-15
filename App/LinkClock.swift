import SwiftUI
import Darwin

@MainActor final class LinkClock: ObservableObject {
    let reference: ABLLinkRef
    @Published private(set) var enabled = false
    @Published private(set) var connected = false
    @Published private(set) var beat = 0.0
    @Published private(set) var bpm = 120.0
    @Published private(set) var active = false
    private var timer: Timer?
    init() {
        reference = ABLLinkNew(120)!
        timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func setActive(_ value: Bool) {
        active = value
        ABLLinkSetActive(reference, value)
        sample()
    }
    func sample() {
        // A lesson-only overlay has no timing subscription and needs no render updates.
        guard active else { if connected { connected = false }; return }
        enabled = ABLLinkIsEnabled(reference)
        connected = active && ABLLinkIsConnected(reference)
        let state = ABLLinkCaptureAppSessionState(reference)
        bpm = ABLLinkGetTempo(state)
        // Visual coach reads the shared clock at the current host time; it renders no audio.
        beat = ABLLinkBeatAtTime(state, mach_absolute_time(), 4)
    }
    deinit { timer?.invalidate(); ABLLinkDelete(reference) }
}

struct LinkPreferences: UIViewControllerRepresentable {
    let clock: LinkClock
    func makeUIViewController(context: Context) -> ABLLinkSettingsViewController {
        ABLLinkSettingsViewController.instance(clock.reference)
    }
    func updateUIViewController(_ controller: ABLLinkSettingsViewController, context: Context) {}
}
