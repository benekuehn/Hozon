import SwiftUI

struct LinksView: View {
    let title: String
    let store: LinksStore
    let showsArchiveAction: Bool
    let showsDeleteAction: Bool
    @State private var selectedLink: Link?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.links) { link in
                    Button {
                        selectedLink = link
                    } label: {
                        LinkRowView(link: link)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await store.loadNextPageIfNeeded(currentLink: link)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: showsArchiveAction) {
                        if showsArchiveAction {
                            Button {
                                Task {
                                    await store.archiveLink(link)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: showsDeleteAction) {
                        if showsDeleteAction {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteLink(link)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }    
                }

                if store.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .navigationTitle(title)
            .overlay {
                if store.isLoading {
                    ProgressView()
                } else if let errorMessage = store.errorMessage, store.links.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Could not load \(title.lowercased())")
                            .font(.headline)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            Task {
                                await store.load()
                            }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(item: $selectedLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
        }
    }
}
