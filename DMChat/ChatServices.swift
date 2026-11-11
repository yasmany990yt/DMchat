import Foundation
import FirebaseFirestore

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func start(uid: String) {
        listener?.remove()
        listener = db.collection("chats").whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                let items = docs.map { d -> Chat in
                    let x = d.data()
                    return Chat(id: d.documentID, members: x["members"] as? [String] ?? [],
                                names: x["names"] as? [String: String] ?? [:],
                                lastMessage: x["lastMessage"] as? String ?? "",
                                lastDate: (x["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date())
                }
                self?.chats = items.sorted { $0.lastDate > $1.lastDate }
            }
    }
    func stop() { listener?.remove() }

    func findUser(username: String, excluding uid: String) async -> AppUser? {
        let name = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let snap = try? await db.collection("users").whereField("username", isEqualTo: name).limit(to: 1).getDocuments()
        guard let doc = snap?.documents.first, doc.documentID != uid else { return nil }
        return AppUser(id: doc.documentID, username: name)
    }

    func openChat(me: AppUser, other: AppUser) async -> ChatRoute {
        let id = chatId(me.id, other.id)
        try? await db.collection("chats").document(id).setData([
            "members": [me.id, other.id],
            "names": [me.id: me.username, other.id: other.username]
        ], merge: true)
        return ChatRoute(chatId: id, otherId: other.id, otherName: other.username)
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var otherTyping = false
    @Published var otherSeen = Date.distantPast
    private var l1: ListenerRegistration?
    private var l2: ListenerRegistration?
    private let db = Firestore.firestore()

    func start(chatId: String, otherId: String) {
        stop()
        let ref = db.collection("chats").document(chatId)
        l1 = ref.collection("messages").order(by: "createdAt").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            self?.messages = docs.map { d in
                let x = d.data()
                return Message(id: d.documentID, senderId: x["senderId"] as? String ?? "",
                               text: x["text"] as? String ?? "",
                               date: (x["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                               image: x["image"] as? Data, replyText: x["replyText"] as? String,
                               reactions: x["reactions"] as? [String: String] ?? [:],
                               unsent: x["unsent"] as? Bool ?? false,
                               gif: x["gif"] as? String, file: x["file"] as? Data, fileName: x["fileName"] as? String)
            }
        }
        l2 = ref.addSnapshotListener { [weak self] snap, _ in
            let x = snap?.data() ?? [:]
            self?.otherTyping = (x["typing"] as? [String: Bool])?[otherId] ?? false
            self?.otherSeen = ((x["seen"] as? [String: Timestamp])?[otherId])?.dateValue() ?? .distantPast
        }
    }
    func stop() { l1?.remove(); l2?.remove() }

    func send(text: String, image: Data?, replyText: String?, chatId: String, senderId: String,
                  gif: String? = nil, file: Data? = nil, fileName: String? = nil) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty || image != nil || gif != nil || file != nil else { return }
        let ref = db.collection("chats").document(chatId)
        var data: [String: Any] = ["senderId": senderId, "text": clean, "createdAt": FieldValue.serverTimestamp()]
        if let image { data["image"] = image }
        if let gif { data["gif"] = gif }
        if let file { data["file"] = file; data["fileName"] = fileName ?? "file" }
        if let replyText { data["replyText"] = replyText }
        try? await ref.collection("messages").addDocument(data: data)
        try? await ref.updateData(["lastMessage": image != nil ? "📷 Photo" : gif != nil ? "GIF" : file != nil ? "📎 File" : clean,
                                   "lastMessageAt": FieldValue.serverTimestamp(),
                                   "typing.\(senderId)": false])
    }

    func react(chatId: String, msgId: String, me: String, emoji: String) async {
        let ref = db.collection("chats").document(chatId).collection("messages").document(msgId)
        try? await ref.updateData(["reactions.\(me)": emoji])
    }

    func unsend(chatId: String, msgId: String) async {
        let ref = db.collection("chats").document(chatId).collection("messages").document(msgId)
        try? await ref.updateData(["unsent": true, "text": "", "image": FieldValue.delete(),
                                   "gif": FieldValue.delete(), "file": FieldValue.delete()])
    }

    func markSeen(chatId: String, me: String) async {
        try? await db.collection("chats").document(chatId).updateData(["seen.\(me)": FieldValue.serverTimestamp()])
    }

    func setTyping(_ on: Bool, chatId: String, me: String) async {
        try? await db.collection("chats").document(chatId).updateData(["typing.\(me)": on])
    }
}
