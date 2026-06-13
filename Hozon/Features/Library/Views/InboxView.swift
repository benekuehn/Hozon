import SwiftUI

struct InboxView: View {
    @State private var store: LinksStore
    @State private var selectedLink: Link?

    init(store: LinksStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            List(store.links) { link in
                Button {
                    selectedLink = link
                } label: {
                    LinkRowView(link: link)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Inbox")
            .overlay {
                if store.isLoading {
                    ProgressView()
                }
            }
            .task {
                await store.loadInbox()
            }
            .sheet(item: $selectedLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
        }
    }
}
