import Foundation

/// Base protocol for all data feed providers.
/// Each provider is an actor to ensure thread-safe access to its internal state.
/// Conforming types run entirely off the main thread.
protocol DataFeedProvider: Actor {
    /// The type of data this provider supplies.
    var feedType: DataFeedType { get }

    /// How many seconds between automatic refreshes.
    var updateInterval: TimeInterval { get }

    /// Fetch the latest events from the remote source.
    /// - Throws: Any networking or decoding error.
    /// - Returns: Normalized array of `GeoEvent` values.
    func fetch() async throws -> [GeoEvent]
}
