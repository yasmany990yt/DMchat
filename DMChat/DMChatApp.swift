import SwiftUI
import FirebaseCore

@main
struct DMChatApp: App {
    @StateObject private var session: SessionStore

    init() {
        FirebaseApp.configure()
        _session = StateObject(wrappedValue: SessionStore())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.user == nil { AuthView() } else { InboxView() }
            }
            .environmentObject(session)
        }
    }
}
