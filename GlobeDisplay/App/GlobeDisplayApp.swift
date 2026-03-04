import SwiftUI

@main
struct GlobeDisplayApp: App {

    @State private var appState = AppState()
    @State private var renderEngine: RenderEngine? = {
        try? RenderEngine.make()
    }()
    @State private var displayManager: ExternalDisplayManager?

    var body: some Scene {
        WindowGroup {
            Group {
                if let engine = renderEngine {
                    ControlPanelView()
                        .environment(appState)
                        .environment(\.renderEngine, engine)
                        .onAppear {
                            if displayManager == nil {
                                displayManager = ExternalDisplayManager(
                                    renderEngine: engine,
                                    appState: appState
                                )
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
