import SwiftUI

/// A grid card displaying a content bundle's thumbnail, title, and resolution.
struct ContentCard: View {
    let bundle: ContentBundle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnailView
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(selectionBorder)

            Text(bundle.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text("\(Int(bundle.resolution.width))×\(Int(bundle.resolution.height))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bundle.title)
        .accessibilityHint("Double-tap to display on globe")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let uiImage = loadBundledImage() {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(2, contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .aspectRatio(2, contentMode: .fill)
                .overlay(
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    }

    private func loadBundledImage() -> UIImage? {
        guard let name = bundle.assets.primaryImageName else { return nil }
        if let ui = UIImage(named: name) { return ui }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg",
                                         subdirectory: "BundledContent")
               ?? Bundle.main.url(forResource: name, withExtension: "png",
                                   subdirectory: "BundledContent"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
