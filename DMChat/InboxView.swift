import SwiftUI

struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = InboxViewModel()
    @State private var path: [ChatRoute] = []
    @State private var showNew = false

    var body: some View {
        NavigationStack(path: $path) {
            List(vm.chats) { chat in
                if let me = session.user {
                    NavigationLink(value: ChatRoute(chatId: chat.id, otherName: chat.otherName(me: me.id))) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .pink, .orange],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                                .overlay(Text(String(chat.otherName(me: me.id).prefix(1)).uppercased())
                                    .bold().foregroundColor(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.otherName(me: me.id)).font(.headline)
                                Text(chat.lastMessage.isEmpty ? "Say hi 👋" : chat.lastMessage)
                                    .font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(session.user?.username ?? "Messages")
            .navigationDestination(for: ChatRoute.self) { ChatView(route: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Log out") { session.signOut() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showNew) {
                NewChatView(vm: vm) { route in path.append(route) }
            }
        }
        .onAppear { if let id = session.user?.id { vm.start(uid: id) } }
        .onDisappear { vm.stop() }
    }
}

struct NewChatView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    let vm: InboxViewModel
    let onOpen: (ChatRoute) -> Void
    @State private var query = ""
    @State private var found: AppUser?
    @State private var searched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("Search exact username", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(Color(.secondarySystemBackground)).cornerRadius(10)
                    Button("Search") {
                        Task {
                            guard let me = session.user else { return }
                            found = await vm.findUser(username: query, excluding: me.id)
                            searched = true
                        }
                    }
                }
                if let found {
                    Button {
                        Task {
                            guard let me = session.user else { return }
                            let route = await vm.openChat(me: me, other: found)
                            dismiss(); onOpen(route)
                        }
                    } label: {
                        HStack { Text("@\(found.username)").bold(); Spacer(); Text("Chat") }
                            .padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                    }
                } else if searched {
                    Text("No user found").foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("New message")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}
