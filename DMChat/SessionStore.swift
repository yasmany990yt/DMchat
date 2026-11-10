import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SessionStore: ObservableObject {
    @Published var user: AppUser?
    @Published var errorMessage: String?
    @Published var busy = false

    private var handle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, fbUser in
            Task { @MainActor in
                guard let self else { return }
                if let fbUser { await self.loadProfile(uid: fbUser.uid) } else { self.user = nil }
            }
        }
    }

    private func loadProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let name = doc.data()?["username"] as? String {
                user = AppUser(id: uid, username: name)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func signIn(email: String, password: String) async {
        busy = true; defer { busy = false }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func signUp(email: String, password: String, username: String) async {
        busy = true; defer { busy = false }
        let name = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard name.count >= 3 else { errorMessage = "Username must be at least 3 characters."; return }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let taken = try await db.collection("users")
                .whereField("username", isEqualTo: name).limit(to: 1).getDocuments()
            if !taken.isEmpty {
                try? await result.user.delete()
                errorMessage = "That username is taken."
                return
            }
            try await db.collection("users").document(result.user.uid).setData(["username": name])
            user = AppUser(id: result.user.uid, username: name)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func signOut() { try? Auth.auth().signOut() }
}
