import AVFoundation
import SwiftUI

@MainActor final class AudioLab: ObservableObject {
    let engine = AVAudioEngine()
    let players = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    let rates = [AVAudioUnitTimePitch(), AVAudioUnitTimePitch()]
    let filters = [AVAudioUnitEQ(numberOfBands:4), AVAudioUnitEQ(numberOfBands:4)]
    let delays = [AVAudioUnitDelay(), AVAudioUnitDelay()]
    let reverbs = [AVAudioUnitReverb(), AVAudioUnitReverb()]
    @Published var channelVolumes = [1.0,1.0] { didSet { updateGains() } }
    @Published var masterVolume = 0.7 { didSet { engine.mainMixerNode.outputVolume=Float(masterVolume) } }
    @Published var eq = [[0.0,0.0,0.0],[0.0,0.0,0.0]]
    @Published var eqKills = [[false,false,false],[false,false,false]]
    @Published var filterAmounts = [0.0,0.0]
    @Published var echoAmounts = [0.0,0.0]
    @Published var reverbAmounts = [0.0,0.0]
    @Published var tempoRates = [1.0,1.0]
    @Published var bpmOverrides = [0.0,0.0]
    @Published var gridOrigins = [0.0,0.0]
    @Published var quantize = true
    @Published var loopBeats = [4,4]
    @Published var loops = [false,false]
    @Published var levels = [Float](repeating:0,count:2)
    @Published var recording = false
    @Published var recordingSeconds = 0.0
    @Published var recordingURL: URL?
    @Published var recordings: [URL] = []
    private let recorder = MixRecorder()
    private var meterInstalled = false
    private var recordingStarted: Date?
    private var loopSpans = [0.0,0.0]
    @Published var loaded: [LocalTrack?] = [nil,nil]
    @Published var playing = [false,false]
    @Published var positions = [0.0,0.0]
    @Published var crossfade = 0.5 { didSet { updateGains() } }
    var offsets = [0.0,0.0]
    var timer: Timer?
    var sessionReady=false
    var companionActive=false
    var sessionSetup:Task<Void,Error>?
    init() {
        for i in 0...1 {
            for node in [players[i] as AVAudioNode,rates[i],filters[i],delays[i],reverbs[i]] { engine.attach(node) }
            engine.connect(players[i],to:rates[i],format:nil)
            engine.connect(rates[i],to:filters[i],format:nil)
            engine.connect(filters[i],to:delays[i],format:nil)
            engine.connect(delays[i],to:reverbs[i],format:nil)
            engine.connect(reverbs[i],to:engine.mainMixerNode,format:nil)
            filters[i].bands[0].filterType = .highPass; filters[i].bands[0].frequency=20; filters[i].bands[0].bypass=false
            for (band,frequency,type) in [(1,100.0,AVAudioUnitEQFilterType.lowShelf),(2,1000.0,.parametric),(3,10000.0,.highShelf)] {
                filters[i].bands[band].filterType=type
                filters[i].bands[band].frequency=Float(frequency)
                filters[i].bands[band].bandwidth=1
                filters[i].bands[band].bypass=false
            }
            reverbs[i].loadFactoryPreset(.mediumHall); reverbs[i].wetDryMix=0
            delays[i].wetDryMix=0; delays[i].feedback=25
        }
        engine.mainMixerNode.outputVolume=0.7
        updateGains()
        refreshRecordings()
        recordingURL=recordings.first
        timer=Timer(timeInterval:0.05,repeats:true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer {RunLoop.main.add(timer,forMode:.common)}
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.stopAll();self?.sessionReady=false } }
    }
    func updateGains() { let (a,b)=DSP.gains(crossfade); players[0].volume=Float(a*channelVolumes[0]); players[1].volume=Float(b*channelVolumes[1]) }
    func stopAll() { for i in 0...1 { players[i].stop(); playing[i]=false } }
    func yieldAudioToDjay() {
        companionActive = true
        stopAll()
        if recording { try? finishRecording() }
        engine.stop()
        // The companion is silent: release our former exclusive playback session.
        if sessionReady {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionReady = false
        }
    }
    func tick() {
        if let start=recordingStarted { recordingSeconds=Date().timeIntervalSince(start) }
        for i in 0...1 where playing[i] {
            if let time=players[i].lastRenderTime, let pt=players[i].playerTime(forNodeTime:time) {
                let elapsed=Double(pt.sampleTime)/pt.sampleRate
                let span=loops[i] ? loopSpans[i] : (loaded[i]?.duration ?? 0)-offsets[i]
                positions[i]=offsets[i]+(loops[i] && span > 0 ? elapsed.truncatingRemainder(dividingBy:span) : elapsed)
                if !loops[i] && positions[i] >= (loaded[i]?.duration ?? 0) { players[i].stop(); playing[i]=false; positions[i]=loaded[i]?.duration ?? 0 }
            }
        }
    }
    func load(_ track: LocalTrack, deck: Int) { players[deck].stop(); playing[deck]=false; positions[deck]=0; loaded[deck]=track; rates[deck].rate=1; tempoRates[deck]=1; loops[deck]=false; bpmOverrides[deck]=0; gridOrigins[deck]=0
        for band in 0..<3 { eqKills[deck][band]=false; setEQ(deck,band:band,value:0) }
        setFilter(deck,value:0); setEcho(deck,value:0); setReverb(deck,value:0) }
    func play(_ deck: Int, from: Double? = nil, loop: Bool? = nil) async throws {
        guard let track=loaded[deck] else { return }
        if from == nil && loop == nil && playing[deck] { players[deck].pause(); playing[deck]=false; return }
        try await prepareAudio()
        let f=try AVAudioFile(forReading:track.url)
        let start=max(0,min(from ?? positions[deck],track.duration-0.01))
        if let loop { loops[deck]=loop }
        let frames=loops[deck] ? min(f.length-AVAudioFramePosition(start*f.processingFormat.sampleRate), AVAudioFramePosition(DSP.beatSeconds(bpm:baseBPM(deck),beats:loopBeats[deck])*f.processingFormat.sampleRate)) : f.length-AVAudioFramePosition(start*f.processingFormat.sampleRate)
        guard frames > 0 else { return }
        players[deck].stop(); offsets[deck]=start; positions[deck]=start
        if loops[deck] {
            guard let buffer=AVAudioPCMBuffer(pcmFormat:f.processingFormat,frameCapacity:AVAudioFrameCount(frames)) else {return}
            f.framePosition=AVAudioFramePosition(start*f.processingFormat.sampleRate); try f.read(into:buffer,frameCount:AVAudioFrameCount(frames))
            let outputFormat=players[deck].outputFormat(forBus:0)
            loopSpans[deck]=Double(buffer.frameLength)/buffer.format.sampleRate
            let playable=try AudioConversion.convert(buffer,to:outputFormat)
            players[deck].scheduleBuffer(playable,at:nil,options:.loops,completionHandler:nil)
        } else { players[deck].scheduleSegment(f,startingFrame:AVAudioFramePosition(start*f.processingFormat.sampleRate),frameCount:AVAudioFrameCount(frames),at:nil,completionHandler:nil) }
        players[deck].play(); playing[deck]=true
    }
    func prepareAudio() async throws {
        guard !companionActive else { throw AppError(message:"Open the local Studio or DJ Board before playing local audio.") }
        if !sessionReady {
            if sessionSetup == nil {
                sessionSetup=Task.detached(priority:.userInitiated) {
                    try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default)
                    try AVAudioSession.sharedInstance().setActive(true)
                }
            }
            do {try await sessionSetup!.value;sessionReady=true;sessionSetup=nil}
            catch {sessionSetup=nil;throw error}
        }
        if companionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionReady = false
            throw AppError(message:"Local playback cancelled while the djay coach is open.")
        }
        if !engine.isRunning {try engine.start()}
        if !meterInstalled {
            let writer=recorder
            engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil) { [weak self] buffer,_ in
                writer.consume(buffer)
                var peaks=[Float](repeating:0,count:2)
                if let channels=buffer.floatChannelData {
                    for c in 0..<min(2,Int(buffer.format.channelCount)) {
                        for i in stride(from:0,to:Int(buffer.frameLength),by:8) {peaks[c]=max(peaks[c],abs(channels[c][i]))}
                    }
                }
                let measured=peaks
                Task { @MainActor [weak self] in self?.levels=measured }
            }
            meterInstalled=true
        }
    }
    func baseBPM(_ deck:Int) -> Double { bpmOverrides[deck] > 0 ? bpmOverrides[deck] : loaded[deck]?.analysis.bpm ?? 120 }
    func setTempo(_ deck:Int,value:Double) {tempoRates[deck]=min(1.25,max(0.75,value));rates[deck].rate=Float(tempoRates[deck])}
    func setEQ(_ deck:Int,band:Int,value:Double) {
        eq[deck][band]=value
        filters[deck].bands[band+1].gain=Float(eqKills[deck][band] ? -96 : value)
    }
    func toggleEQKill(_ deck:Int,band:Int) {eqKills[deck][band].toggle();setEQ(deck,band:band,value:eq[deck][band])}
    func setFilter(_ deck:Int,value:Double) {
        filterAmounts[deck]=value
        let band=filters[deck].bands[0]
        band.filterType=value < 0 ? .lowPass : .highPass
        band.frequency=Float(value < 0 ? 20000*pow(0.015,-value) : 20*pow(500,value))
    }
    func setEcho(_ deck:Int,value:Double) {echoAmounts[deck]=value;delays[deck].wetDryMix=Float(value);delays[deck].delayTime=60/(baseBPM(deck)*tempoRates[deck])/2}
    func setReverb(_ deck:Int,value:Double) {reverbAmounts[deck]=value;reverbs[deck].wetDryMix=Float(value)}
    func snapped(_ deck:Int,_ position:Double) -> Double {
        guard let track=loaded[deck] else {return 0}
        let beat=60/baseBPM(deck), origin=gridOrigins[deck]
        let target=quantize ? origin+((position-origin)/beat).rounded()*beat : position
        return min(max(0,target),max(0,track.duration-0.01))
    }
    func seek(_ deck:Int,to position:Double,snap:Bool=false) async throws {
        let target=snap ? snapped(deck,position) : min(max(0,position),max(0,(loaded[deck]?.duration ?? 0)-0.01))
        if playing[deck] {try await play(deck,from:target)} else {positions[deck]=target; offsets[deck]=target}
    }
    func jump(_ deck:Int,beats:Int) async throws {try await seek(deck,to:positions[deck]+Double(beats)*60/baseBPM(deck),snap:true)}
    func toggleLoop(_ deck:Int,beats:Int?=nil) async throws {
        guard loaded[deck] != nil else {return}
        let newState=beats == nil ? !loops[deck] : true
        if let beats {loopBeats[deck]=beats}
        let wasPlaying=playing[deck]
        try await play(deck,from:snapped(deck,positions[deck]),loop:newState)
        if !wasPlaying {players[deck].pause();playing[deck]=false}
    }
    func sync(_ deck:Int) async throws {
        let master=1-deck
        guard loaded[deck] != nil, loaded[master] != nil else {throw AppError(message:"Load both decks to match tempo and beat phase.")}
        let ratio=baseBPM(master)*Double(rates[master].rate)/baseBPM(deck)
        guard (0.75...1.25).contains(ratio) else {throw AppError(message:"These tempos are outside the ±25% range. Adjust the BPM estimate first.")}
        setTempo(deck,value:ratio)
        let masterBeat=(positions[master]-gridOrigins[master])*baseBPM(master)/60
        let phase=masterBeat-floor(masterBeat)
        let beat=60/baseBPM(deck)
        let beatIndex=((positions[deck]-gridOrigins[deck])/beat-phase).rounded()
        try await seek(deck,to:gridOrigins[deck]+(beatIndex+phase)*beat)
    }
    func startRecording() async throws {
        try await prepareAudio()
        let directory=LibraryStore.directory.deletingLastPathComponent().appendingPathComponent("Recordings",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let stamp=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
        let url=directory.appendingPathComponent("DJ-TUT-Mix-\(stamp)-\(UUID().uuidString.prefix(4)).wav")
        try recorder.start(url,format:engine.mainMixerNode.outputFormat(forBus:0))
        recordingStarted=Date();recordingSeconds=0;recordingURL=nil;recording=true
    }
    func finishRecording() throws {
        recording=false;recordingStarted=nil
        recordingURL=try recorder.finish()
        refreshRecordings()
    }
    func refreshRecordings() {
        let directory=LibraryStore.directory.deletingLastPathComponent().appendingPathComponent("Recordings",isDirectory:true)
        recordings=((try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.creationDateKey])) ?? []).filter{$0.pathExtension=="wav"}.sorted{$0.lastPathComponent>$1.lastPathComponent}
    }
    nonisolated static func importFile(_ source: URL) throws -> LocalTrack {
        let access=source.startAccessingSecurityScopedResource(); defer { if access {source.stopAccessingSecurityScopedResource()} }
        let file=try AVAudioFile(forReading:source)
        let duration=Double(file.length)/file.processingFormat.sampleRate
        guard duration > 1, duration <= 600 else { throw AppError(message:"Choose a playable audio file between 1 second and 10 minutes.") }
        let name=UUID().uuidString+"."+source.pathExtension
        let dest=LibraryStore.directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at:source,to:dest)
        do {
            // Analyze first 90 seconds; block reads avoid holding an entire track in memory.
            let count=AVAudioFrameCount(min(file.length,AVAudioFramePosition(file.processingFormat.sampleRate*90)))
            guard let b=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:count) else {throw AppError(message:"Cannot decode this file.")}
            try file.read(into:b,frameCount:count)
            guard let channels=b.floatChannelData else {throw AppError(message:"Unsupported protected audio.")}
            let step=max(1,Int(file.processingFormat.sampleRate/11025))
            var samples=[Float](); samples.reserveCapacity(Int(b.frameLength)/step)
            for i in stride(from:0,to:Int(b.frameLength),by:step) {
                var x:Float=0; for c in 0..<Int(b.format.channelCount) {x+=channels[c][i]}; samples.append(x/Float(b.format.channelCount))
            }
            return LocalTrack(title:source.deletingPathExtension().lastPathComponent,filename:name,analysis:DSP.analyze(samples,sampleRate:file.processingFormat.sampleRate/Double(step)),duration:duration)
        } catch {try? FileManager.default.removeItem(at:dest); throw error}
    }
    nonisolated static func demo(_ index: Int) throws -> LocalTrack {
        let rate=22050.0, bpm=index==0 ? 120.0 : 124.0
        let url=LibraryStore.directory.appendingPathComponent("Practice-\(index).wav")
        let format=AVAudioFormat(standardFormatWithSampleRate:rate,channels:1)!
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(rate*32))!
        buffer.frameLength=buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) {
            let t=Double(i)/rate, p=t.truncatingRemainder(dividingBy:60/bpm)
            let kick=sin(2 * .pi * 65 * t)*exp(-p*35)
            let bass=sin(2 * .pi * (index==0 ? 130.81 : 164.81)*t)*0.15
            buffer.floatChannelData![0][i]=Float(kick*0.65+bass)
        }
        let out=try AVAudioFile(forWriting:url,settings:format.settings); try out.write(from:buffer)
        return LocalTrack(title:index==0 ? "Neon pulse · original demo" : "Afterhours · original demo",filename:url.lastPathComponent,analysis:DSP.analyze(Array(UnsafeBufferPointer(start:buffer.floatChannelData![0],count:Int(buffer.frameLength))),sampleRate:rate),duration:32)
    }
    nonisolated static func export(_ track: LocalTrack, start: Double, reverse: Bool, repeatBeat: Bool) throws -> URL {
        let f=try AVAudioFile(forReading:track.url), rate=f.processingFormat.sampleRate
        f.framePosition=AVAudioFramePosition(max(0,min(start,track.duration-0.1))*rate)
        let frames=AVAudioFrameCount(min(f.length-f.framePosition,AVAudioFramePosition(DSP.beatSeconds(bpm:track.analysis.bpm,beats:repeatBeat ? 1 : 16)*rate)))
        let b=AVAudioPCMBuffer(pcmFormat:f.processingFormat,frameCapacity:frames)!
        try f.read(into:b,frameCount:frames)
        let repeats=repeatBeat ? 16 : 1
        let result=AVAudioPCMBuffer(pcmFormat:f.processingFormat,frameCapacity:b.frameLength*UInt32(repeats))!
        result.frameLength=result.frameCapacity
        for c in 0..<Int(b.format.channelCount) {
            let input=Array(UnsafeBufferPointer(start:b.floatChannelData![c],count:Int(b.frameLength)))
            let edited=DSP.edit(input,reverse:reverse,fadeFrames:Int(rate*0.008))
            for r in 0..<repeats {for i in edited.indices {result.floatChannelData![c][r*edited.count+i]=edited[i]*0.8}}
        }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("DJTutor-\(UUID().uuidString).wav")
        let out=try AVAudioFile(forWriting:url,settings:f.processingFormat.settings); try out.write(from:result); return url
    }
}

// Audio tap and UI access share only this locked recorder, never the app's state.
final class MixRecorder: @unchecked Sendable {
    private let lock=NSLock()
    private var file:AVAudioFile?
    private var url:URL?
    private var failure:Error?
    func start(_ url:URL,format:AVAudioFormat) throws {
        let output=try AVAudioFile(forWriting:url,settings:format.settings)
        lock.lock();defer{lock.unlock()};file=output;self.url=url;failure=nil
    }
    func consume(_ buffer:AVAudioPCMBuffer) {
        lock.lock();defer{lock.unlock()}
        guard let file else {return}
        do {try file.write(from:buffer)} catch {failure=error;self.file=nil}
    }
    func finish() throws -> URL? {
        lock.lock();defer{lock.unlock()};file=nil
        if let failure {throw failure};return url
    }
}
