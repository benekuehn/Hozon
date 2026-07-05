import SwiftUI

struct LinkRowView: View {
    let link: Link

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: faviconURL(for: link.url)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(link.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func faviconURL(for pageURL: URL) -> URL? {
        URL(string: "https://www.google.com/s2/favicons?sz=128&domain_url=\(pageURL.absoluteString)")
    }
}
