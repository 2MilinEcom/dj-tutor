#if DEBUG
import Foundation
import AVFoundation

@MainActor enum BoardAcceptance {
    private static var hasRun=false
    static func run(lab:AudioLab,library:LibraryStore,coach:CoachService) async {
        guard !hasRun else {return}
        hasRun=true
        var results:[String:Bool]=[:]
        var details:[String:String]=[:]
        do {
            for i in 0...1 {
                let generated=try await Task.detached(priority:.userInitiated){try AudioLab.demo(i)}.value
                let t=library.tracks.first(where:{$0.filename==generated.filename}) ?? generated
                if !library.tracks.contains(where:{$0.id==t.id}){library.tracks.append(t)}
                lab.load(t,deck:i);lab.bpmOverrides[i]=i==0 ? 120 : 124
            }
            library.save()
            var legacy=(try JSONSerialization.jsonObject(with:JSONEncoder().encode(lab.loaded[0]!))) as! [String:Any]
            legacy.removeValue(forKey:"hotCues")
            let oldTrack=try JSONDecoder().decode(LocalTrack.self,from:JSONSerialization.data(withJSONObject:legacy))
            results["legacyLibrary"]=oldTrack.hotCues == nil
            try await lab.sync(1)
            results["tempoMatch"]=abs(lab.baseBPM(1)*Double(lab.rates[1].rate)-120)<0.01
            lab.gridOrigins[0]=0.1;lab.quantize=true
            results["gridSnap"]=abs(lab.snapped(0,0.78)-0.6)<0.001
            lab.gridOrigins[0]=0
            lab.setEQ(0,band:0,value:-12);lab.toggleEQKill(0,band:0)
            results["eqKill"]=lab.filters[0].bands[1].gain == -96
            lab.toggleEQKill(0,band:0)
            results["eqRestore"]=lab.filters[0].bands[1].gain == -12
            lab.setEQ(0,band:0,value:0)
            lab.setFilter(1,value:-0.5)
            results["lowPass"]=lab.filters[1].bands[0].filterType == .lowPass && lab.filters[1].bands[0].frequency < 20000
            lab.setFilter(1,value:0.4)
            results["highPass"]=lab.filters[1].bands[0].filterType == .highPass && lab.filters[1].bands[0].frequency > 20
            lab.setFilter(1,value:0)
            lab.setEcho(1,value:10);lab.setReverb(1,value:10)
            results["effects"]=lab.delays[1].wetDryMix == 10 && lab.reverbs[1].wetDryMix == 10
            lab.channelVolumes[0]=0.5;lab.crossfade=0
            results["channelFader"]=abs(lab.players[0].volume-0.5)<0.001 && lab.players[1].volume<0.001
            lab.channelVolumes[0]=1;lab.crossfade=0.5
            library.setHotCue(lab.loaded[0]!.id,slot:7,at:1)
            let restored=LibraryStore()
            results["persistedHotCue"]=restored.tracks.first(where:{$0.id==lab.loaded[0]?.id})?.hotCues?["7"] == 1
            try await lab.startRecording()
            try await lab.play(0,from:0,loop:true)
            try await lab.play(1,from:0,loop:true)
            try await Task.sleep(nanoseconds:700_000_000)
            // Read the render clock directly so a busy simulator UI does not make the check depend on timer delivery.
            for _ in 0..<10 {
                lab.tick()
                if lab.positions.allSatisfy({$0 > 0}) {break}
                try await Task.sleep(nanoseconds:100_000_000)
            }
            results["playback"]=lab.playing.allSatisfy{$0} && lab.players.allSatisfy{$0.isPlaying} && lab.positions.allSatisfy{$0 > 0}
            details["playheads"]=String(describing:lab.positions)
            try await Task.sleep(nanoseconds:1_700_000_000)
            lab.tick()
            results["loopWrap"]=lab.playing.allSatisfy{$0} && lab.positions[0] < 2.05
            try await lab.jump(0,beats:8)
            results["beatJump"]=lab.positions[0] >= 4
            try await lab.seek(1,to:6)
            results["jogSeek"]=lab.positions[1] >= 6
            try await Task.sleep(nanoseconds:800_000_000)
            try lab.finishRecording()
            if let url=lab.recordingURL {
                let file=try AVAudioFile(forReading:url)
                let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(min(file.length,48000)))!
                try file.read(into:buffer)
                var peak:Float=0
                if let samples=buffer.floatChannelData {for i in 0..<Int(buffer.frameLength){peak=max(peak,abs(samples[0][i]))}}
                results["mixRecording"]=file.length>0 && peak>0.001
                details["recordingSeconds"]=String(Double(file.length)/file.processingFormat.sampleRate)
                details["recordingPeak"]=String(peak)
            }
            var a=lab.loaded[0]!.analysis,b=lab.loaded[1]!.analysis
            a.bpm=lab.baseBPM(0)*lab.tempoRates[0];b.bpm=lab.baseBPM(1)*lab.tempoRates[1]
            await coach.generate(a:a,b:b,mashup:false,cloud:true)
            results["liveAICoach"]=coach.error == nil && coach.source.hasPrefix("AI coach") && (coach.plan?.steps.count ?? 0)>0
            if let error=coach.error{details["coachError"]=error}
            details["coachTitle"]=coach.plan?.title ?? ""
            lab.stopAll()
            lab.loops=[false,false];lab.positions=[0,0];lab.offsets=[0,0]
            lab.setEcho(1,value:0);lab.setReverb(1,value:0)
        }catch{details["error"]=error.localizedDescription;lab.stopAll();if lab.recording{try? lab.finishRecording()}}
        let report:[String:Any]=["checks":results,"details":details,"passed":!results.isEmpty && results.values.allSatisfy{$0} && details["error"] == nil]
        let url=LibraryStore.directory.deletingLastPathComponent().appendingPathComponent("board-acceptance.json")
        if let data=try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]){try? data.write(to:url)}
    }
}
#endif
