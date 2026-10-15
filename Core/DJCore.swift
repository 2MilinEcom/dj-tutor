import Foundation

public struct Analysis: Codable, Equatable, Sendable {
    public var bpm: Double
    public var key: String
    public var confidence: Double
    public var waveform: [Float]
    public init(bpm: Double, key: String, confidence: Double, waveform: [Float]) {
        self.bpm = bpm; self.key = key; self.confidence = confidence; self.waveform = waveform
    }
}
public enum DSP {
    public static func analyze(_ samples: [Float], sampleRate: Double) -> Analysis {
        guard samples.count > 2048, sampleRate > 0 else { return Analysis(bpm: 120, key: "Unknown", confidence: 0, waveform: []) }
        let hop = max(1, Int(sampleRate / 100))
        var energy = [Double]()
        var waveform = [Float]()
        let width = max(1, samples.count / 160)
        for start in stride(from: 0, to: samples.count, by: width) {
            waveform.append(samples[start..<min(start + width, samples.count)].map { abs($0) }.max() ?? 0)
        }
        for start in stride(from: 0, to: samples.count - hop, by: hop) {
            energy.append(samples[start..<start+hop].reduce(0) { $0 + Double($1 * $1) } / Double(hop))
        }
        let onset = energy.indices.map { i in max(0, energy[i] - (i > 0 ? energy[i-1] : 0)) }
        let envelopeRate = sampleRate / Double(hop)
        var best = 0.0, lag = Int(envelopeRate * 0.5)
        for l in Int(envelopeRate * 60 / 180)...Int(envelopeRate * 60 / 70) where l < onset.count {
            let value = (l..<onset.count).reduce(0.0) { $0 + onset[$1] * onset[$1-l] } / Double(onset.count-l)
            if value > best { best = value; lag = l }
        }
        // Sparse chroma sampling with Hann-windowed Goertzel bins; approximate key, never authoritative.
        var chroma = [Double](repeating: 0, count: 12)
        let n = 2048
        for start in stride(from: 0, to: samples.count-n, by: max(n, samples.count/40)) {
            for midi in 48...83 {
                let frequency = 440 * pow(2, Double(midi-69)/12)
                let coefficient = 2 * cos(2 * .pi * frequency / sampleRate)
                var a = 0.0, b = 0.0
                for i in 0..<n {
                    let x = Double(samples[start+i]) * (0.5 - 0.5*cos(2 * .pi * Double(i)/Double(n-1)))
                    let c = x + coefficient*a - b; b = a; a = c
                }
                chroma[midi%12] += max(0, a*a+b*b-coefficient*a*b)
            }
        }
        let major = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
        let minor = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]
        var score = -Double.infinity, key = "Unknown"
        let names = ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"]
        let mean = chroma.reduce(0,+)/12
        for tonic in 0..<12 {
            for (profile, suffix) in [(major,"major"),(minor,"minor")] {
                let pm = profile.reduce(0,+)/12
                let v = (0..<12).reduce(0.0) { $0 + (chroma[($1+tonic)%12]-mean)*(profile[$1]-pm) }
                if v > score { score = v; key = names[tonic]+" "+suffix }
            }
        }
        let power = onset.reduce(0) { $0+$1*$1 } / Double(max(1,onset.count))
        return Analysis(bpm: 60*envelopeRate/Double(lag), key: mean > 0.000001 ? key : "Unknown", confidence: power > 0 ? min(1,best/power) : 0, waveform: waveform)
    }
    public static func gains(_ crossfader: Double) -> (Double, Double) {
        let x = min(1,max(0,crossfader)); return (cos(x * .pi/2), sin(x * .pi/2))
    }
    public static func beatSeconds(bpm: Double, beats: Int) -> Double { 60 / max(40,bpm) * Double(beats) }
    public static func edit(_ samples: [Float], reverse: Bool, fadeFrames: Int) -> [Float] {
        var out = reverse ? Array(samples.reversed()) : samples
        let n = min(fadeFrames,out.count/2)
        if n > 0 { for i in 0..<n { let g = Float(i)/Float(n); out[i] *= g; out[out.count-1-i] *= g } }
        return out
    }
}
public struct CoachPlan: Codable, Sendable {
    public var title: String
    public var steps: [String]
    public var caution: String
    public init(title: String, steps: [String], caution: String) { self.title=title; self.steps=steps; self.caution=caution }
    public static func offline(a: Analysis, b: Analysis, mashup: Bool) -> CoachPlan {
        let change = (a.bpm/b.bpm-1)*100
        return CoachPlan(title: mashup ? "Build a phrase-aligned mashup" : "A clean 16-bar blend", steps: [String(format:"Match deck B to %.1f BPM (%+.1f%%). Listen for half/double-time ambiguity.",a.bpm,change), "Set both cue points on a downbeat. Count 1–2–3–4 for eight bars before entering B.", mashup ? "Loop four beats on B. Keep one bass line at a time; bring the hook in over eight bars." : "Start B at the next phrase. Ease the crossfader over sixteen bars.", "Swap the bass gradually, then fade A. Record what sounded crowded and repeat."], caution: "Estimated keys: \(a.key) / \(b.key). Check by ear. Use only audio you have permission to edit.")
    }
}
