enum StaticOverlayLayer: String, CaseIterable, Hashable, Sendable {
    case rivers

    var displayName: String {
        switch self { case .rivers: "Rivers" }
    }

    var systemImage: String {
        switch self { case .rivers: "water.waves" }
    }

    var bundledAssetName: String {
        switch self { case .rivers: "rivers_2048x1024" }
    }
}
