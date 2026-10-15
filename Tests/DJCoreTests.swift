import XCTest
import AVFoundation
@testable import DJCore
final class DJCoreTests: XCTestCase {
    func testMonoLoopConvertedToStereoPlayerFormat() throws {
        let mono=AVAudioFormat(standardFormatWithSampleRate:22050,channels:1)!
        let stereo=AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
        let input=AVAudioPCMBuffer(pcmFormat:mono,frameCapacity:22050)!
        input.frameLength=22050
        for i in 0..<22050 {input.floatChannelData![0][i]=Float(sin(Double(i)*0.1))*0.3}
        let output=try AudioConversion.convert(input,to:stereo)
        XCTAssertEqual(output.format.channelCount,2)
        XCTAssertEqual(output.format.sampleRate,44100)
        XCTAssertGreaterThan(output.frameLength,43000)
        XCTAssertEqual(output.floatChannelData![0][1000],output.floatChannelData![1][1000],accuracy:0.001)
    }
    func testTempoOnSyntheticKick() {
        let rate = 8000.0
        let s = (0..<Int(rate*12)).map { i -> Float in
            let t = Double(i)/rate; let phase = t.truncatingRemainder(dividingBy: 0.5)
            return Float(sin(2 * .pi * 70 * t) * exp(-phase*50))
        }
        let a = DSP.analyze(s, sampleRate: rate)
        XCTAssertEqual(a.bpm,120,accuracy:3); XCTAssertGreaterThan(a.confidence,0.3)
        XCTAssertFalse(a.waveform.isEmpty)
    }
    func testSilenceDoesNotClaimKey() { XCTAssertEqual(DSP.analyze([Float](repeating:0,count:16000),sampleRate:8000).key,"Unknown") }
    func testCrossfadeHasConstantPowerAndClamps() {
        for x in [0.0,0.25,0.5,0.75,1] { let (a,b)=DSP.gains(x); XCTAssertEqual(a*a+b*b,1,accuracy:0.0001) }
        XCTAssertEqual(DSP.gains(-2).0,1); XCTAssertEqual(DSP.gains(2).1,1)
    }
    func testEditsAndPhraseTiming() {
        XCTAssertEqual(DSP.edit([1,2,3],reverse:true,fadeFrames:0),[3,2,1])
        XCTAssertEqual(DSP.beatSeconds(bpm:120,beats:64),32)
        XCTAssertEqual(DSP.edit([1,1,1,1],reverse:false,fadeFrames:2).first,0)
    }
}
