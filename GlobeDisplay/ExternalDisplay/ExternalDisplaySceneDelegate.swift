import UIKit

/// Scene delegate for the external display scene
/// (UIWindowSceneSessionRoleExternalDisplayNonInteractive).
///
/// iOS instantiates this automatically when a display is connected, provided
/// the Info.plist declares the scene configuration. It runs on the main thread,
/// matching @MainActor isolation.
@MainActor
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard
            let windowScene = scene as? UIWindowScene,
            let engine = SharedAppResources.renderEngine,
            let appState = SharedAppResources.appState
        else { return }

        let win = UIWindow(windowScene: windowScene)

        let globeView = GlobeOutputView(renderEngine: engine)
        globeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let controller = UIViewController()
        controller.view = globeView
        controller.view.backgroundColor = .black

        win.rootViewController = controller
        win.isHidden = false

        window = win
        appState.displayConnected = true
        appState.displayResolution = windowScene.screen.nativeBounds.size
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        SharedAppResources.appState?.displayConnected = false
    }
}
