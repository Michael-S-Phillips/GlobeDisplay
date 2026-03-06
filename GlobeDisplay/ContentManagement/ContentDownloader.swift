import Foundation

/// Manages background URLSession downloads of SOS dataset archives.
///
/// Downloads are tracked by `ContentBundle.id`. After a download finishes the
/// raw file is moved into the app's Application Support directory and
/// `ContentManager` is notified via `importBundle(_:)`.
///
/// - Note: Full ZIP extraction is deferred (TODO). The current implementation
///   saves the downloaded file and attempts to parse it as a pre-extracted
///   directory bundle using `BundleParser`.
@MainActor
final class ContentDownloader: NSObject {

    // MARK: - Singleton

    static let shared = ContentDownloader()

    // MARK: - State

    /// Download progress for each bundle ID (0.0 – 1.0).
    private(set) var downloadProgress: [UUID: Double] = [:]

    /// Active download tasks keyed by bundle ID.
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]

    /// Resume data saved when a task is cancelled, keyed by bundle ID.
    private var resumeData: [UUID: Data] = [:]

    // MARK: - Session

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.globedisplay.downloads"
        )
        // URLSession delegate must be set at init time for background sessions.
        // We use a trampoline so we can keep ContentDownloader @MainActor.
        return URLSession(
            configuration: config,
            delegate: SessionDelegate(owner: self),
            delegateQueue: nil
        )
    }()

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Starts downloading the archive for `bundle` if it has a `downloadURL`
    /// and is not already being downloaded.
    ///
    /// - Parameter bundle: The content bundle to download.
    func download(bundle: ContentBundle) {
        guard let downloadURL = bundle.assets.downloadURL else { return }
        guard activeTasks[bundle.id] == nil else { return }  // already in flight

        let task: URLSessionDownloadTask
        if let saved = resumeData[bundle.id] {
            task = session.downloadTask(withResumeData: saved)
            resumeData.removeValue(forKey: bundle.id)
        } else {
            task = session.downloadTask(with: downloadURL)
        }

        task.taskDescription = bundle.id.uuidString
        activeTasks[bundle.id] = task
        downloadProgress[bundle.id] = 0.0
        task.resume()
    }

    /// Cancels an active download, saving resume data if available.
    ///
    /// - Parameter id: The `UUID` of the bundle whose download should be cancelled.
    func cancelDownload(id: UUID) {
        guard let task = activeTasks[id] else { return }
        task.cancel { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data {
                    self.resumeData[id] = data
                }
                self.activeTasks.removeValue(forKey: id)
                self.downloadProgress.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Internal Callbacks (called from SessionDelegate)

    func didWriteData(taskDescription: String?, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let desc = taskDescription, let id = UUID(uuidString: desc) else { return }
        guard totalBytesExpectedToWrite > 0 else { return }
        downloadProgress[id] = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }

    func didFinishDownloading(taskDescription: String?, location: URL) {
        guard let desc = taskDescription, let id = UUID(uuidString: desc) else { return }

        let destination = contentDirectory(for: id)

        do {
            try FileManager.default.createDirectory(
                at: destination,
                withIntermediateDirectories: true
            )

            // Move the downloaded file into the destination directory.
            // TODO: If the downloaded file is a ZIP archive, extract it here
            // instead of moving the raw file. iOS does not have a built-in
            // unzip command; a third-party library (e.g. ZIPFoundation) or a
            // custom implementation would be needed for full ZIP support.
            let destFile = destination.appendingPathComponent(
                location.lastPathComponent
            )
            if FileManager.default.fileExists(atPath: destFile.path) {
                try FileManager.default.removeItem(at: destFile)
            }
            try FileManager.default.moveItem(at: location, to: destFile)

            // Attempt to parse the destination as a bundle directory.
            let bundle = try BundleParser.parse(directory: destination)
            ContentManager.shared.importBundle(bundle)
        } catch {
            // Log and surface the error; do not crash.
            print("[ContentDownloader] Failed to process download for \(id): \(error.localizedDescription)")
        }

        activeTasks.removeValue(forKey: id)
        downloadProgress.removeValue(forKey: id)
    }

    func didCompleteWithError(taskDescription: String?, error: Error?) {
        guard let desc = taskDescription, let id = UUID(uuidString: desc) else { return }
        activeTasks.removeValue(forKey: id)

        if let error {
            print("[ContentDownloader] Download failed for \(id): \(error.localizedDescription)")
            downloadProgress.removeValue(forKey: id)
        }
    }

    // MARK: - Helpers

    private func contentDirectory(for id: UUID) -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("GlobeDisplay/Content/\(id.uuidString)")
    }
}

// MARK: - Session Delegate Trampoline

/// A non-isolated `URLSessionDownloadDelegate` that forwards events back to the
/// `@MainActor`-isolated `ContentDownloader`. This pattern is necessary because
/// `URLSessionDownloadDelegate` callbacks arrive on a background queue and we
/// cannot make `ContentDownloader` itself conform to the delegate protocol while
/// keeping it `@MainActor`.
private final class SessionDelegate: NSObject, URLSessionDownloadDelegate {

    private weak var owner: ContentDownloader?

    init(owner: ContentDownloader) {
        self.owner = owner
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let desc = downloadTask.taskDescription
        // Copy the file to a stable path before the system removes it.
        let tempCopy: URL
        do {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(location.pathExtension)
            try FileManager.default.copyItem(at: location, to: tmp)
            tempCopy = tmp
        } catch {
            print("[SessionDelegate] Could not copy downloaded file: \(error)")
            return
        }

        Task { @MainActor [weak owner] in
            owner?.didFinishDownloading(taskDescription: desc, location: tempCopy)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let desc = downloadTask.taskDescription
        Task { @MainActor [weak owner] in
            owner?.didWriteData(
                taskDescription: desc,
                bytesWritten: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let desc = task.taskDescription
        Task { @MainActor [weak owner] in
            owner?.didCompleteWithError(taskDescription: desc, error: error)
        }
    }
}
