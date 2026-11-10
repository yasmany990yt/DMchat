import SwiftUI

struct ChatView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var vm = ChatViewModel()
    let route: ChatRoute
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.messages) { msg in
                            bubble(msg).id(msg.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            HStack(spacing: 8) {
                TextField("Message...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground)).cornerRadius(22)
                Button("Send") { send() }
                    .bold().disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .navigationTitle(route.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start(chatId: route.chatId) }
        .onDisappear { vm.stop() }
    }

    private func send() {
        guard let me = session.user else { return }
        let text = draft; draft = ""
        Task { await vm.send(text: text, chatId: route.chatId, senderId: me.id) }
    }

    @ViewBuilder
    private func bubble(_ msg: Message) -> some View {
        let mine = msg.senderId == session.user?.id
        HStack {
            if mine { Spacer(minLength: 50) }
            Text(msg.text)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundColor(mine ? .white : .primary)
                .background(
                    mine ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                         : AnyShapeStyle(Color(.systemGray5))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            if !mine { Spacer(minLength: 50) }
        }
    }
}
