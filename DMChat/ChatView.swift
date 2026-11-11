import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    @EnvironmentObject var session: SessionStore
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("typingIndicator") private var typingIndicator = true
    @StateObject private var vm = ChatViewModel()
    let route: ChatRoute
    @State private var draft = ""
    @State private var pick: PhotosPickerItem?
    @State private var replyTo: Message?
    @State private var fullImage: UIImage?
    @State private var showGif = false
    @State private var showFiles = false
    @State private var shareURL: URL?
    @State private var fileNote = ""

    private var me: String { session.user?.id ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.messages) { bubble($0).id($0.id) }
                        if let last = vm.messages.last, last.senderId == me, vm.otherSeen >= last.date {
                            Text("Seen").font(.caption2).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        if vm.otherTyping { Text("typing...").font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading) }
                    }.padding(12)
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    if readReceipts { Task { await vm.markSeen(chatId: route.chatId, me: me) } }
                }
            }
            if let r = replyTo {
                HStack {
                    Text("Replying: \(r.text.isEmpty ? "📷 Photo" : r.text)").font(.caption).lineLimit(1)
                    Spacer()
                    Button { replyTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                }.padding(.horizontal, 12).padding(.vertical, 6).background(Color(.secondarySystemBackground))
            }
            HStack(spacing: 8) {
                PhotosPicker(selection: $pick, matching: .images) { Image(systemName: "photo").font(.title3) }
                Button { showGif = true } label: { Text("GIF").font(.caption.bold()).padding(4).overlay(RoundedRectangle(cornerRadius: 5).stroke()) }
                Button { showFiles = true } label: { Image(systemName: "paperclip").font(.title3) }
                TextField("Message...", text: $draft, axis: .vertical).lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground)).cornerRadius(22)
                Button("Send") { send(image: nil) }.bold()
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(10)
        }
        .navigationTitle(route.otherName).navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.start(chatId: route.chatId, otherId: route.otherId)
            if readReceipts { Task { await vm.markSeen(chatId: route.chatId, me: me) } }
        }
        .onDisappear {
            vm.stop(); Task { await vm.setTyping(false, chatId: route.chatId, me: me) }
        }
        .onChange(of: draft) { text in
            guard typingIndicator else { return }
            Task { await vm.setTyping(!text.isEmpty, chatId: route.chatId, me: me) }
        }
        .onChange(of: pick) { item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let c = Self.compressed(d) { send(image: c) }
                pick = nil
            }
        }
        .sheet(isPresented: $showGif) { GifPicker { url in send(gif: url) } }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let u = shareURL { ActivityView(url: u) }
        }
        .alert(fileNote, isPresented: Binding(get: { !fileNote.isEmpty }, set: { if !$0 { fileNote = "" } })) { Button("OK") {} }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            guard let d = try? Data(contentsOf: url) else { return }
            if d.count > 700_000 { fileNote = "That file is too big (max 700 KB)." } else { send(file: d, name: url.lastPathComponent) }
        }
        .sheet(isPresented: Binding(get: { fullImage != nil }, set: { if !$0 { fullImage = nil } })) {
            if let img = fullImage { Image(uiImage: img).resizable().scaledToFit().padding() }
        }
    }

    private func send(image: Data? = nil, gif: String? = nil, file: Data? = nil, name: String? = nil) {
        let text = (image == nil && gif == nil && file == nil) ? draft : ""
        let reply = replyTo.map { $0.unsent ? "Unsent message" : ($0.text.isEmpty ? "📷 Photo" : $0.text) }
        draft = ""; replyTo = nil
        Task { await vm.send(text: text, image: image, replyText: reply, chatId: route.chatId, senderId: me,
                                gif: gif, file: file, fileName: name) }
    }

    static func compressed(_ data: Data) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, 800 / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.5)
    }

    @ViewBuilder
    private func bubble(_ msg: Message) -> some View {
        let mine = msg.senderId == me
        HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if let r = msg.replyText {
                    Text("↩︎ \(r)").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                content(msg, mine: mine)
                    .onTapGesture(count: 2) { Task { await vm.react(chatId: route.chatId, msgId: msg.id, me: me, emoji: "❤️") } }
                    .contextMenu {
                        if !msg.unsent {
                            ForEach(["❤️", "😂", "😮", "😢", "👍"], id: \.self) { e in
                                Button(e) { Task { await vm.react(chatId: route.chatId, msgId: msg.id, me: me, emoji: e) } }
                            }
                            Button("Reply") { replyTo = msg }
                            if !msg.text.isEmpty { Button("Copy") { UIPasteboard.general.string = msg.text } }
                            if mine { Button("Unsend", role: .destructive) { Task { await vm.unsend(chatId: route.chatId, msgId: msg.id) } } }
                        }
                    }
                if !msg.reactions.isEmpty {
                    Text(msg.reactions.values.joined()).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemGray5)).clipShape(Capsule())
                }
            }
            if !mine { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private func content(_ msg: Message, mine: Bool) -> some View {
        if msg.unsent {
            Text("Message unsent").italic().font(.subheadline).foregroundColor(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray4)))
        } else if let g = msg.gif, let u = URL(string: g) {
            GifView(url: u).frame(width: 200, height: 160).cornerRadius(18)
        } else if let f = msg.file {
            Button {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(msg.fileName ?? "file")
                try? f.write(to: url); shareURL = url
            } label: {
                Label("\(msg.fileName ?? "file") · \(f.count / 1024) KB", systemImage: "doc").font(.subheadline)
                    .padding(.horizontal, 14).padding(.vertical, 9).background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }.buttonStyle(.plain)
        } else if let d = msg.image, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: 220).cornerRadius(18)
                .onTapGesture { fullImage = ui }
        } else {
            Text(msg.text).padding(.horizontal, 14).padding(.vertical, 9)
                .foregroundColor(mine ? .white : .primary)
                .background(mine ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                 : AnyShapeStyle(Color(.systemGray5)))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
