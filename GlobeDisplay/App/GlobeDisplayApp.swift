import SwiftUI

@main
struct GlobeDisplayApp: App {

    @State private var appState = AppState()
    @State private var renderEngine: RenderEngine? = {
        try? RenderEngine.make()
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if let engine = renderEngine {
                    ControlPanelView()
                        .environment(appState)
                        .environment(\.renderEngine, engine)
                        .onAppear {
                            // Publish resources so ExternalDisplaySceneDelegate
                            // can access them when the OS activates the external
                            // display scene.
                            SharedAppResources.renderEngine = engine
                            SharedAppResources.appState = appState
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
