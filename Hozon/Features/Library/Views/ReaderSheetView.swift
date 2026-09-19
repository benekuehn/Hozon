import SwiftUI

@MainActor
struct ReaderSheetView: View {
    let link: Link
    let extractor: any ArticleExtracting

    init(link: Link) {
        self.init(link: link, extractor: WebKitArticleExtractor())
    }

    init(link: Link, extractor: any ArticleExtracting) {
        self.link = link
        self.extractor = extractor
    }

    var body: some View {
        NavigationStack {
            ArticleReaderView(
                link: link,
                extractor: extractor,
                showsCloseButton: true
            )
        }
    }
}

@MainActor
struct ArticleReaderView: View {
    private enum LoadState {
        case loading
        case loaded(ArticleDocument)
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss

    let link: Link
    let extractor: any ArticleExtracting

    @State private var loadState: LoadState = .loading
    @State private var loadAttempt = UUID()
    @State private var originalPage: OriginalPagePresentation?

    init(link: Link) {
        self.init(
            link: link,
            extractor: WebKitArticleExtractor(),
            showsCloseButton: false
        )
    }

    init(
        link: Link,
        extractor: any ArticleExtracting,
        showsCloseButton: Bool = false
    ) {
        self.link = link
        self.extractor = extractor
        self.showsCloseButton = showsCloseButton
    }

    let showsCloseButton: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                articleHeader
                readerContent
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(AppTheme.background)
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Open Original", systemImage: "safari") {
                    originalPage = OriginalPagePresentation(url: link.url)
                }
            }
        }
        .task(id: "\(link.url.absoluteString)-\(loadAttempt.uuidString)") {
            await loadArticle()
        }
        .fullScreenCover(item: $originalPage) { presentation in
            BrowserSheetView(url: presentation.url)
        }
    }

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayTitle)
                .font(.system(.title, design: .serif).weight(.semibold))
                .textSelection(.enabled)

            Text(metadata)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        switch loadState {
        case .loading:
            HStack {
                Spacer()
                ProgressView("Preparing article…")
                Spacer()
            }
            .padding(.vertical, 48)

        case .loaded(let article):
            ArticleBlocksView(blocks: article.blocks)

        case .failed(let message):
            ContentUnavailableView {
                Label("Reader Unavailable", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", systemImage: "arrow.clockwise") {
                    retry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private var displayTitle: String {
        if case .loaded(let article) = loadState, !article.title.isEmpty {
            return article.title
        }
        return link.title
    }

    private var isLoading: Bool {
        if case .loading = loadState {
            return true
        }
        return false
    }

    private func retry() {
        guard !isLoading else { return }
        loadState = .loading
        loadAttempt = UUID()
    }

    private var metadata: String {
        let article: ArticleDocument?
        if case .loaded(let loadedArticle) = loadState {
            article = loadedArticle
        } else {
            article = nil
        }

        return [article?.siteName ?? link.domain, article?.byline ?? link.author]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func loadArticle() async {
        loadState = .loading

        do {
            let article = try await extractor.extract(from: link.url)
            guard !Task.isCancelled else { return }
            loadState = .loaded(article)
        } catch is CancellationError {
            // Dismissing the sheet cancels its task; that is not an error state.
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(error.localizedDescription)
        }
    }
}

private struct ArticleBlocksView: View {
    let blocks: [ArticleBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .heading:
                    Text(block.text)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .textSelection(.enabled)
                        .padding(.top, 8)
                case .paragraph:
                    Text(block.text)
                        .font(.system(.body, design: .serif).leading(.loose))
                        .textSelection(.enabled)
                case .quote:
                    Text(block.text)
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.tertiary)
                                .frame(width: 3)
                        }
                case .listItem:
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                        Text(block.text)
                            .font(.system(.body, design: .serif).leading(.loose))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct OriginalPagePresentation: Identifiable {
    let url: URL

    var id: URL { url }
}
