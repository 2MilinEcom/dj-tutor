import Foundation
import SwiftUI

struct LocalTrack: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var filename: String
    var analysis: Analysis
    var duration: Double
    var cues: [Double] = []
    var hotCues: [String:Double]?
    var url: URL { LibraryStore.directory.appendingPathComponent(filename) }
}
@MainActor final class LibraryStore: ObservableObject {
    nonisolated static var directory: URL {
        let u = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Audio",isDirectory:true)
        try? FileManager.default.createDirectory(at:u,withIntermediateDirectories:true); return u
    }
    @Published var tracks: [LocalTrack] = []
    init() { if let data = try? Data(contentsOf:Self.directory.appendingPathComponent("library.json")), let t = try? JSONDecoder().decode([LocalTrack].self,from:data) { tracks=t } }
    func save() { if let d = try? JSONEncoder().encode(tracks) { try? d.write(to:Self.directory.appendingPathComponent("library.json"),options:.atomic) } }
    func setHotCue(_ id:UUID,slot:Int,at seconds:Double) {
        guard let index=tracks.firstIndex(where:{$0.id==id}) else {return}
        if tracks[index].hotCues == nil {tracks[index].hotCues=[:]}
        tracks[index].hotCues?[String(slot)]=seconds;save()
    }
    func cue(_ id: UUID, at seconds: Double) { guard let i=tracks.firstIndex(where:{$0.id==id}) else {return}; tracks[i].cues.append(seconds); save() }
}
enum AppConfig {
    static func value(_ key: String) -> String { (Bundle.main.object(forInfoDictionaryKey:key) as? String) ?? "" }
}
struct AppError: LocalizedError { var message: String; var errorDescription: String? { message } }
