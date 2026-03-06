import SwiftUI

/// First-run setup guide shown on initial launch.
struct OnboardingView: View {

    let onDismiss: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "cable.connector.horizontal",
            imageColor: .blue,
            title: "Connect Your Globe",
            body: "Attach a USB-C Digital AV Adapter to your iPad, then connect an HDMI cable from the adapter to the MagicPlanet globe's projector input."
        ),
        OnboardingPage(
            systemImage: "display.2",
            imageColor: .green,
            title: "Globe Detected Automatically",
            body: "Once connected, the globe display will be detected automatically. The status indicator in the bottom toolbar will turn green. The iPad screen is your control panel — the globe shows the content."
        ),
        OnboardingPage(
            systemImage: "globe.americas.fill",
            imageColor: .cyan,
            title: "Browse & Display Content",
            body: "Choose from planetary textures, Earth datasets, and more in the content browser. Tap any item to send it to the globe instantly."
        ),
        OnboardingPage(
            systemImage: "waveform.path.ecg",
            imageColor: .red,
            title: "Live Data Overlays",
            body: "Enable real-time earthquake, volcano, and wildfire overlays using the toggle buttons in the bottom toolbar. Data updates automatically in the background."
        ),
        OnboardingPage(
            systemImage: "gear",
            imageColor: .gray,
            title: "Calibrate Your Display",
            body: "Use the Settings screen (gear icon in the sidebar) to adjust brightness or flip the image if your globe's orientation doesn't match. Use the rotation slider to align the prime meridian."
        ),
    ]

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("Welcome to GlobeDisplay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if page == pages.count - 1 {
                        Button("Get Started") { onDismiss() }
                            .fontWeight(.semibold)
                    } else {
                        Button("Skip") { onDismiss() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: p.systemImage)
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(p.imageColor)
                .frame(height: 90)

            VStack(spacing: 12) {
                Text(p.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(p.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

private struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let body: String
}
