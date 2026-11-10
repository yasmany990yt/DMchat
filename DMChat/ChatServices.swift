import Foundation
import FirebaseFirestore

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func start(uid: String) {
        listener?.remove()
        listener = db.collection("chats")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                let items = docs.map { d -> Chat in
                    let data = d.data()
                    return Chat(
                        id: d.documentID,
                        members: data["members"] as? [String] ?? [],
                        names: data["names"] as? [String: String] ?? [:],
                        lastMessage: data["lastMessage"] as? String ?? "",
                        lastDate: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                self?.chats = items.sorted { $0.lastDate > $1.lastDate }
            }
    }

    func stop() { listener?.remove() }

    func findUser(username: String, excluding uid: String) async -> AppUser? {
        let name = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let snap = try? await db.collection("users")
            .whereField("username", isEqualTo: name).limit(to: 1).getDocuments()
        guard let doc = snap?.documents.first, doc.documentID != uid else { return nil }
        return AppUser(id: doc.documentID, username: name)
    }

    func openChat(me: AppUser, other: AppUser) async -> ChatRoute {
        let id = chatId(me.id, other.id)
        try? await db.collection("chats").document(id).setData([
            "members": [me.id, other.id],
            "names": [me.id: me.username, other.id: other.username]
        ], merge: true)
        return ChatRoute(chatId: id, otherName: other.username)
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func start(chatId: String) {
        listener?.remove()
        listener = db.collection("chats").document(chatId).collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.messages = docs.map { d in
                    let data = d.data()
                    return Message(
                        id: d.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        date: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    func stop() { listener?.remove() }

    func send(text: String, chatId: String, senderId: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let ref = db.collection("chats").document(chatId)
        try? await ref.collection("messages").addDocument(data: [
            "senderId": senderId,
            "text": clean,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try? await ref.updateData([
            "lastMessage": clean,
            "lastMessageAt": FieldValue.serverTimestamp()
        ])
    }
}
