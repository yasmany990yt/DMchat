# DMChat – text-only DM app for iPhone (SwiftUI + Firebase)

## 1. Firebase (free tier)
1. console.firebase.google.com -> new project.
2. Add an iOS app with bundle ID `com.yasmany.dmchat` -> download `GoogleService-Info.plist`.
3. Build -> Authentication -> enable **Email/Password**.
4. Build -> Firestore Database -> create (production mode) -> Rules tab -> paste `firestore.rules` -> Publish.

## 2. Build the .ipa without a Mac (GitHub Actions)
1. Push this folder to a new private GitHub repo (branch `main`).
2. On Windows, run in PowerShell:
   `[Convert]::ToBase64String([IO.File]::ReadAllBytes("GoogleService-Info.plist")) | Set-Clipboard`
3. Repo -> Settings -> Secrets and variables -> Actions -> new secret
   `GOOGLE_SERVICE_INFO_PLIST_BASE64` = paste.
4. Actions tab -> "Build IPA" -> Run workflow -> download the `DMChat-ipa` artifact.

## 3. Install on your iPhone
The .ipa is unsigned. Sign + install it with Sideloadly or AltStore (free Apple ID;
the app expires every 7 days and must be re-signed).

## With a Mac instead
`brew install xcodegen && xcodegen generate`, put `GoogleService-Info.plist` in `DMChat/`,
open `DMChat.xcodeproj`, pick your team, Run.

## No iPhone? Test in the browser (Appetize.io)
The default workflow ("Build Simulator App") now produces `DMChat-simulator.zip`.
Upload that zip at appetize.io (Apps > Upload App, platform iOS) and run it in your browser.
The real-iPhone `.ipa` build is still available: Actions > "Build IPA (real iPhone, manual)" > Run workflow.
