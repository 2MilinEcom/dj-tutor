import Foundation
@MainActor final class CoachService: ObservableObject {
    @Published var plan: CoachPlan?
    @Published var busy=false
    @Published var source="Offline lesson engine"
    @Published var error: String?
    func generate(a: Analysis, b: Analysis, mashup: Bool, cloud: Bool) async {
        plan=CoachPlan.offline(a:a,b:b,mashup:mashup); error=nil
        source="Offline lesson engine"
        guard cloud else {return}
        busy=true; defer{busy=false}
        do {
            guard let url=URL(string:AppConfig.value("CoachBaseURL")), url.scheme=="https", url.host != "example.com", let key=Vault.read("coachSession"), let bearer=String(data:key,encoding:.utf8), !bearer.isEmpty else {throw AppError(message:"Add your deployed coach URL and a short-lived session token in Settings.")}
            var request=URLRequest(url:url.appendingPathComponent("coach")); request.httpMethod="POST"; request.timeoutInterval=30
            request.setValue("application/json",forHTTPHeaderField:"Content-Type"); request.setValue("Bearer \(bearer)",forHTTPHeaderField:"Authorization")
            // Deliberately excludes filenames, audio, Spotify data and free-text prompts.
            request.httpBody=try JSONSerialization.data(withJSONObject:["a":["bpm":a.bpm,"key":a.key],"b":["bpm":b.bpm,"key":b.key],"mode":mashup ? "mashup" : "transition","source":"local"])
            let (data,response)=try await URLSession.shared.data(for:request)
            guard (response as? HTTPURLResponse)?.statusCode==200 else {throw AppError(message:"Cloud coach unavailable. Offline lesson retained.")}
            plan=try JSONDecoder().decode(CoachPlan.self,from:data); source="AI coach · local audio measurements"
        } catch {self.error=error.localizedDescription}
    }
}
