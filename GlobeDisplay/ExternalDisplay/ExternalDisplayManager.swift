import UIKit

/// Detects the HDMI-connected MagicPlanet display via UIScreen notifications
/// and manages the UIWindow that hosts the Metal render view on that screen.
@MainActor
final class ExternalDisplayManager {

    private let renderEngine: RenderEngine
    private let appState: AppState
    private var externalWindow: UIWindow?

    var calibration = DisplayCalibration()

    init(renderEngine: RenderEngine, appState: AppState) {
        self.renderEngine = renderEngine
        self.appState = appState
        registerForScreenNotifications()
        checkExistingScreens()
    }

    // MARK: - Screen Detection

    private func registerForScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidConnect(_:)),
            name: UIScreen.didConnectNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect(_:)),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    /// Handles the case where the globe was already connected when the app launched.
    private func checkExistingScreens() {
        let externalScreens = UIScreen.screens.filter { $0 != UIScreen.main }
        if let screen = externalScreens.first {
            setupExternalWindow(for: screen)
        }
    }

    @objc private func screenDidConnect(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen,
              screen != UIScreen.main else { return }
        setupExternalWindow(for: screen)
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        tearDownExternalWindow()
    }

    // MARK: - Window Management

    private func setupExternalWindow(for screen: UIScreen) {
        tearDownExternalWindow()

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen

        let globeView = GlobeOutputView(renderEngine: renderEngine)
        let controller = UIViewController()
        controller.view = globeView
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        window.isHidden = false

        externalWindow = window
        appState.displayConnected = true
        appState.displayResolution = screen.nativeBounds.size
    }

    private func tearDownExternalWindow() {
        externalWindow?.isHidden = true
        externalWindow = nil
        appState.displayConnected = false
        appState.displayResolution = CGSize(width: 2048, height: 1024)
    }
}
