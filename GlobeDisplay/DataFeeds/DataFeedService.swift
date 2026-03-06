import Foundation
import OSLog

private let logger = Logger(subsystem: "com.globedisplay", category: "DataFeedService")

// MARK: - Shared error type

/// Errors that can be thrown by any DataFeedProvider implementation.
enum DataFeedError: Error, LocalizedError {
    case badHTTPStatus
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .badHTTPStatus:
            return "The server returned a non-200 HTTP status code."
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - DataFeedService

/// Coordinates all data feed providers and publishes results to `AppState`.
/// Runs on the main actor so that `AppState` (also `@MainActor`) can be mutated directly.
@MainActor
final class DataFeedService {

    // MARK: Shared instance

    static let shared = DataFeedService()

    // MARK: Providers

    private let earthquakeProvider = USGSEarthquakeProvider()
    private let volcanoProvider    = GVPVolcanoProvider()
    private let wildfireProvider   = GDACSWildfireProvider()

    // MARK: Active tasks

    /// Maps each active feed type to its refresh `Task`.
    private var refreshTasks: [DataFeedType: Task<Void, Never>] = [:]

    // MARK: Init

    private init() {}

    // MARK: Public interface

    /// Start auto-refreshing `type`, writing results into `appState`.
    /// Cancels any previously running task for the same feed type first.
    func startFeed(_ type: DataFeedType, appState: AppState) {
        stopFeed(type, appState: appState)   // cancel existing task and clear events

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runRefreshLoop(for: type, appState: appState)
        }
        refreshTasks[type] = task
    }

    /// Stop auto-refreshing `type` and clear its events from `appState`.
    func stopFeed(_ type: DataFeedType, appState: AppState) {
        refreshTasks[type]?.cancel()
        refreshTasks[type] = nil
        clearEvents(for: type, appState: appState)
        appState.feedStatus[type] = nil
    }

    /// Stop all active feeds and clear all events from `appState`.
    func stopAll(appState: AppState) {
        for type in DataFeedType.allCases {
            stopFeed(type, appState: appState)
        }
    }

    // MARK: Private helpers

    /// Returns the concrete provider for a given feed type.
    private func provider(for type: DataFeedType) -> any DataFeedProvider {
        switch type {
        case .earthquakes: return earthquakeProvider
        case .volcanoes:   return volcanoProvider
        case .wildfires:   return wildfireProvider
        }
    }

    /// Writes normalized events back into the relevant `AppState` array.
    private func publish(events: [GeoEvent], for type: DataFeedType, to appState: AppState) {
        switch type {
        case .earthquakes: appState.earthquakeEvents = events
        case .volcanoes:   appState.volcanoEvents    = events
        case .wildfires:   appState.wildfireEvents   = events
        }
    }

    /// Resets the relevant `AppState` array to empty.
    private func clearEvents(for type: DataFeedType, appState: AppState) {
        publish(events: [], for: type, to: appState)
    }

    /// The perpetual fetch-sleep-repeat loop for a single feed type.
    /// Uses exponential backoff (capped at 5 minutes) on consecutive errors.
    private func runRefreshLoop(for type: DataFeedType, appState: AppState) async {
        let p = provider(for: type)
        let baseInterval = await p.updateInterval

        var consecutiveFailures = 0
        let maxBackoff: TimeInterval = 5 * 60   // 5 minutes

        while !Task.isCancelled {
            await MainActor.run { appState.feedStatus[type] = .fetching }

            do {
                let events = try await p.fetch()

                // Hop back to MainActor to update AppState (already on MainActor,
                // but the hop is explicit for clarity with strict concurrency).
                await MainActor.run {
                    self.publish(events: events, for: type, to: appState)
                    appState.feedStatus[type] = .ok(eventCount: events.count, updatedAt: Date())
                }

                consecutiveFailures = 0
                logger.info("[\(type.rawValue)] Fetched \(events.count) event(s).")

            } catch {
                consecutiveFailures += 1
                let backoff = min(baseInterval * pow(2.0, Double(consecutiveFailures - 1)), maxBackoff)
                logger.error("[\(type.rawValue)] Fetch error (attempt \(consecutiveFailures)): \(error.localizedDescription). Retrying in \(backoff)s.")

                await MainActor.run {
                    let lastUpdated: Date? = {
                        if case .ok(_, let d) = appState.feedStatus[type] { return d }
                        return nil
                    }()
                    appState.feedStatus[type] = .error(
                        message: error.localizedDescription,
                        lastUpdated: lastUpdated
                    )
                }

                try? await Task.sleep(for: .seconds(backoff))
                continue   // skip the normal sleep below
            }

            // Normal inter-fetch sleep.
            try? await Task.sleep(for: .seconds(baseInterval))
        }
    }
}
