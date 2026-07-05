import SwiftUI

struct LinkRowView: View {
    let link: Link

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: faviconURL(for: link.url)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.rowIconBackground)
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(link.title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 52, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func faviconURL(for pageURL: URL) -> URL? {
        URL(string: "https://www.google.com/s2/favicons?sz=128&domain_url=\(pageURL.absoluteString)")
    }
}
