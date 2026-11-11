import Foundation

struct AppUser: Identifiable, Hashable {
    let id: String
    let username: String
}

struct Chat: Identifiable, Hashable {
    let id: String
    let members: [String]
    let names: [String: String]
    let lastMessage: String
    let lastDate: Date
    func otherId(me: String) -> String { members.first { $0 != me } ?? me }
    func otherName(me: String) -> String { names[otherId(me: me)] ?? "user" }
}

struct Message: Identifiable, Hashable {
    let id: String
    let senderId: String
    let text: String
    let date: Date
    var image: Data? = nil
    var replyText: String? = nil
    var reactions: [String: String] = [:]
    var unsent = false
    var gif: String? = nil
    var file: Data? = nil
    var fileName: String? = nil
}

struct ChatRoute: Hashable {
    let chatId: String
    let otherId: String
    let otherName: String
}

func chatId(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "_") }
