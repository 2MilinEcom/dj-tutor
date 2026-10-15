import SwiftUI
import UniformTypeIdentifiers

private let boardInk = Color(red:0.035,green:0.043,blue:0.065)
private let boardPanel = Color(red:0.075,green:0.085,blue:0.115)
private let boardLine = Color.white.opacity(0.09)
private let deckColors: [Color] = [Color(red:0.15,green:0.91,blue:0.84),Color(red:0.72,green:0.46,blue:1)]

struct DJBoard: View {
    @EnvironmentObject var lab:AudioLab
    @EnvironmentObject var library:LibraryStore
    @State var libraryOpen=false
    @State var loadingDeck=0
    @State var error:String?
    @State var demoBusy=false
    @State var showCoach=true
    @State var recordingsOpen=false
    @StateObject var coach=CoachService()
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing:0) {
                header
                ScrollView {
                    VStack(spacing:14) {
                        HStack(spacing:14) { overview(0); overview(1) }
                        if geometry.size.width >= 850 {
                            HStack(alignment:.top,spacing:14) {
                                ConsoleDeck(deck:0,compact:geometry.size.height<950,load:{openLibrary(0)},onError:{error=$0})
                                ConsoleMixer(compact:geometry.size.height<950).frame(width:210)
                                ConsoleDeck(deck:1,compact:geometry.size.height<950,load:{openLibrary(1)},onError:{error=$0})
                            }
                        } else {
                            HStack(alignment:.top,spacing:14) {
                                ConsoleDeck(deck:0,compact:geometry.size.height<950,load:{openLibrary(0)},onError:{error=$0})
                                ConsoleDeck(deck:1,compact:geometry.size.height<950,load:{openLibrary(1)},onError:{error=$0})
                            }
                            ConsoleMixer()
                        }
                        if showCoach { BoardCoach(coach:coach) }
                        if let error {Label(error,systemImage:"exclamationmark.triangle").font(.caption).foregroundStyle(.orange).frame(maxWidth:.infinity,alignment:.leading)}
                    }.padding(18)
                }
            }.background(boardInk)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["DJTUT_VALIDATE_BOARD"] == "1" {await BoardAcceptance.run(lab:lab,library:library,coach:coach)}
            #endif
        }
        .sheet(isPresented:$recordingsOpen) { RecordedMixes() }
        .sheet(isPresented:$libraryOpen) { BoardLibrary(deck:loadingDeck) }
        .alert("Studio",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})) {Button("OK"){error=nil}} message:{Text(error ?? "")}
    }
    var header:some View {
        HStack(spacing:14) {
            HStack(spacing:8) {Image(systemName:"waveform.path").font(.title2).foregroundStyle(.mint);Text("DJ TUT").font(.system(size:22,weight:.black,design:.rounded))}
            Text("PERFORMANCE STUDIO").font(.system(size:9,weight:.bold)).tracking(2).foregroundStyle(.secondary)
            Spacer()
            Button {Task{await loadDemos()}} label:{Label(demoBusy ? "Loading…" : "Demo set",systemImage:"sparkles")}.disabled(demoBusy)
            Button {showCoach.toggle()} label:{Label("Coach",systemImage:"graduationcap.fill")}.tint(showCoach ? .mint : .gray)
            Toggle("Quantize",isOn:$lab.quantize).toggleStyle(.button).font(.caption)
            Button {Task{do{if lab.recording{try lab.finishRecording()}else{try await lab.startRecording()}}catch{self.error=error.localizedDescription}}} label:{
                HStack(spacing:6){Circle().fill(lab.recording ? Color.red : Color.white.opacity(0.4)).frame(width:8,height:8);Text(lab.recording ? String(format:"STOP %02d:%02d",Int(lab.recordingSeconds)/60,Int(lab.recordingSeconds)%60) : "REC")}
            }.tint(lab.recording ? .red : .white)
            Button {lab.refreshRecordings();recordingsOpen=true} label:{Image(systemName:"waveform.badge.mic")}.accessibilityLabel("Saved mix recordings")
            if let url=lab.recordingURL {ShareLink(item:url){Image(systemName:"square.and.arrow.up")}.accessibilityLabel("Share recorded mix")}
        }.font(.system(size:12,weight:.semibold)).buttonStyle(.bordered).padding(.horizontal,20).padding(.vertical,14).background(boardPanel)
    }
    func overview(_ deck:Int) -> some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {Text("DECK \(deck==0 ? "A" : "B")").font(.system(size:9,weight:.bold)).tracking(2).foregroundStyle(deckColors[deck]);Spacer();Text("LOCAL AUDIO").font(.system(size:8,weight:.medium)).foregroundStyle(.secondary)}
            ConsoleWaveform(deck:deck,height:42)
        }.padding(12).background(boardPanel,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(boardLine))
    }
    func openLibrary(_ deck:Int) {loadingDeck=deck;libraryOpen=true}
    func loadDemos() async {
        demoBusy=true;defer{demoBusy=false}
        do {
            for i in 0...1 {
                let track:LocalTrack
                if let existing=library.tracks.first(where:{$0.filename=="Practice-\(i).wav"}) {track=existing}
                else {track=try await Task.detached(priority:.userInitiated){try AudioLab.demo(i)}.value;library.tracks.append(track)}
                lab.load(track,deck:i)
                lab.bpmOverrides[i]=i==0 ? 120 : 124
            }
            library.save()
        }catch{self.error=error.localizedDescription}
    }
}

struct ConsoleDeck:View {
    @EnvironmentObject var lab:AudioLab
    @EnvironmentObject var library:LibraryStore
    let deck:Int
    var compact=false
    let load:()->Void
    let onError:(String)->Void
    @State var padMode=0
    @State var jogStart:Double?
    @State var jogWasPlaying=false
    @State var bpmEditor=false
    @State var bpmText=""
    var color:Color {deckColors[deck]}
    var track:LocalTrack? {lab.loaded[deck]}
    var savedTrack:LocalTrack? {library.tracks.first(where:{$0.id==track?.id})}
    var body:some View {
        VStack(spacing:compact ? 9 : 14) {
            trackHeader
            ConsoleWaveform(deck:deck,height:compact ? 35 : 52)
            HStack(spacing:10) {
                Button {action{try await lab.sync(deck)}} label:{Text("SYNC").font(.system(size:11,weight:.heavy)).frame(width:48)}.disabled(track==nil || lab.loaded[1-deck]==nil)
                Button {bpmText=String(format:"%.1f",lab.baseBPM(deck));bpmEditor=true} label:{VStack(spacing:2){Text(String(format:"%.1f",lab.baseBPM(deck)*lab.tempoRates[deck])).font(.system(size:21,weight:.bold,design:.monospaced));Text("BPM · EDIT GRID").font(.system(size:7,weight:.semibold)).foregroundStyle(.secondary)}}.buttonStyle(.plain)
                Spacer()
                Text(String(format:"%+.1f%%",(lab.tempoRates[deck]-1)*100)).font(.system(size:12,weight:.medium,design:.monospaced)).foregroundStyle(color)
            }
            HStack(spacing:6){Button("−"){lab.setTempo(deck,value:lab.tempoRates[deck]-0.005)};Slider(value:Binding(get:{lab.tempoRates[deck]},set:{lab.setTempo(deck,value:$0)}),in:0.75...1.25).accessibilityLabel("Deck \(deck+1) tempo");Button("+"){lab.setTempo(deck,value:lab.tempoRates[deck]+0.005)};Button("0% "){lab.setTempo(deck,value:1)}}.font(.caption).disabled(track==nil)
            turntable
            HStack(spacing:10) {
                Button {action{try await lab.play(deck)}} label:{Image(systemName:lab.playing[deck] ? "pause.fill" : "play.fill").font(.title3).frame(width:46,height:38)}.tint(color).buttonStyle(.borderedProminent).accessibilityLabel("\(lab.playing[deck] ? "Pause" : "Play") deck \(deck+1)")
                Button("CUE") {action{try await lab.seek(deck,to:savedTrack?.hotCues?["0"] ?? 0)}}
                Button("SET") {if let track {library.setHotCue(track.id,slot:0,at:lab.snapped(deck,lab.positions[deck]))}}
                Spacer()
                Button {action{try await lab.toggleLoop(deck)}} label:{Label("\(lab.loopBeats[deck])",systemImage:"repeat")}.tint(lab.loops[deck] ? color : .gray)
            }.font(.system(size:11,weight:.bold)).disabled(track==nil)
            Picker("Performance pads",selection:$padMode){Text("HOT CUES").tag(0);Text("LOOPS").tag(1);Text("BEAT JUMP").tag(2)}.pickerStyle(.segmented)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:7),count:4),spacing:7) {
                ForEach(0..<8,id:\.self){slot in pad(slot)}
            }.disabled(track==nil)
            HStack {Text(padMode==0 ? "Tap to set / launch · hold to replace" : padMode==1 ? "Loop lengths in beats · tap active pad to exit" : "Jump on your estimated beat grid").font(.system(size:9)).foregroundStyle(.secondary);Spacer()}
            HStack(spacing:14) {
                MiniKnob(label:"FILTER",value:Binding(get:{lab.filterAmounts[deck]},set:{lab.setFilter(deck,value:$0)}),range:-1...1,color:color,display:abs(lab.filterAmounts[deck])<0.01 ? "OFF" : lab.filterAmounts[deck]<0 ? "LP" : "HP")
                MiniKnob(label:"ECHO",value:Binding(get:{lab.echoAmounts[deck]},set:{lab.setEcho(deck,value:$0)}),range:0...40,color:color,display:String(format:"%.0f%%",lab.echoAmounts[deck]))
                MiniKnob(label:"REVERB",value:Binding(get:{lab.reverbAmounts[deck]},set:{lab.setReverb(deck,value:$0)}),range:0...50,color:color,display:String(format:"%.0f%%",lab.reverbAmounts[deck]))
            }.frame(maxWidth:.infinity).padding(.top,3)
        }.padding(16).background(boardPanel,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(color.opacity(0.18))).tint(color).buttonStyle(.bordered)
        .alert("Adjust beat grid",isPresented:$bpmEditor){TextField("BPM (40–240)",text:$bpmText).keyboardType(.decimalPad);Button("Apply"){if let value=Double(bpmText),(40...240).contains(value){lab.bpmOverrides[deck]=value}else{onError("Enter a BPM between 40 and 240.")}};Button("Set beat one here"){lab.gridOrigins[deck]=lab.positions[deck]};Button("Cancel",role:.cancel){}} message:{Text("Tempo and phrase timing are estimates. Set beat one on a downbeat and confirm by ear.")}
    }
    var trackHeader:some View {
        HStack(spacing:10) {
            ZStack {RoundedRectangle(cornerRadius:10).fill(LinearGradient(colors:[color.opacity(0.85),color.opacity(0.12),.black],startPoint:.topLeading,endPoint:.bottomTrailing));Image(systemName:"waveform").font(.title2).foregroundStyle(.white)}.frame(width:48,height:48)
            VStack(alignment:.leading,spacing:5){Text(track?.title ?? "Choose your next track").font(.system(size:15,weight:.bold)).lineLimit(1);HStack(spacing:10){Text(track?.analysis.key ?? "No track loaded");Text(timeRemaining).monospacedDigit()}.font(.system(size:10)).foregroundStyle(.secondary)}
            Spacer(minLength:0)
            Button(action:load){Image(systemName:"folder.badge.plus").font(.title3)}.buttonStyle(.plain).accessibilityLabel("Load deck \(deck+1)")
        }
    }
    var timeRemaining:String {let time=max(0,Int((track?.duration ?? 0)-lab.positions[deck]));return String(format:"−%02d:%02d",time/60,time%60)}
    var turntable:some View {
        GeometryReader { g in
            let diameter=min(g.size.width,g.size.height)
            ZStack {
                Circle().fill(.black).shadow(color:color.opacity(0.1),radius:16)
                Circle().stroke(Color.white.opacity(0.35),style:StrokeStyle(lineWidth:3,dash:[1,5])).padding(7)
                ForEach(0..<7,id:\.self){i in Circle().stroke(.white.opacity(0.045),lineWidth:1).padding(CGFloat(20+i*9))}
                Circle().fill(AngularGradient(colors:[.black,.white.opacity(0.11),.black,.white.opacity(0.06),.black],center:.center)).padding(16)
                Circle().stroke(color.opacity(0.3),lineWidth:1).padding(18)
                VStack(spacing:4){Text(deck==0 ? "A" : "B").font(.system(size:32,weight:.black,design:.rounded));Text("DJ TUT").font(.system(size:8,weight:.heavy)).tracking(2)}.frame(width:diameter*0.34,height:diameter*0.34).background(LinearGradient(colors:[color,color.opacity(0.4)],startPoint:.topLeading,endPoint:.bottomTrailing),in:Circle()).foregroundStyle(.black)
                Capsule().fill(color).frame(width:4,height:26).offset(y:-diameter/2+36).rotationEffect(.degrees(lab.positions[deck]*200))
                Circle().fill(.black).frame(width:8,height:8).overlay(Circle().stroke(.white.opacity(0.35)))
            }.frame(width:diameter,height:diameter).frame(maxWidth:.infinity,maxHeight:.infinity)
            .contentShape(Circle()).gesture(DragGesture(minimumDistance:2).onChanged{value in
                if jogStart==nil {jogStart=lab.positions[deck];jogWasPlaying=lab.playing[deck];lab.players[deck].pause();lab.playing[deck]=false}
                lab.positions[deck]=min(max(0,(jogStart ?? 0)+Double(value.translation.width)/12),max(0,(track?.duration ?? 0)-0.01))
            }.onEnded{_ in let resume=jogWasPlaying;jogStart=nil;if resume{action{try await lab.play(deck,from:lab.positions[deck])}}})
            .accessibilityLabel("Deck \(deck+1) jog wheel. Drag horizontally to seek.")
            VStack {Spacer();HStack{Text(jogStart==nil ? "JOG · DRAG TO SEEK" : "SEEKING").font(.system(size:8,weight:.semibold)).tracking(1.5).foregroundStyle(.secondary);Spacer();Text(String(format:"%02d:%02d",Int(lab.positions[deck])/60,Int(lab.positions[deck])%60)).font(.system(size:10,design:.monospaced)).foregroundStyle(color)}}
        }.frame(height:compact ? 155 : 225)
    }
    func pad(_ slot:Int) -> some View {
        let lengths=[1,2,4,8,16,32,64,128]
        let jumps=[-16,-8,-4,-1,1,4,8,16]
        let cue=savedTrack?.hotCues?[String(slot)]
        let active=padMode==0 ? cue != nil : padMode==1 && lab.loops[deck] && lab.loopBeats[deck]==lengths[slot]
        return Button {action{
            if padMode==0 {if let cue{try await lab.play(deck,from:cue)}else if let track{library.setHotCue(track.id,slot:slot,at:lab.snapped(deck,lab.positions[deck]))}}
            else if padMode==1 {try await lab.toggleLoop(deck,beats:active ? nil : lengths[slot])}
            else {try await lab.jump(deck,beats:jumps[slot])}
        }} label:{VStack(spacing:3){Text(padMode==0 ? "\(slot+1)" : padMode==1 ? "\(lengths[slot])" : "\(jumps[slot]>0 ? "+" : "")\(jumps[slot])").font(.system(size:16,weight:.bold,design:.monospaced));Text(padMode==0 ? cue.map{String(format:"%.1fs",$0)} ?? "SET" : "BEATS").font(.system(size:7,weight:.semibold))}.frame(maxWidth:.infinity).frame(height:43).foregroundStyle(active ? .black : color).background(active ? color : color.opacity(0.1),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(color.opacity(active ? 0 : 0.25)))}.buttonStyle(.plain).highPriorityGesture(LongPressGesture(minimumDuration:0.6).onEnded{_ in if padMode==0,let track{library.setHotCue(track.id,slot:slot,at:lab.snapped(deck,lab.positions[deck]))}}).accessibilityLabel("Deck \(deck+1) \(padMode==0 ? "hot cue" : padMode==1 ? "loop" : "beat jump") \(slot+1)")
    }
    func action(_ work:@escaping ()async throws->Void){Task{do{try await work()}catch{onError(error.localizedDescription)}}}
}

struct MiniKnob:View {
    let label:String
    @Binding var value:Double
    let range:ClosedRange<Double>
    let color:Color
    let display:String
    @State var origin:Double?
    var fraction:Double {(value-range.lowerBound)/(range.upperBound-range.lowerBound)}
    var body:some View {
        VStack(spacing:5) {
            Text(label).font(.system(size:8,weight:.bold)).tracking(1).foregroundStyle(.secondary)
            ZStack {
                Circle().trim(from:0.12,to:0.88).stroke(Color.white.opacity(0.1),style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(90))
                Circle().trim(from:0.12,to:0.12+fraction*0.76).stroke(color,style:StrokeStyle(lineWidth:3,lineCap:.round)).rotationEffect(.degrees(90))
                Circle().fill(LinearGradient(colors:[Color.white.opacity(0.15),.black],startPoint:.topLeading,endPoint:.bottomTrailing)).padding(6).overlay(Circle().stroke(.white.opacity(0.06)).padding(6))
                Capsule().fill(.white).frame(width:2,height:10).offset(y:-13).rotationEffect(.degrees(-137+fraction*274))
            }.frame(width:49,height:49).contentShape(Circle()).gesture(DragGesture(minimumDistance:0).onChanged{g in if origin==nil{origin=value};value=min(range.upperBound,max(range.lowerBound,(origin ?? value)-Double(g.translation.height)*(range.upperBound-range.lowerBound)/140))}.onEnded{_ in origin=nil}).onTapGesture(count:2){value=range.contains(0) ? 0 : range.lowerBound}
            Text(display).font(.system(size:8,weight:.medium,design:.monospaced)).foregroundStyle(color)
        }.accessibilityElement(children:.ignore).accessibilityLabel(label).accessibilityValue(display).accessibilityAdjustableAction{direction in let step=(range.upperBound-range.lowerBound)/20;value=min(range.upperBound,max(range.lowerBound,value+(direction == .increment ? step : -step)))}
    }
}

struct ConsoleMixer:View {
    @EnvironmentObject var lab:AudioLab
    var compact=false
    var body:some View {
        VStack(spacing:compact ? 10 : 17) {
            HStack{Text("MIXER").font(.system(size:10,weight:.bold)).tracking(2);Spacer();Image(systemName:"slider.horizontal.3").foregroundStyle(.secondary)}
            HStack(alignment:.top,spacing:22) {channel(0);channel(1)}
            Divider().overlay(boardLine)
            HStack{Text("MASTER").font(.system(size:8,weight:.semibold));StereoMeter();Text(String(format:"%.0f%%",lab.masterVolume*100)).font(.system(size:9,design:.monospaced))}
            Slider(value:$lab.masterVolume,in:0...1).tint(.white).accessibilityLabel("Master volume")
            VStack(spacing:8){HStack{Text("A").foregroundStyle(deckColors[0]);Spacer();Text("CROSSFADE").font(.system(size:8)).foregroundStyle(.secondary);Spacer();Text("B").foregroundStyle(deckColors[1])};Slider(value:$lab.crossfade,in:0...1).tint(.mint).accessibilityLabel("Mixer crossfader")}
            Button("CENTER"){lab.crossfade=0.5}.font(.system(size:9,weight:.semibold)).buttonStyle(.bordered)
        }.padding(14).background(boardPanel,in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(boardLine))
    }
    func channel(_ deck:Int)->some View {
        VStack(spacing:compact ? 8 : 13) {
            Text(deck==0 ? "A" : "B").font(.system(size:12,weight:.heavy)).foregroundStyle(deckColors[deck])
            ForEach([2,1,0],id:\.self){band in VStack(spacing:3){MiniKnob(label:["LOW","MID","HIGH"][band],value:Binding(get:{lab.eq[deck][band]},set:{lab.setEQ(deck,band:band,value:$0)}),range:-24...12,color:deckColors[deck],display:String(format:"%+.0f dB",lab.eq[deck][band]));Button("KILL"){lab.toggleEQKill(deck,band:band)}.font(.system(size:7,weight:.heavy)).foregroundStyle(lab.eqKills[deck][band] ? .red : .secondary).buttonStyle(.plain)}}
            Slider(value:Binding(get:{lab.channelVolumes[deck]},set:{lab.channelVolumes[deck]=$0}),in:0...1).tint(deckColors[deck]).frame(width:compact ? 110 : 140).rotationEffect(.degrees(-90)).frame(width:40,height:compact ? 110 : 140).accessibilityLabel("Deck \(deck+1) channel volume")
            Text(String(format:"%.0f%%",lab.channelVolumes[deck]*100)).font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity)
    }
}
struct StereoMeter:View {
    @EnvironmentObject var lab:AudioLab
    var body:some View {VStack(spacing:2){ForEach(0..<2,id:\.self){c in GeometryReader{g in ZStack(alignment:.leading){Capsule().fill(.white.opacity(0.08));Capsule().fill(lab.levels[c]>0.95 ? Color.red : Color.mint).frame(width:g.size.width*CGFloat(min(1,lab.levels[c])))}}.frame(height:4)}}.frame(width:55).accessibilityLabel("Master output meter")}
}

struct ConsoleWaveform:View {
    @EnvironmentObject var lab:AudioLab
    let deck:Int
    let height:CGFloat
    var body:some View {
        GeometryReader{g in Canvas{context,size in
            guard let track=lab.loaded[deck],!track.analysis.waveform.isEmpty else {var line=Path();line.move(to:CGPoint(x:0,y:size.height/2));line.addLine(to:CGPoint(x:size.width,y:size.height/2));context.stroke(line,with:.color(.white.opacity(0.08)));return}
            let samples=track.analysis.waveform
            let analyzedDuration=min(90,track.duration)
            let current=min(1,lab.positions[deck]/analyzedDuration)
            let w=size.width/CGFloat(samples.count)
            for (i,sample) in samples.enumerated(){let amplitude=max(2,CGFloat(sample)*size.height);let rect=CGRect(x:CGFloat(i)*w,y:(size.height-amplitude)/2,width:max(1,w-1),height:amplitude);context.fill(Path(roundedRect:rect,cornerRadius:1),with:.linearGradient(Gradient(colors:[deckColors[deck],deckColors[deck].opacity(0.3)]),startPoint:CGPoint(x:0,y:0),endPoint:CGPoint(x:0,y:size.height)))}
            let beat=60/lab.baseBPM(deck)
            for b in stride(from:lab.gridOrigins[deck],to:analyzedDuration,by:beat*4) where b>=0 {let x=b/analyzedDuration*size.width;var p=Path();p.move(to:CGPoint(x:x,y:0));p.addLine(to:CGPoint(x:x,y:size.height));context.stroke(p,with:.color(.white.opacity(0.2)),lineWidth:0.5)}
            let x=current*size.width;var p=Path();p.move(to:CGPoint(x:x,y:0));p.addLine(to:CGPoint(x:x,y:size.height));context.stroke(p,with:.color(.white),lineWidth:2)
        }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onEnded{value in Task{try? await lab.seek(deck,to:Double(min(1,max(0,value.location.x/g.size.width)))*min(90,lab.loaded[deck]?.duration ?? 0),snap:true)}})}.frame(height:height).clipped().accessibilityLabel("Deck \(deck+1) overview waveform; first 90 seconds")
    }
}

struct BoardLibrary:View {
    @EnvironmentObject var library:LibraryStore
    @EnvironmentObject var lab:AudioLab
    @Environment(\.dismiss) var dismiss
    @State var importing=false
    @State var permitted=false
    @State var busy=false
    @State var error:String?
    let deck:Int
    var body:some View {NavigationStack{List {
        Section("Your sound"){Text("Load permitted local audio into deck \(deck==0 ? "A" : "B"). Spotify browsing is available in the Spotify tab.").font(.subheadline);Toggle("I have permission to use this audio",isOn:$permitted);Button("Import audio from Files",systemImage:"square.and.arrow.down"){importing=true}.disabled(!permitted || busy)}
        Section("Library"){ForEach(library.tracks){track in Button{lab.load(track,deck:deck);dismiss()}label:{HStack{Image(systemName:"waveform").foregroundStyle(deckColors[deck]);VStack(alignment:.leading){Text(track.title).foregroundStyle(.primary);Text(String(format:"%.1f BPM · %@",track.analysis.bpm,track.analysis.key)).font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"arrow.down.circle")}}}}
        if busy{ProgressView("Analyzing local audio…")};if let error{Text(error).foregroundStyle(.orange)}
    }.navigationTitle("Load deck \(deck==0 ? "A" : "B")").toolbar{Button("Done"){dismiss()}}}.fileImporter(isPresented:$importing,allowedContentTypes:[.audio]){result in Task{busy=true;defer{busy=false};do{let url=try result.get();let track=try await Task.detached(priority:.userInitiated){try AudioLab.importFile(url)}.value;library.tracks.append(track);library.save();lab.load(track,deck:deck);dismiss()}catch{self.error=error.localizedDescription}}}}
}

struct BoardCoach:View {
    @EnvironmentObject var lab:AudioLab
    @ObservedObject var coach:CoachService
    @State var consent=false
    @State var mashup=false
    @State var selectedStep=0
    var beat:Double {max(0,(lab.positions[0]-lab.gridOrigins[0])*lab.baseBPM(0)/60)}
    var nextPhrase:Int {32-Int(beat)%32}
    var tempoDifference:Double {lab.baseBPM(1)*lab.tempoRates[1]-lab.baseBPM(0)*lab.tempoRates[0]}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack(spacing:12){Image(systemName:"graduationcap.fill").foregroundStyle(.mint);Text("YOUR MIX COACH").font(.system(size:11,weight:.heavy)).tracking(1.5);Spacer();Text("TIMING GUIDE · ESTIMATED GRID").font(.system(size:8,weight:.semibold)).foregroundStyle(.secondary)}
            HStack(alignment:.top,spacing:24){
                VStack(alignment:.leading,spacing:9){
                    HStack(spacing:7){ForEach(0..<4,id:\.self){i in Text("\(i+1)").font(.system(size:18,weight:.bold,design:.monospaced)).frame(width:38,height:38).background(Int(beat)%4==i && lab.playing[0] ? Color.mint : Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:8)).foregroundStyle(Int(beat)%4==i && lab.playing[0] ? .black : .secondary)}}
                    Text("Bar \(Int(beat)/4+1) · next 8-bar phrase in \(nextPhrase) beats").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
                    Text(lab.loaded.contains(where:{$0==nil}) ? "Load both decks to begin." : abs(tempoDifference)>0.15 ? String(format:"B is %+.1f BPM from A. Tap SYNC on B, then listen for aligned kicks.",tempoDifference) : lab.channelVolumes[0]>0.5 && lab.channelVolumes[1]>0.5 && lab.eq[0][0]>(-6) && lab.eq[1][0]>(-6) && lab.playing.allSatisfy({$0}) ? "Both bass lines are up. Lower LOW on the incoming deck before blending." : "Tempos are close. Cue the incoming track on beat one, then blend at the next phrase.").font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true)
                    Text("Set beat one in EDIT GRID. Confirm the phrase and downbeat by ear.").font(.system(size:9)).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.leading,spacing:10){
                    HStack{Toggle("Send local BPM/key for AI lessons",isOn:$consent).font(.caption);Toggle("Mashup",isOn:$mashup).font(.caption).toggleStyle(.button)}
                    Button {Task{if var a=lab.loaded[0]?.analysis,var b=lab.loaded[1]?.analysis {a.bpm=lab.baseBPM(0)*lab.tempoRates[0];b.bpm=lab.baseBPM(1)*lab.tempoRates[1];await coach.generate(a:a,b:b,mashup:mashup,cloud:consent);selectedStep=0}}} label:{Label(coach.busy ? "Building your lesson…" : consent ? "Ask AI for a mix lesson" : "Build offline practice plan",systemImage:"sparkles")}.buttonStyle(.borderedProminent).tint(.mint).disabled(coach.busy || lab.loaded.contains(where:{$0==nil}))
                    if let plan=coach.plan {Text(coach.source).font(.system(size:9,weight:.semibold)).foregroundStyle(.mint);Text(plan.title).font(.headline);if !plan.steps.isEmpty {Text("\(selectedStep+1). \(plan.steps[min(selectedStep,plan.steps.count-1)])").font(.subheadline);HStack{Button("Previous"){selectedStep=max(0,selectedStep-1)}.disabled(selectedStep==0);Button("Next step"){selectedStep=min(plan.steps.count-1,selectedStep+1)}.disabled(selectedStep>=plan.steps.count-1)}};Text(plan.caution).font(.system(size:9)).foregroundStyle(.secondary)}
                    if let error=coach.error {Text(error).font(.caption).foregroundStyle(.orange)}
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
        }.padding(18).background(LinearGradient(colors:[Color.mint.opacity(0.08),boardPanel],startPoint:.leading,endPoint:.trailing),in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(Color.mint.opacity(0.16)))
    }
}

struct RecordedMixes:View {
    @EnvironmentObject var lab:AudioLab
    @Environment(\.dismiss) var dismiss
    var body:some View {NavigationStack{List {
        if lab.recordings.isEmpty {ContentUnavailableView("Your first mix starts here",systemImage:"waveform",description:Text("Tap REC on the board, play your decks, then stop recording. Your WAV mixes stay on this device."))}
        ForEach(lab.recordings,id:\.self){url in VStack(alignment:.leading,spacing:8){Text(url.deletingPathExtension().lastPathComponent).font(.subheadline);ShareLink("Share WAV mix",item:url)}}
    }.navigationTitle("Recorded mixes").toolbar{Button("Done"){dismiss()}}}}
}
