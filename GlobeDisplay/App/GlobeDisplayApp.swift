import SwiftUI

@main
struct GlobeDisplayApp: App {

    @State private var appState = AppState()
    @State private var renderEngine: RenderEngine? = {
        try? RenderEngine.make()
    }()
    @State private var overlayController = OverlayController()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let engine = renderEngine {
                    ControlPanelView()
                        .environment(appState)
                        .environment(ContentManager.shared)
                        .environment(\.renderEngine, engine)
                        .onAppear {
                            // Publish resources so ExternalDisplaySceneDelegate
                            // can access them when the OS activates the external
                            // display scene.
                            SharedAppResources.renderEngine = engine
                            SharedAppResources.appState = appState

                            // Start the overlay observation / render loop.
                            overlayController.start(appState: appState, renderEngine: engine)

                            // Monitor network connectivity.
                            NetworkMonitor.shared.start()

                            // Show onboarding on first launch.
                            if !hasCompletedOnboarding {
                                showOnboarding = true
                            }
                        }
                        .task {
                            // Keep AppState.isNetworkAvailable in sync with NetworkMonitor.
                            while true {
                                appState.isNetworkAvailable = NetworkMonitor.shared.isConnected
                                try? await Task.sleep(for: .seconds(2))
                            }
                        }
                        .sheet(isPresented: $showOnboarding) {
                            OnboardingView {
                                hasCompletedOnboarding = true
                                showOnboarding = false
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "Metal Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This device does not support Metal rendering.")
                    )
                }
            }
        }
    }
}
