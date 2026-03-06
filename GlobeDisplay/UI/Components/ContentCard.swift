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
        ZStack(alignment: .bottomTrailing) {
            if let uiImage = loadBundledImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(2, contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .aspectRatio(2, contentMode: .fill)
                    .overlay(
                        Image(systemName: bundle.contentType == .imageSequence ? "film" : "globe")
                            .foregroundStyle(.secondary)
                    )
            }

            if let progress = currentDownloadProgress {
                // Download in progress: show progress bar overlay.
                VStack(spacing: 3) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.cyan)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(6)
            } else if isDownloadable {
                // Not downloaded yet: show download button.
                Button {
                    ContentDownloader.shared.download(bundle: bundle)
                } label: {
                    Label("Download", systemImage: "cloud.arrow.down.fill")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("Download \(bundle.title)")
            }
        }
    }

    /// True when the bundle has a remote URL and has not yet been downloaded.
    private var isDownloadable: Bool {
        bundle.assets.downloadURL != nil && !ContentManager.shared.isDownloaded(bundle.id)
    }

    /// Non-nil during an active download for this bundle (0.0 – 1.0).
    private var currentDownloadProgress: Double? {
        ContentDownloader.shared.downloadProgress[bundle.id]
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
