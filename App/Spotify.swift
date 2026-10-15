import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

enum Vault {
    static func read(_ name: String) -> Data? {
        let q: [String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"DJTutor",kSecAttrAccount as String:name,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess else {return nil}; return result as? Data
    }
    static func write(_ name: String, _ data: Data?) throws {
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"DJTutor",kSecAttrAccount as String:name]
        SecItemDelete(q as CFDictionary)
        if let data {
            var insert=q; insert[kSecValueData as String]=data; insert[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary,nil)==errSecSuccess else {throw AppError(message:"Secure storage failed.")}
        }
    }
}
struct SpotifyToken: Codable {
    var access_token: String; var refresh_token: String?; var expires_in: Int; var expiry: Date?
}
struct SpotifyProfile: Decodable { var id: String; var display_name: String? }
struct SpotifyItem: Decodable, Identifiable {
    var id: String; var name: String; var external_urls: [String:String]?
    var owner: SpotifyProfile?; var collaborative: Bool?
}
struct SpotifyPage<T: Decodable>: Decodable { var items: [T]; var next: String? }
struct SavedTrack: Decodable { var track: SpotifyItem? }
struct PlaylistEntry: Decodable { var item: SpotifyItem?; var track: SpotifyItem? }

@MainActor final class SpotifyService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var profile: SpotifyProfile?
    @Published var playlists: [SpotifyItem]=[]
    @Published var saved: [SpotifyItem]=[]
    @Published var playlistTracks: [SpotifyItem]=[]
    @Published var status="Connect to discover your library."
    @Published var busy=false
    private var token: SpotifyToken?
    private var session: ASWebAuthenticationSession?
    private var refreshing: Task<SpotifyToken,Error>?
    private var blockedUntil=Date.distantPast
    override init() { super.init(); if let d=Vault.read("spotify") {token=try? JSONDecoder().decode(SpotifyToken.self,from:d)} }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first(where:{$0.isKeyWindow}) ?? ASPresentationAnchor()
    }
    func connect() async {
        busy=true; defer {busy=false}
        do {
            let client=AppConfig.value("SpotifyClientID"), redirect=AppConfig.value("SpotifyRedirectURI")
            guard !client.isEmpty, let callback=URL(string:redirect), callback.scheme=="https", let host=callback.host, host != "example.com" else {throw AppError(message:"Configure your Spotify client ID and HTTPS callback domain in Config/App.xcconfig first.")}
            let verifier=try random(), state=try random()
            let challenge=Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
            var u=URLComponents(string:"https://accounts.spotify.com/authorize")!
            u.queryItems=["client_id":client,"response_type":"code","redirect_uri":redirect,"code_challenge_method":"S256","code_challenge":challenge,"state":state,"scope":"playlist-read-private playlist-read-collaborative user-library-read"].map{URLQueryItem(name:$0.key,value:$0.value)}
            let result: URL = try await withCheckedThrowingContinuation { continuation in
                session=ASWebAuthenticationSession(url:u.url!,callback:.https(host:host,path:callback.path)) { url,error in
                    if let error {continuation.resume(throwing:error)} else if let url {continuation.resume(returning:url)} else {continuation.resume(throwing:AppError(message:"No OAuth callback."))}
                }
                session?.presentationContextProvider=self; session?.prefersEphemeralWebBrowserSession=true
                if session?.start() != true {continuation.resume(throwing:AppError(message:"Cannot open Spotify authorization."))}
            }
            let query=URLComponents(url:result,resolvingAgainstBaseURL:false)?.queryItems ?? []
            guard query.first(where:{$0.name=="state"})?.value==state else {throw AppError(message:"OAuth state validation failed.")}
            guard let code=query.first(where:{$0.name=="code"})?.value else {throw AppError(message:"Spotify authorization declined.")}
            token=try await exchange(["grant_type":"authorization_code","code":code,"redirect_uri":redirect,"client_id":client,"code_verifier":verifier])
            try persist(); await refreshLibrary()
        } catch {status=error.localizedDescription}
    }
    private func random() throws -> String {
        var bytes=[UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes)==errSecSuccess else {throw AppError(message:"Cannot generate secure OAuth state.")}
        return Data(bytes).map{String(format:"%02x",$0)}.joined()
    }
    private func exchange(_ fields:[String:String]) async throws -> SpotifyToken {
        var request=URLRequest(url:URL(string:"https://accounts.spotify.com/api/token")!); request.httpMethod="POST"
        request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        var allowed=CharacterSet.alphanumerics; allowed.insert(charactersIn:"-._~")
        request.httpBody=fields.map{ $0.key+"="+($0.value.addingPercentEncoding(withAllowedCharacters:allowed) ?? "") }.joined(separator:"&").data(using:.utf8)
        let (data,response)=try await URLSession.shared.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode==200 else {throw AppError(message:"Spotify token request failed. Reconnect and verify developer settings.")}
        var t=try JSONDecoder().decode(SpotifyToken.self,from:data); t.expiry=Date().addingTimeInterval(Double(t.expires_in)); return t
    }
    private func persist() throws {try Vault.write("spotify",token.map{try JSONEncoder().encode($0)})}
    private func access() async throws -> String {
        guard let t=token else {throw AppError(message:"Connect Spotify first.")}
        if (t.expiry ?? .distantPast) > Date().addingTimeInterval(60) {return t.access_token}
        if let refreshing {return try await refreshing.value.access_token}
        guard let refresh=t.refresh_token else {throw AppError(message:"Reconnect Spotify.")}
        let task=Task { var n=try await exchange(["grant_type":"refresh_token","refresh_token":refresh,"client_id":AppConfig.value("SpotifyClientID")]); n.refresh_token=n.refresh_token ?? refresh; return n }
        refreshing=task; defer {refreshing=nil}
        token=try await task.value; try persist(); return token!.access_token
    }
    private func get<T:Decodable>(_ path:String, as type:T.Type, retry:Bool=true) async throws -> T {
        guard Date() >= blockedUntil else {throw AppError(message:"Spotify quota/rate limit active. Try again later.")}
        guard let url=URL(string:path.hasPrefix("https://") ? path : "https://api.spotify.com/v1/"+path), url.host=="api.spotify.com", url.scheme=="https" else {throw AppError(message:"Invalid API pagination URL.")}
        var request=URLRequest(url:url); request.setValue("Bearer \(try await access())",forHTTPHeaderField:"Authorization")
        let (data,response)=try await URLSession.shared.data(for:request); let http=response as! HTTPURLResponse
        if http.statusCode==401 && retry {token?.expiry = .distantPast; return try await get(path,as:type,retry:false)}
        if http.statusCode==429 {blockedUntil=Date().addingTimeInterval(Double(http.value(forHTTPHeaderField:"Retry-After") ?? "60") ?? 60); throw AppError(message:"Spotify rate or account quota reached. Try later; all development apps share an account quota.")}
        guard (200...299).contains(http.statusCode) else {throw AppError(message:"Spotify returned \(http.statusCode). Check user allowlist, scopes and endpoint access in your dashboard.")}
        return try JSONDecoder().decode(T.self,from:data)
    }
    private func pages<T:Decodable>(_ path:String, as type:T.Type) async throws -> [T] {
        var next:String?=path; var items=[T]()
        while let p=next, items.count<1000 {let page=try await get(p,as:SpotifyPage<T>.self); items+=page.items; next=page.next}
        return items
    }
    func refreshLibrary() async {
        busy=true; defer{busy=false}
        do {
            profile=try await get("me",as:SpotifyProfile.self)
            playlists=try await pages("me/playlists?limit=50",as:SpotifyItem.self)
            // Endpoint-specific denial must not discard successful account/playlist discovery.
            do {saved=try await pages("me/tracks?limit=50",as:SavedTrack.self).compactMap{$0.track}; status="Library synced (up to 1,000 items)."}
            catch {status="Playlists synced. Saved-track access unavailable: "+error.localizedDescription}
        } catch {status=error.localizedDescription}
    }
    func contents(_ playlist:SpotifyItem) async {
        playlistTracks=[]
        guard playlist.owner?.id==profile?.id || playlist.collaborative==true else {status="Only owned or collaborative playlist contents are available in current development mode."; return}
        do {playlistTracks=try await pages("playlists/\(playlist.id)/items?limit=50",as:PlaylistEntry.self).compactMap{$0.item ?? $0.track}; status="Playlist loaded."} catch {status=error.localizedDescription}
    }
    func disconnect() {token=nil; profile=nil; playlists=[]; saved=[]; playlistTracks=[]; try? Vault.write("spotify",nil); status="Disconnected. Tokens removed from this device."}
}
