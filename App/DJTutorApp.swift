import SwiftUI
import UniformTypeIdentifiers

@main struct DJTutorApp: App {
    init() {
        #if DEBUG
        if let session=ProcessInfo.processInfo.environment["DJTUT_COACH_SESSION"] {try? Vault.write("coachSession",Data(session.utf8))}
        #endif
    }
    @StateObject var library=LibraryStore()
    @StateObject var lab=AudioLab()
    @StateObject var linkClock=LinkClock()
    var body: some Scene {WindowGroup {RootView().environmentObject(library).environmentObject(lab).environmentObject(linkClock).preferredColorScheme(.dark)}}
}
struct RootView: View {
    var body: some View {
        #if DJAY_COMPANION
        DjayCompanion()
        #else
        TabView {
            DjayCompanion().tabItem{Label("Coach",systemImage:"sparkles")}
            if UIDevice.current.userInterfaceIdiom == .pad {DJBoard().tabItem{Label("DJ Board",systemImage:"opticaldisc")}}
            LearnView().tabItem{Label("Learn",systemImage:"sparkles")}
            PracticeView().tabItem{Label("Studio",systemImage:"slider.horizontal.3")}
            LibraryView().tabItem{Label("Audio",systemImage:"waveform")}
            SpotifyView().tabItem{Label("Spotify",systemImage:"music.note.list")}
            SettingsView().tabItem{Label("Settings",systemImage:"gearshape")}
        }.tint(.mint)
        #endif
    }
}
struct Panel<Content:View>:View {
    let title:String; @ViewBuilder var content:Content
    var body:some View {VStack(alignment:.leading,spacing:16){Text(title).font(.headline); content}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:22))}
}
struct LearnView: View {
    @AppStorage("completedLessons") var completed=""
    let lessons=[("Find the one","Count four beats. The strongest beat often starts the bar. Tap along for eight bars, then place a cue on the next downbeat."), ("Blend in phrases","Dance music often changes every 8, 16 or 32 bars. Start the incoming track at a phrase boundary and listen for a clean handoff."),("Make room for the bass","Two bass lines can mask each other. Raise the incoming deck’s high-pass filter, blend it in, then swap low-end gradually."),("Build a mashup","Use audio you have permission to edit. Match tempo, loop an instrumental phrase, and introduce a compatible hook. Avoid overlapping vocal phrases."),("Creative edits","Use the Studio export tools to reverse a 16-beat phrase or repeat one beat. Short fades soften clicks; compare the result by ear.")]
    var body:some View {NavigationStack {ScrollView {VStack(alignment:.leading,spacing:22){
        Text("YOUR NEXT GREAT MIX").font(.caption).tracking(3).foregroundStyle(.mint)
        Text("Learn the craft.\nFind your sound.").font(.system(size:36,weight:.bold,design:.rounded))
        Text("A personal DJ classroom, with a real two-deck practice studio.").foregroundStyle(.secondary)
        Panel(title:"Start with sound"){Text("Import permitted audio or load the original demo loops. Connect Spotify separately to explore your listening library."); NavigationLink("Open practice studio"){PracticeView()}.buttonStyle(.borderedProminent)}
        ForEach(lessons.indices,id:\.self){i in Panel(title:String(format:"%02d",i+1)+" · "+lessons[i].0){Text(lessons[i].1).foregroundStyle(.secondary); Button(completed.contains("\(i),") ? "Completed ✓" : "Mark practiced"){if !completed.contains("\(i),") {completed+="\(i),"}}.buttonStyle(.bordered)}}
    }.padding(20)}.navigationTitle("DJ Tutor")}}
}
struct LibraryView: View {
    @EnvironmentObject var library:LibraryStore
    @EnvironmentObject var lab:AudioLab
    @State var importing=false
    @State var permitted=false
    @State var busy=false
    @State var error:String?
    var body:some View {NavigationStack {ScrollView{VStack(spacing:18){
        Panel(title:"Your audio, your studio"){
            Text("Only import audio you own or are licensed to analyze and edit. Spotify downloads and protected files cannot be used here.").foregroundStyle(.secondary)
            Toggle("I have permission to use this audio",isOn:$permitted)
            Button("Import audio from Files",systemImage:"square.and.arrow.down"){importing=true}.buttonStyle(.borderedProminent).disabled(!permitted || busy)
            Button("Load original practice loops"){Task{busy=true; defer{busy=false}; do{for i in 0...1 {let t=try await Task.detached(priority:.userInitiated){try AudioLab.demo(i)}.value; if !library.tracks.contains(where:{$0.filename==t.filename}) {library.tracks.append(t)} }; library.save()}catch{self.error=error.localizedDescription}}}.disabled(busy)
            if busy {ProgressView("Analyzing audio…")}
        }
        if let error {Text(error).foregroundStyle(.orange)}
        ForEach(library.tracks){track in Panel(title:track.title){
            Text(String(format:"%.1f BPM · %@ · %.0f sec",track.analysis.bpm,track.analysis.key,track.duration)).foregroundStyle(.mint)
            Text(String(format:"Tempo confidence %.0f%% · estimates, verify by ear",track.analysis.confidence*100)).font(.caption).foregroundStyle(.secondary)
            Waveform(values:track.analysis.waveform,progress:0,color:.mint)
            HStack{Button("Load A"){lab.load(track,deck:0)}; Spacer(); Button("Load B"){lab.load(track,deck:1)}}.buttonStyle(.bordered)
        }}
    }.padding(20)}.navigationTitle("Local audio")}
    .fileImporter(isPresented:$importing,allowedContentTypes:[.audio]){result in Task{busy=true; defer{busy=false}; do {let u=try result.get(); let t=try await Task.detached(priority:.userInitiated){try AudioLab.importFile(u)}.value; library.tracks.append(t); library.save()} catch{self.error=error.localizedDescription}}}
    }
}
struct Waveform:View {
    var values:[Float]; var progress:Double; var color:Color
    var body:some View {GeometryReader{g in Canvas{ctx,size in
        let data=values.isEmpty ? [Float](repeating:0.05,count:80) : values
        let w=size.width/Double(data.count)
        for (i,v) in data.enumerated(){let h=max(2,Double(v)*size.height); let r=CGRect(x:Double(i)*w,y:(size.height-h)/2,width:max(1,w-1),height:h); ctx.fill(Path(roundedRect:r,cornerRadius:1),with:.color(color.opacity(Double(i)/Double(data.count)<progress ? 1 : 0.4)))}
        let x=min(1,max(0,progress))*size.width; var line=Path();line.move(to:CGPoint(x:x,y:0));line.addLine(to:CGPoint(x:x,y:size.height));ctx.stroke(line,with:.color(.white),lineWidth:2)
    }}.frame(height:66).accessibilityLabel("Audio waveform")}
}
struct PracticeView:View {
    @EnvironmentObject var lab:AudioLab
    @EnvironmentObject var library:LibraryStore
    @StateObject var coach=CoachService()
    @State var mashup=false
    @State var cloud=false
    @State var consent=false
    @State var error:String?
    @State var exported:URL?
    @State var exporting=false
    var body:some View {NavigationStack{ScrollView{VStack(spacing:18){
        Text("THE PRACTICE ROOM").font(.caption).tracking(3).foregroundStyle(.mint)
        ForEach(0...1,id:\.self){i in DeckView(deck:i,onError:{error=$0})}
        Panel(title:"Blend") {HStack{Text("A");Slider(value:$lab.crossfade,in:0...1);Text("B")}.accessibilityLabel("Equal power crossfader")
            Button("Match B tempo to A"){if let a=lab.loaded[0],let b=lab.loaded[1] {lab.rates[1].rate=Float(min(1.25,max(0.75,a.analysis.bpm/b.analysis.bpm)))}}
            Text("Tempo matching does not align beats. Use cues and your ears.").font(.caption).foregroundStyle(.secondary)
            Button("Stop both decks"){lab.stopAll()}
        }
        Panel(title:"Your transition coach") {
            Toggle("Mashup lesson",isOn:$mashup)
            Toggle("Use cloud AI coach",isOn:$cloud)
            if cloud {Toggle("Send local BPM/key only to the coach",isOn:$consent)}
            Button(coach.busy ? "Coaching…" : "Build my practice plan") {Task{if let a=lab.loaded[0],let b=lab.loaded[1]{await coach.generate(a:a.analysis,b:b.analysis,mashup:mashup,cloud:cloud)}}}.buttonStyle(.borderedProminent).disabled(coach.busy || lab.loaded.contains(where:{$0==nil}) || (cloud && !consent))
            if let p=coach.plan {Text(coach.source).font(.caption).foregroundStyle(.mint); Text(p.title).font(.title3.bold());ForEach(Array(p.steps.enumerated()),id:\.offset){i,s in Text("\(i+1). \(s)")};Text(p.caution).font(.caption).foregroundStyle(.secondary)}
            if let e=coach.error {Text(e).foregroundStyle(.orange)}
        }
        Panel(title:"Creative export · deck A"){
            Text("Export from the current cue/playhead. Only local audio is used.").font(.caption).foregroundStyle(.secondary)
            Button("Reverse a 16-beat phrase"){export(reverse:true,repeatBeat:false)}.disabled(lab.loaded[0]==nil || exporting)
            Button("16× beat-repeat edit"){export(reverse:false,repeatBeat:true)}.disabled(lab.loaded[0]==nil || exporting)
            if exporting {ProgressView("Creating edit…")}
            if let exported {ShareLink("Share WAV edit",item:exported)}
        }
        if let error {Text(error).foregroundStyle(.orange)}
    }.padding(20)}.navigationTitle("Studio")}}
    func export(reverse:Bool,repeatBeat:Bool){guard let t=lab.loaded[0] else{return};let start=lab.positions[0];exporting=true;Task{defer{exporting=false};do{exported=try await Task.detached(priority:.userInitiated){try AudioLab.export(t,start:start,reverse:reverse,repeatBeat:repeatBeat)}.value}catch{self.error=error.localizedDescription}}}
}
struct DeckView:View {
    @EnvironmentObject var lab:AudioLab
    @EnvironmentObject var library:LibraryStore
    let deck:Int; var onError:(String)->Void
    @State var tempo=1.0
    @State var cutoff=20.0
    @State var echo=0.0
    var color:Color {deck==0 ? .mint : .purple}
    var body:some View {Panel(title:deck==0 ? "DECK A" : "DECK B"){
        if let t=lab.loaded[deck] {
            Text(t.title).font(.title3.bold())
            Text(String(format:"%.1f BPM · %@",t.analysis.bpm,t.analysis.key)).foregroundStyle(color)
            Waveform(values:t.analysis.waveform,progress:lab.positions[deck]/t.duration,color:color)
            Slider(value:Binding(get:{min(t.duration,lab.positions[deck])},set:{v in action{try await lab.play(deck,from:v)}}),in:0...t.duration).accessibilityLabel("Seek deck \(deck+1)")
            HStack{
                Button(lab.playing[deck] ? "Pause" : "Play",systemImage:lab.playing[deck] ? "pause.fill" : "play.fill"){action{try await lab.play(deck)}}
                Button("Cue +"){library.cue(t.id,at:lab.positions[deck])}
                Button(lab.loops[deck] ? "Exit loop" : "4-beat loop"){action{try await lab.play(deck,from:lab.positions[deck],loop:!lab.loops[deck])}}
            }.buttonStyle(.bordered)
            if let saved=library.tracks.first(where:{$0.id==t.id}) {ScrollView(.horizontal){HStack{ForEach(Array(saved.cues.enumerated()),id:\.offset){i,c in Button(String(format:"C%d · %.1fs",i+1,c)){action{try await lab.play(deck,from:c)}}.buttonStyle(.bordered)}}}}
            Text("Tempo \(Int(Double(lab.rates[deck].rate)*100))% · preserves pitch").font(.caption)
            Slider(value:$tempo,in:0.75...1.25).onChange(of:tempo){_,v in lab.rates[deck].rate=Float(v)}.accessibilityLabel("Tempo")
            Text("High-pass filter").font(.caption);Slider(value:$cutoff,in:20...2000).onChange(of:cutoff){_,v in lab.filters[deck].bands[0].frequency=Float(v)}
            Text("Echo send").font(.caption);Slider(value:$echo,in:0...40).onChange(of:echo){_,v in lab.delays[deck].wetDryMix=Float(v); lab.delays[deck].delayTime=60/t.analysis.bpm/2}
        } else {Text("Load a track from Local audio.").foregroundStyle(.secondary);NavigationLink("Choose audio"){LibraryView()}}
    }.onChange(of:lab.loaded[deck]?.id){_,_ in tempo=1;cutoff=20;echo=0;lab.filters[deck].bands[0].frequency=20;lab.delays[deck].wetDryMix=0}}
    func action(_ f:@escaping ()async throws->Void){Task{do{try await f()}catch{onError(error.localizedDescription)}}}
}
struct SpotifyView:View {
    @StateObject var spotify=SpotifyService()
    @EnvironmentObject var library:LibraryStore
    @State var showPractice=false
    @State var loadingDemo=false
    @State var demoError:String?
    var spotifyConfigured:Bool { !AppConfig.value("SpotifyClientID").isEmpty && URL(string:AppConfig.value("SpotifyRedirectURI"))?.host != "example.com" }
    @EnvironmentObject var lab:AudioLab
    @Environment(\.openURL) var openURL
    var body:some View {NavigationStack{ScrollView{VStack(spacing:18){
        Panel(title:"Spotify discovery"){
            Text("Explore your account, saved tracks and playlists. Listen in Spotify. Spotify audio stays outside the studio and AI coach.").foregroundStyle(.secondary)
            if let p=spotify.profile {Text(p.display_name ?? p.id).font(.title3);Button("Refresh library"){Task{await spotify.refreshLibrary()}};Button("Disconnect",role:.destructive){spotify.disconnect()}}
            else {
                if spotifyConfigured {
                    Button("Connect Spotify"){Task{await spotify.connect()}}.buttonStyle(.borderedProminent).disabled(spotify.busy)
                    Button("Restore saved connection"){Task{await spotify.refreshLibrary()}}.disabled(spotify.busy)
                } else {
                    Text("Spotify setup is pending").font(.headline)
                    Text("Spotify login needs an HTTPS callback configured for this app. You can use the full local practice studio now.").foregroundStyle(.secondary)
                    Button(loadingDemo ? "Preparing practice audio…" : "Try the practice studio") {loadPractice()}.buttonStyle(.borderedProminent).disabled(loadingDemo)
                    if loadingDemo {ProgressView()}
                    if let demoError {Text(demoError).foregroundStyle(.orange)}
                }
            }
            if spotifyConfigured {Text(spotify.status).font(.caption)};if spotify.busy{ProgressView()}
        }
        if spotify.profile != nil {Panel(title:"Playlists"){ForEach(spotify.playlists){p in HStack{Button(p.name){Task{await spotify.contents(p)}};Spacer();Button("Open"){listen(p)}}}}
        Panel(title:"Playlist tracks"){ForEach(spotify.playlistTracks){t in Button(t.name){listen(t)}}}
        Panel(title:"Saved tracks"){ForEach(spotify.saved){t in Button(t.name){listen(t)}}}}
        Text("Discovery via Spotify · playback opens the Spotify app or website.").font(.caption).foregroundStyle(.secondary)
    }.padding(20)}.navigationTitle("Spotify")}.sheet(isPresented:$showPractice){PracticeView()}}
    func loadPractice() {
        loadingDemo=true
        Task {defer{loadingDemo=false};do {
            for i in 0...1 {
                let t=try await Task.detached(priority:.userInitiated){try AudioLab.demo(i)}.value
                if !library.tracks.contains(where:{$0.filename==t.filename}) {library.tracks.append(t)}
                let saved=library.tracks.first(where:{$0.filename==t.filename}) ?? t
                lab.load(saved,deck:i)
            }
            library.save();showPractice=true
        } catch {demoError=error.localizedDescription}}
    }
    func listen(_ item:SpotifyItem){guard let s=item.external_urls?["spotify"],let u=URL(string:s),u.scheme=="https",u.host=="open.spotify.com" else{return};lab.stopAll();openURL(u)}
}
struct SettingsView:View {
    @State var session=""
    @State var status=""
    var body:some View{NavigationStack{Form{
        Section("Cloud coach session"){
            Text("The app never stores an AI provider key. Paste a short-lived token issued by your own backend administrator. Local coaching works without setup.")
            SecureField("Session token",text:$session).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save securely"){do{try Vault.write("coachSession",Data(session.utf8));session="";status="Saved to device Keychain."}catch{status=error.localizedDescription}}
            Button("Remove session",role:.destructive){try? Vault.write("coachSession",nil);status="Session removed."}
            Text(status)
        }
        Section("Privacy") {Text("Audio is analyzed on your iPhone. Cloud coaching sends only BPM, key and lesson mode after you opt in. Spotify data and tokens are never sent to the coach. No analytics are collected.")}
        Section("About") {Text("DJ Tutor 1.0 · estimates are learning aids. The iPad board includes an editable estimated beat grid; no stem separation. Use only permitted audio.")}
    }.navigationTitle("Settings")}}
}
