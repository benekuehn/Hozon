import SwiftUI
import WebKit

struct SafariView: View {
    let url: URL
    @State private var webView: WKWebView

    init(url: URL) {
        self.url = url
        _webView = State(initialValue: WebViewPrewarmer.shared.takeWebView())
    }

    var body: some View {
        WebView(webView: webView, url: url)
    }

    static func prewarm() {
        WebViewPrewarmer.shared.prewarm()
    }
}

private struct WebView: UIViewRepresentable {
    let webView: WKWebView
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}

@MainActor
private final class WebViewPrewarmer {
    static let shared = WebViewPrewarmer()

    private var warmedWebView: WKWebView?

    private init() {}

    func prewarm() {
        guard warmedWebView == nil else { return }
        let webView = Self.makeWebView()
        webView.loadHTMLString("", baseURL: nil)
        warmedWebView = webView
    }

    func takeWebView() -> WKWebView {
        if let webView = warmedWebView {
            warmedWebView = nil
            prewarm()
            return webView
        }

        return Self.makeWebView()
    }

    private static func makeWebView() -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
}
