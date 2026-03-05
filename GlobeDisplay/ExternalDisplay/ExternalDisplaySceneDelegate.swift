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
        print("[ExternalDisplay] scene willConnectTo — role: \(session.role.rawValue)")
        guard let windowScene = scene as? UIWindowScene else {
            print("[ExternalDisplay] guard failed: not a UIWindowScene")
            return
        }
        guard let engine = SharedAppResources.renderEngine else {
            print("[ExternalDisplay] guard failed: SharedAppResources.renderEngine is nil")
            return
        }
        guard let appState = SharedAppResources.appState else {
            print("[ExternalDisplay] guard failed: SharedAppResources.appState is nil")
            return
        }

        print("[ExternalDisplay] creating window on screen: \(windowScene.screen.bounds)")

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
        print("[ExternalDisplay] window created, displayConnected = true")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[ExternalDisplay] sceneDidDisconnect")
        window = nil
        SharedAppResources.appState?.displayConnected = false
    }
}
