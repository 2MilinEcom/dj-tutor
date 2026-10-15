# DJ Tutor

Native iPad DJ learning companion with illustrated lessons, practice prompts, and an optional teaching backend.

## Technology

SwiftUI, Swift, Python.

## Run locally

Open `DJTutor.xcodeproj` with Xcode and configure your own signing team in `Config/App.xcconfig`. Download the third-party LinkKit dependency using `Scripts/fetch-linkkit.sh`; it is not redistributed in this snapshot. See `Backend/package.json` and `Backend/.env.example` for the optional teaching backend. No account tokens or signed device build are included.

## Portfolio snapshot

This repository contains a source snapshot of a personal project. Personal records, credentials, browser sessions, local databases, and generated output are excluded. Use your own configuration and fictional data when evaluating it. Some integrations require external accounts or additional setup. This is a development project, with feature limitations documented in the source and guides.

See [the project guide](PROJECT_GUIDE.md) for implementation details and earlier development notes. Verification claims in that guide describe the original working copy; they are not a fresh end-to-end test of this portfolio snapshot.
