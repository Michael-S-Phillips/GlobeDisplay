import SwiftUI

/// Environment key for injecting RenderEngine into the SwiftUI view hierarchy.
struct RenderEngineKey: EnvironmentKey {
    static let defaultValue: RenderEngine? = nil
}

extension EnvironmentValues {
    var renderEngine: RenderEngine? {
        get { self[RenderEngineKey.self] }
        set { self[RenderEngineKey.self] = newValue }
    }
}
