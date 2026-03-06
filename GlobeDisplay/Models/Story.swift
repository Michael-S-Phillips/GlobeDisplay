import Foundation

/// A single step in a guided story: one content bundle + narrator text.
struct StoryStep: Identifiable, Codable, Sendable {
    let id: UUID
    /// References a `ContentBundle` by its stable UUID.
    let contentBundleID: UUID
    /// Educational narrative shown on the control panel during this step.
    let narrative: String
    /// If set, the player auto-advances after this many seconds.
    let autoAdvanceSeconds: Double?
}

/// An ordered, curated sequence of content steps with educational narration.
struct Story: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let systemImage: String
    let steps: [StoryStep]
}
