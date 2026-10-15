# DJ Tutor

I built DJ Tutor to help me work through the controls and basic transitions in djay. I included short lessons, animated control demonstrations, practice prompts, and an optional question and answer service.

I used SwiftUI and Swift for the app, with a separate JavaScript teaching service. The guide does not listen to my music or control djay. I use the listening and visual checks in each lesson to judge the result myself.

## Running it

I open `DJTutor.xcodeproj` in Xcode and configure my own development team in `Config/App.xcconfig`. I fetch LinkKit with `Scripts/fetch-linkkit.sh` before building. I configure the optional teaching service using `Backend/.env.example`.

I keep more setup details and feature limits in the [project guide](PROJECT_GUIDE.md).
