import Foundation
import WebKit

@MainActor
protocol ArticleExtracting {
    func extract(from url: URL) async throws -> ArticleDocument
}

enum ArticleExtractionError: LocalizedError {
    case unsupportedURL
    case alreadyExtracting
    case navigationFailed(String)
    case timedOut
    case invalidResult
    case noArticleContent

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "This link can’t be opened as a webpage."
        case .alreadyExtracting:
            return "The reader is still preparing another article."
        case .navigationFailed(let message):
            return "Couldn’t load this webpage: \(message)"
        case .timedOut:
            return "The webpage took too long to load."
        case .invalidResult:
            return "The webpage returned content the reader couldn’t understand."
        case .noArticleContent:
            return "We couldn’t find a readable article on this page."
        }
    }
}

/// Extracts a clean, native-reader representation without displaying a webpage.
///
/// WebKit performs the same rendering work a normal browser would, then a fixed,
/// dependency-free script selects likely article content and returns JSON-safe text
/// blocks. No content supplied by a webpage is interpolated into the script.
@MainActor
final class WebKitArticleExtractor: NSObject, ArticleExtracting {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<ArticleDocument, Error>?
    private var timeoutTask: Task<Void, Never>?

    func extract(from url: URL) async throws -> ArticleDocument {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw ArticleExtractionError.unsupportedURL
        }

        guard continuation == nil else {
            throw ArticleExtractionError.alreadyExtracting
        }

        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation

                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()

                let webView = WKWebView(frame: .zero, configuration: configuration)
                webView.navigationDelegate = self
                self.webView = webView

                timeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard !Task.isCancelled else { return }
                    self?.complete(.failure(ArticleExtractionError.timedOut))
                }

                webView.load(URLRequest(url: url))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.complete(.failure(CancellationError()))
            }
        }
    }

    private func complete(_ result: Result<ArticleDocument, Error>) {
        guard let continuation else { return }

        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        continuation.resume(with: result)
    }
}

extension WebKitArticleExtractor: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        guard ["http", "https"].contains(scheme) else {
            decisionHandler(.cancel)
            if navigationAction.targetFrame?.isMainFrame == true {
                Task { @MainActor [weak self] in
                    self?.complete(.failure(ArticleExtractionError.unsupportedURL))
                }
            }
            return
        }

        decisionHandler(.allow)
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.complete(.failure(ArticleExtractionError.navigationFailed(error.localizedDescription)))
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.complete(.failure(ArticleExtractionError.navigationFailed(error.localizedDescription)))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        Task { @MainActor [weak self] in
            guard let self, self.webView === webView else { return }

            do {
                let value = try await webView.evaluateJavaScript(Self.extractionScript)
                guard let json = value as? String,
                      let data = json.data(using: .utf8) else {
                    complete(.failure(ArticleExtractionError.invalidResult))
                    return
                }

                let response = try JSONDecoder().decode(ExtractionResponse.self, from: data)
                let blocks = response.blocks.compactMap { block -> ArticleBlock? in
                    guard let kind = ArticleBlock.Kind(rawValue: block.kind) else { return nil }
                    let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return ArticleBlock(kind: kind, text: text)
                }

                let bodyLength = blocks.reduce(into: 0) { $0 += $1.text.count }
                guard blocks.count >= 2, bodyLength >= 200 else {
                    complete(.failure(ArticleExtractionError.noArticleContent))
                    return
                }

                complete(.success(ArticleDocument(
                    url: webView.url ?? response.url,
                    title: response.title,
                    siteName: response.siteName,
                    byline: response.byline,
                    blocks: blocks
                )))
            } catch is CancellationError {
                complete(.failure(CancellationError()))
            } catch {
                complete(.failure(ArticleExtractionError.invalidResult))
            }
        }
    }
}

private extension WebKitArticleExtractor {
    struct ExtractionResponse: Decodable {
        struct Block: Decodable {
            let kind: String
            let text: String
        }

        let url: URL
        let title: String
        let siteName: String?
        let byline: String?
        let blocks: [Block]
    }

    /// This script has no inputs. It removes common non-content regions, prefers
    /// semantic article/main containers, and falls back to a scored text container.
    static let extractionScript = #"""
    (() => {
      const clean = (value) => (value || '').replace(/\s+/g, ' ').trim();
      const meta = (name) => {
        const element = document.querySelector(`meta[property="${name}"], meta[name="${name}"]`);
        return clean(element && element.getAttribute('content'));
      };
      const ignored = 'script,style,noscript,nav,footer,header,aside,form,iframe,button,svg,canvas,[role="navigation"],[role="banner"],[role="complementary"],.advertisement,.advert,.ads,.social,.share,.newsletter,.comments,.cookie,.modal';
      const score = (element) => {
        const text = clean(element.innerText);
        if (text.length < 120) return -1;
        const paragraphs = element.querySelectorAll('p').length;
        const linkText = Array.from(element.querySelectorAll('a')).reduce((sum, link) => sum + clean(link.innerText).length, 0);
        return text.length + paragraphs * 180 - linkText * 0.6;
      };
      const candidates = Array.from(document.querySelectorAll('article, main, [role="main"], .entry-content, .post-content, .article-content, .article-body, #article, section, div'));
      let root = document.querySelector('article, main, [role="main"], .entry-content, .post-content, .article-content, .article-body, #article');
      if (!root) root = candidates.reduce((best, candidate) => score(candidate) > score(best) ? candidate : best, document.body);
      const content = root.cloneNode(true);
      content.querySelectorAll(ignored).forEach((element) => element.remove());
      const blocks = [];
      const seen = new Set();
      content.querySelectorAll('h1,h2,h3,h4,p,blockquote,li').forEach((element) => {
        const text = clean(element.innerText);
        if (!text || seen.has(text)) return;
        seen.add(text);
        const tag = element.tagName.toLowerCase();
        blocks.push({
          kind: tag.startsWith('h') ? 'heading' : tag === 'blockquote' ? 'quote' : tag === 'li' ? 'listItem' : 'paragraph',
          text
        });
      });
      const title = meta('og:title') || clean(content.querySelector('h1')?.innerText) || clean(document.querySelector('h1')?.innerText) || clean(document.title) || location.hostname;
      return JSON.stringify({
        url: location.href,
        title,
        siteName: meta('og:site_name') || location.hostname,
        byline: meta('author') || meta('article:author') || '',
        blocks
      });
    })()
    """#
}
