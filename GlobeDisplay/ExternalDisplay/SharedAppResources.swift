import Foundation

/// Bridges resources created by SwiftUI's App lifecycle to UIKit scene
/// delegates, which are instantiated by the OS independently of the SwiftUI
/// view hierarchy.
@MainActor
enum SharedAppResources {
    static var renderEngine: RenderEngine?
    static var appState: AppState?
}
