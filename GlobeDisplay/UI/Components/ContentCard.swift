import SwiftUI

/// A grid card displaying a content bundle's thumbnail, title, and resolution.
struct ContentCard: View {
    let bundle: ContentBundle
    let isSelected: Bool

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnailView
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(selectionBorder)

            HStack(alignment: .top) {
                Text(bundle.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Info about \(bundle.title)")
            }

            Text("\(Int(bundle.resolution.width))×\(Int(bundle.resolution.height))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bundle.title)
        .accessibilityHint("Double-tap to display on globe")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .sheet(isPresented: $showInfo) {
            ContentInfoSheet(bundle: bundle)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .topTrailing) {
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

            if isDownloadable {
                Image(systemName: "cloud.arrow.down")
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(6)
                    .accessibilityLabel("Downloadable content")
            }
        }
    }

    /// True when the bundle is marked as downloadable but not yet locally present.
    private var isDownloadable: Bool {
        bundle.source == .downloaded && bundle.assets.downloadURL != nil
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    }

    private func loadBundledImage() -> UIImage? {
        guard let name = bundle.assets.primaryImageName else { return nil }
        if let ui = UIImage(named: name) { return ui }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg")
               ?? Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Info Sheet

private struct ContentInfoSheet: View {

    let bundle: ContentBundle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Thumbnail header
                    if let uiImage = loadThumbnail() {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(2, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description
                    Text(bundle.description)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Divider()

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        metaRow(label: "Category", value: bundle.category.displayName)
                        metaRow(label: "Resolution",
                                value: "\(Int(bundle.resolution.width)) × \(Int(bundle.resolution.height))")
                        metaRow(label: "Source", value: bundle.attribution)
                        metaRow(label: "License", value: bundle.license)
                    }
                }
                .padding()
            }
            .navigationTitle(bundle.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func metaRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout)
        }
    }

    private func loadThumbnail() -> UIImage? {
        guard let name = bundle.assets.primaryImageName else { return nil }
        if let ui = UIImage(named: name) { return ui }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg")
               ?? Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
