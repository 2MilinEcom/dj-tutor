# DJ TUT · djay companion for iPad

## Current teaching overlay

The installed companion now opens a message-style teaching view rather than BPM/phrase setup. Five lessons cover a first blend, core controls, phrase timing, EQ/bass swaps and echo exits. Each shows one move and an audible/visual check, with **Next move**, **Back**, **Why?**, **Find it**, and **Fix it**. Lesson selection and progress persist locally. **I messed up — restart lesson** resets lesson progress and shows safe recovery instructions; it does not detect mistakes or rewind/operate djay. The user confirmed DJ TUT can sit in Slide Over above djay with both Spotify tracks loaded.

**Show me** opens explicit, offline Start → Action → Finish illustrations for all 18 lesson steps. The action type and starting/ending control states are authored per instruction rather than inferred from caption wording. The first crossfader move starts at center and visibly travels left; Play starts with a paused deck, shows a tap and then changes to playing. Cue Set/Jump, Sync off/on, Low EQ down/restored, FX opening and Echo amount/release have distinct visual states. Compound start-and-fade/bass-swap moves are split into separate instructions. Observations are marked LOOK / LISTEN — NO CHANGE and counting remains illustrative, not synced to music.

Each selected movement automatically demonstrates once, then waits for Next instruction; Replay this movement and Pause guide animation affect only the guide. Reduced Motion keeps the illustration static until the learner chooses replay. There is no tutorial scrubber. A numbered action card and Start/Finish labels sit above the highlighted target; inactive decks dim. Decorative platters appear only on playback instructions, keeping fader, cue, EQ and FX targets visible. No screen or music is captured, and no live djay control or timing is claimed.

**Try this with songs** follows every demo, with an additional pinned button on the final instruction. The local practice pair starts with the user’s previously chosen Hurts Me (left) and FE!N (right), can be edited or swapped, and persists on the iPad. The practice screen reuses the exact lesson step and check, adds section-selection guidance, and offers self-reported outcomes with retry prompts. It does not load tracks, capture music, infer song structure or send the pair to the AI endpoint. Songs play in djay; exact cue times and BPM are not assumed. Practice feedback does not mark a lesson complete or score the audio.

**Ask AI** provides contextual questions and follow-up conversation through an authenticated `/teach` endpoint. It sends typed questions, current topic/step and up to four recent Q&A turns only with consent. The user explicitly approved the private teaching connection; that consent is provisioned for this iPad and can be switched off in the app. The server adds a controlled lesson-step description. No audio, screenshot, BPM, key, Spotify identifier or automatic deck state enters the teaching contract. Unsupported fields and excessive histories/questions are rejected. Replies contain a short explanation, next action, check and follow-up question. The teacher is explicitly instructed not to claim to see/hear/control djay or invent song timing.

The existing provider key remains in the Mac server environment. No new key was created or copied into the app. The user explicitly approved the expanded teaching payload and its authenticated Cloudflare HTTPS connection. Physical iPad acceptance results are recorded in VALIDATION.md. Pilot sessions last one hour; the AI connection requires the Mac backend and temporary HTTPS connection to remain running. This is not permanent hosting or independent device enrollment.

`TeacherAcceptance` is Debug-only, opt-in integration verification triggered with `DJTUT_VALIDATE_TEACHER=1`; it submits one generic synthetic question through the app's real service, checks Keychain/session and decoded response, writes a credential-free result, then clears the synthetic conversation. It is not a user conversation or an audio test.

The sections below retain earlier development history; the current teacher no longer requires the user to type BPM or mark phrases to receive lessons.

A native SwiftUI iPhone and iPad learning app. It now opens a silent coaching companion first, intended to sit beside or over djay, with Ableton Link timing and guided transition lessons. The previous local studio, Spotify discovery and optional cloud coach remain separate tabs. Requires Xcode with an iOS 17.4+ SDK and Ableton's official LinkKit 4.1.2. All synced project reference files remain untouched.

## djay companion

### Installed free-account pilot

DJ TUT was signed and installed on the user's physical iPad A16/iPadOS 26.5, and launched after the user enabled Developer Mode and trusted their developer profile. djay 5.6.9 is installed. The personal development team cannot provision the old Associated Domains capability; a separate **DJ TUT Coach** Xcode scheme uses `Config/DjayCompanion.xcconfig` and empty `App/Companion.entitlements`. It opens the coach directly and omits the legacy tabs from this build. It defaults to **Manual timing**, hides unavailable Link controls and never activates Link networking. Thus this installed pilot does **not** automatically sync with djay or read its playback. The full DJTutor scheme still preserves the old studio and prospective Link integration.

Choose **DJ TUT Coach** and the connected iPad in Xcode to reinstall this free development build. The first device profile expires October 21, 2026; the app needs re-signing/reinstallation after its development profile expires. No membership, song or djay subscription was purchased. Apple-account refresh, device registration/profile creation and developer trust were explicitly authorized or completed by the user. The unsigned generic device build alone did not constitute an install; actual installation and launch were subsequently confirmed by Apple's device tool.

The Coach tab is a narrow, responsive window suitable for Slide Over on the user's iPad A16 running iPadOS 26.5. It includes a shared BPM/beat display, a learner-supplied phrase anchor, an echo-out/drop lesson, a bass-swap lesson, beat countdowns, explanations, and missed-cue recovery. Guided lessons are on-device templates; they do not make AI/API requests or claim to hear Spotify. Cloud AI in the old studio still accepts local-audio measurements only. Spotify/djay audio, track metadata, and Link timing are not sent to a model.

The companion reads tempo and beat time using the official LinkKit C interface on the main thread. It never writes the live session tempo or transport, enables Link Audio, or captures djay output. The official Ableton Link settings pane lets the user enable/disable Link. Link joins any available peer, without identifying it as djay. An absolute song playhead, phrase structure, EQ/fader values, cue positions and track names are not provided by this integration. Mark the first beat of a musical phrase by ear before arming a lesson. Reconnection, backgrounding or a discontinuous timeline cancels the lesson and requires another marker. Keep both apps visible; this silent companion does not run a fake background audio session. Entering it releases the local studio's audio session to avoid competing with djay.

### Setup on the iPad

1. The manual companion is installed on the user's unlocked iPad. For future installs, choose **DJ TUT Coach** in Xcode. The full Link build remains separately gated by its capability/profile requirements below.
2. In djay, connect Spotify Premium, load the tracks, enable **Settings → Ableton Link**, use Beat and Tempo Sync, and play the active deck with its channel fader raised.
3. In DJ TUT, open **Ableton Link**, enable it and allow local-network access. Both apps/devices must have a working local-network connection.
4. Hold DJ TUT's window controls and choose **Enter Slide Over**, or place both windows side by side. This is an operating-system companion window, not an extension inserted into djay's controls.
5. Mark an audible phrase start, choose a lesson, and tap **Start guided transition**. The first move occurs on the next anchored 8-bar phrase with at least four beats of preparation. You perform every action inside djay.

### Physical-device Link permission

Ableton documents an Apple-approved `com.apple.developer.networking.multicast` entitlement as necessary on iOS devices, including development builds. The existing signing profile has not been verified to include it. The default `App/DJTutor.entitlements` does **not** assert this restricted capability, so the app can be signed for manual coaching without it. `App/LinkCoach.entitlements` contains the correct multicast capability plus the existing associated domain. After Apple enables the capability for this development team/app ID and a matching profile is generated, set `CODE_SIGN_ENTITLEMENTS = App/LinkCoach.entitlements` in `Config/App.xcconfig`. Merely editing the file does not grant access. No entitlement application has been submitted on the user's behalf.

Until the device profile permits Link, **Manual timing** works without peer access: set/tap the BPM shown in djay, mark the phrase start and follow the lesson. Manual timing is explicitly labeled unsynchronized and can drift. Live Link/djay compatibility with Spotify and real-device transition timing remain unverified. The coach keeps counting while foreground-inactive so it can remain visible while the user operates djay; hiding/backgrounding it invalidates the phrase anchor.

### LinkKit dependency

The official SDK was downloaded locally from [Ableton's LinkKit 4.1.2 release](https://github.com/Ableton/LinkKit/releases/tag/LinkKit-4.1.2). Its XCFramework and localization bundle are linked by the Xcode project; `App/LinkBridge.h` exposes its C/Objective-C interfaces to Swift. See [Ableton's integration guide](https://ableton.github.io/linkkit/) and [djay's connection instructions](https://help.algoriddim.com/topic/using-djay/using-ableton-link-with-djay).

The SDK itself is excluded from distributable source archives because its license prohibits redistributing the SDK. A fresh checkout/archive recipient downloads it directly from Ableton using `bash Scripts/fetch-linkkit.sh` before opening/building the project. There is no charge for this SDK. No paid djay subscription was started and no songs were purchased.

## iPad DJ board

The iPad retains a dedicated DJ Board tab, with cyan/purple decks, rotating jog indicators, estimated-grid waveforms, a central mixer and a teaching panel. It plays local files only; it is not a Spotify deck engine. Portrait and landscape layouts share the same real audio engine. The existing learning/studio navigation remains available.

Tap **Demo set** to load the two original loops into A/B. The generated loops are known to be 120/124 BPM, so their grid values are set explicitly. Import permitted audio through a deck's folder button. The board provides play/pause, waveform seek, jog seeking, ±25% tempo adjustment, one-shot tempo/beat-phase matching, an editable BPM/beat-one grid, eight saved hot cues per deck, 1–128 beat loops, beat jumps, low/mid/high EQ and kill switches, low/high-pass filtering, echo, reverb, channel volume, master volume, equal-power crossfade and stereo output metering. Quantize snaps cues, loop starts and beat jumps to the editable estimated grid; it does not identify musical downbeats automatically. Sync matches estimated tempo and phase once rather than maintaining a continuous sync lock. Jog dragging seeks and resumes playback; it does not synthesize vinyl scratching.

**REC** records the local mixed output to WAV, including deck processing, and retains files under app Documents/Recordings. The recordings button opens the saved-mix list; share buttons export via the system share sheet. Exported phrase edits remain available in Studio.

The teaching panel counts beats, bars and the next 8-bar phrase on deck A's estimated grid. Its immediate guidance responds to the current deck tempos, playheads, playback state and bass settings. Enable **Send local BPM/key for AI lessons** to request a structured AI practice plan, with Previous/Next controls. Only local BPM/key and lesson mode are sent; the AI does not hear the audio, inspect Spotify data or independently detect the actual phrase structure.

The current AI prototype uses an authenticated Mac-hosted backend through an explicitly approved temporary Cloudflare HTTPS tunnel. The existing OpenAI key is inherited by the server and never placed in the app or copied into project files. The service must keep running on the Mac; the tunnel address changes if restarted. A private one-hour coaching session was provisioned into the iPad simulator's Keychain through a development-only launch environment. This setup is for development, not permanent hosting or end-user account enrollment. Railway still hosts the stable Spotify callback. Permanent coach hosting and physical-device session provisioning remain separate deployment work.

Development-only `BoardAcceptance` checks real engine state, legacy library decoding, persisted hot cues, recorded audio and a live AI lesson. It runs only when the Debug build is launched with `DJTUT_VALIDATE_BOARD=1`; it is excluded from Release builds. Demo measurements alone are used for that AI check.

No stem separation, real vinyl scratching, hardware headphone cue routing, MIDI-controller integration or continuously locked beat sync is claimed. Physical-device audio quality and timing still need acceptance testing.

## Run immediately

1. Open `DJTutor.xcodeproj`, choose the **DJTutor** scheme and an iPhone simulator, then Run.
2. In **Audio**, tap **Load original practice loops**. Load one into A and the other into B.
3. In **Studio**, play the decks, match tempo, place cues, loop four beats, adjust high-pass/echo and blend with the crossfader.
4. Tap **Build my practice plan** for offline transition or mashup instruction. Cloud AI is optional and labeled separately.
5. Try **Reverse a 16-beat phrase** or **16× beat-repeat edit**, then share the resulting WAV.

For a physical phone, change the bundle identifier in `Config/App.xcconfig`, select your Apple development team in Signing & Capabilities, and trust the device. An Apple developer account and provisioning are needed for device distribution; App Store release also needs icons, privacy disclosures, licensing review, and real-device QA. The development Team ID is set from the existing local Xcode project; signing credentials are managed by Xcode.

## Spotify setup (verified against official docs October 14, 2026)

The existing DJ TUT developer app's public Client ID is configured, and the bundle identifier is `com.djtut.app`. The `djtut` URL scheme is registered in Info.plist for future native SDK callbacks. The dashboard screenshot shows `djtut://spotify-callback`, but this project's Web API PKCE flow requires a separate HTTPS redirect under Spotify's current Web API requirements. `SPOTIFY_REDIRECT_URI` now uses `https://spotify-callback-production-c577.up.railway.app/spotify/callback`, deployed on Railway and saved in the Spotify developer dashboard. A hosting-provided HTTPS address can be used without buying a custom domain. The native Spotify iOS SDK is not included in this project. Live Spotify authorization and library refresh are verified in the iPhone 17 simulator: profile, playlists, saved tracks, and selected playlist contents displayed successfully. Physical-device login, token expiry, and revocation remain to be tested.

The iPhone is a public OAuth client. **Do not create or embed a Spotify client secret.** The app uses Authorization Code with PKCE (S256), cryptographic state, an ephemeral system authentication browser, token refresh, and device-only Keychain storage.

1. Create a Web API app in the Spotify developer dashboard. Put its public client ID in `Config/App.xcconfig`.
2. Set `SPOTIFY_REDIRECT_URI` to an HTTPS callback on a domain you control, for example `https:/$()/your-domain.com/spotify/callback` in xcconfig. Register the exact resulting URL `https://your-domain.com/spotify/callback` in Spotify. The `$()` preserves slashes in xcconfig. Never use localhost or a custom scheme with this Web API implementation.
3. The app uses the iOS 17.4+ `ASWebAuthenticationSession` HTTPS host/path callback. Serve a harmless fallback page at that URL; it should not log query strings, analytics, or authorization codes. Test this redirect on a signed physical device. The project now includes the required `webcredentials` Associated Domains entitlement and Railway serves the apple-app-site-association file for `ZBMURWWFQS.com.djtut.app`. The Team ID was taken from the existing local Xcode project. Apple domain association caching and signed physical-device behavior still need acceptance testing.
4. Add test users to the dashboard allowlist and ensure the development app owner's Premium subscription is active. Development mode currently caps authorized users at five (existing allowances may differ). As of July 2026, the client ID limit is **25**, and quota is shared per developer account. Extended quota access requires Spotify's approval and eligibility; do not assume commercial approval.
5. Connect in **Spotify**. The requested scopes are `playlist-read-private`, `playlist-read-collaborative`, and `user-library-read`. Discovery calls `/me`, `/me/playlists`, `/me/tracks` and `/playlists/{id}/items`. Each collection is paginated up to 1,000 items to bound quota usage. Saved-track denial is shown without losing account/playlist results. Playlist contents are restricted to owned/collaborative playlists in new development-mode access; missing fields are optional. A 401 triggers one refresh/retry; 429 applies Retry-After cooldown. The UI reports endpoint/scopes/allowlist errors.

Spotify content never enters analysis, audio nodes, export, or AI. No audio-features, audio-analysis, recommendations, preview download, capture or remix endpoint is used. **Open** hands listening to Spotify and stops local decks. The app does not request playback control scopes or promise in-app streaming. Spotify prohibits overlapping its content with other audio and ingesting its content into AI. The user must follow those restrictions when listening outside this app too.

Official references:
- [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- [Redirect requirements](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri)
- [Developer policy](https://developer.spotify.com/policy)
- [Development API migration](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)
- [July quota update](https://developer.spotify.com/blog/2026-07-23-web-api-quota-updates)
- [Quota modes / approval](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)

## Secure AI backend

The dependency-free Node 22+ service is in `Backend/`. The iOS app contains no OpenAI key, server signing secret or shared static API password. The existing provider credential was reused in the server environment with the user's explicit authorization; it was not copied into source files or the app.

1. Copy `Backend/.env.example` to `Backend/.env` (ignored). Provision your OpenAI API key securely into `OPENAI_API_KEY` and generate at least 32 random characters for `SESSION_SIGNING_SECRET`, on your server only. Choose an available model with Structured Outputs; the configurable default is `gpt-4.1-mini`.
2. Run `npm start` in `Backend`. It binds to loopback by default. Deploy behind a trusted HTTPS reverse proxy; configure its request size and timeout limits. Set `COACH_BASE_URL` in xcconfig to that HTTPS origin. The app refuses insecure HTTP.
3. On the server, run `npm run token -- student-id` to issue a one-hour HMAC-signed bearer token. Treat its output as a credential. Paste it into the app's **Settings** secure field. This administrator-issued token flow is appropriate for a private pilot. A public launch needs your own authenticated sign-in/token issuer (and revocation/abuse controls), not a public token vending route. Never put the signing secret or provider key in the app.
4. Load permitted local tracks in both decks, enable cloud coaching, and opt in to sending local BPM/key. Filenames, audio, waveforms, user prompts, Spotify identifiers and library data are excluded by construction. The backend strictly validates allowed fields and key names, limits each token subject to 20 requests/hour and the service to 200/day by default, uses request timeouts, `store:false`, a strict response schema, and generic upstream errors. It does not log request bodies or credentials. Invalid/incomplete responses preserve the app's offline plan.
5. For production, use a persistent shared quota store across server replicas/restarts, provider spending limits, secret rotation, an authenticated identity provider, monitoring without payload logging, and reviewed privacy disclosures. Current in-memory quotas target one pilot server and reset on restart.

[OpenAI Structured Outputs reference](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses)

## Audio behavior and limits

Imports use the Files picker with security-scoped access, copy into app Documents, and persist a local JSON library with cue points. Supported formats are those AVAudioFile can decode; protected/DRM files are rejected. Import requires an explicit rights acknowledgment. Files must be 1 second–10 minutes. The first 90 seconds feed a bounded analysis using energy-onset autocorrelation and Hann-windowed chroma/Goertzel major/minor profile matching. The displayed waveform covers that analyzed portion, not the full file for tracks longer than 90 seconds. Tempo/key are approximate: sparse, live, ambient, or swung material may be ambiguous; confirm manually by ear. No stems or reliable downbeat/phrase detector is claimed.

Two AVAudioPlayerNodes run through independent time/pitch, high-pass and delay units into an attenuated mixer. Equal-power crossfading can still sum peaks; keep listening volume comfortable. Tempo matching changes rate only, with pitch preservation; cues and manual timing align beats. Four-beat loops begin at the selected playhead; no automatic quantization. Audio interruptions stop both decks. Exports create a local WAV of the selected phrase or beat-repeat edit with short click-reduction fades. This is not a full live-session recorder. Synthesized demo loops were created for this project and may be used freely.

## Checks

From this directory:

```sh
swift test
(cd Backend && npm test)
xcodebuild -project DJTutor.xcodeproj -scheme DJTutor -sdk iphonesimulator -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Core tests also cover mono-to-stereo loop-buffer conversion to prevent the reproduced playback crash. Core tests cover synthetic tempo recovery, silence, constant-power crossfade, edit reversal/fades and phrase timing. Backend tests cover token expiry/tampering, field validation, Spotify-data exclusion, quota resets and malformed coach output. See `VALIDATION.md` for the actual run results and limits.

Manual device acceptance: import WAV/M4A, play both decks and seek/loop, hear tempo/filter/echo changes, relaunch and verify cues, export and reopen WAV, interrupt audio, cancel/deny Spotify OAuth, revoke tokens and reconnect, test an unauthorized playlist and rate limit, expire AI session, disconnect and verify Keychain removal. No live Spotify/AI assertions are made without credentials.
