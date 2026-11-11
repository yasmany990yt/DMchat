import SwiftUI
import WebKit

struct GifView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.isOpaque = false; w.backgroundColor = .clear; w.scrollView.isScrollEnabled = false
        return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {
        w.loadHTMLString("<meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0'><img src='\(url.absoluteString)' style='width:100%;height:100%;object-fit:cover'></body>", baseURL: nil)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ c: UIActivityViewController, context: Context) {}
}

struct GifPicker: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [String] = []
    @State private var message = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search GIFs", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal)
                    .onSubmit { Task { await search() } }
                if !message.isEmpty { Text(message).font(.footnote).foregroundColor(.red).padding() }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(results, id: \.self) { u in
                            AsyncImage(url: URL(string: u)) { $0.resizable().scaledToFill() } placeholder: { Color(.systemGray5) }
                                .frame(height: 110).clipped().cornerRadius(8)
                                .onTapGesture { onPick(u); dismiss() }
                        }
                    }.padding(.horizontal)
                }
            }
            .navigationTitle("GIFs").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .task { await search() }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        var c = URLComponents(string: "https://api.giphy.com/v1/gifs/" + (q.isEmpty ? "trending" : "search"))!
        c.queryItems = [URLQueryItem(name: "api_key", value: giphyKey), URLQueryItem(name: "limit", value: "24"),
                        URLQueryItem(name: "rating", value: "pg-13")] + (q.isEmpty ? [] : [URLQueryItem(name: "q", value: q)])
        do {
            let (d, _) = try await URLSession.shared.data(from: c.url!)
            guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let arr = j["data"] as? [[String: Any]] else { message = "No results. Check your GIPHY key."; return }
            results = arr.compactMap { (($0["images"] as? [String: Any])?["fixed_height"] as? [String: Any])?["url"] as? String }
            message = results.isEmpty ? "No GIFs found." : ""
        } catch { message = error.localizedDescription }
    }
}
