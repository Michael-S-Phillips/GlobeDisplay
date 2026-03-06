import Foundation
import ImageIO
import Observation

/// Manages background URLSession downloads of SOS dataset archives and MOV video files.
///
/// Downloads are tracked by `ContentBundle.id`. After a MOV download finishes,
/// `VideoFrameExtractor` converts it to a numbered JPEG sequence and
/// `ContentManager` is notified via `importBundle(_:)`.
@Observable
@MainActor
final class ContentDownloader: NSObject {

    // MARK: - Singleton

    static let shared = ContentDownloader()

    // MARK: - State

    /// Download progress for each bundle ID (0.0 – 1.0). Observable — drives UI updates.
    private(set) var downloadProgress: [UUID: Double] = [:]

    /// Active download tasks keyed by bundle ID.
    @ObservationIgnored private var activeTasks: [UUID: URLSessionDownloadTask] = [:]

    /// Resume data saved when a task is cancelled, keyed by bundle ID.
    @ObservationIgnored private var resumeData: [UUID: Data] = [:]

    /// Original bundle metadata preserved during download, keyed by bundle ID.
    @ObservationIgnored private var pendingBundles: [UUID: ContentBundle] = [:]

    // MARK: - Session

    /// Background URLSession. @ObservationIgnored because lazy is incompatible with
    /// the @Observable macro's computed-property transformation.
    @ObservationIgnored private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.globedisplay.downloads"
        )
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
        pendingBundles[bundle.id] = bundle
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
                self.pendingBundles.removeValue(forKey: id)
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

        let originalBundle = pendingBundles[id]
        pendingBundles.removeValue(forKey: id)

        // Detect video files by the original download URL extension (more reliable
        // than the temp file extension from URLSession).
        let downloadExt = (originalBundle?.assets.downloadURL?.pathExtension
            ?? location.pathExtension).lowercased()
        let isVideo = downloadExt == "mov" || downloadExt == "mp4"

        if isVideo {
            // Extract frames asynchronously; do not block the main actor.
            let destination = contentDirectory(for: id)
            Task.detached(priority: .utility) { [weak self] in
                do {
                    try FileManager.default.createDirectory(
                        at: destination,
                        withIntermediateDirectories: true
                    )
                    // Background URLSession temp files have no meaningful extension
                    // (e.g. ".tmp"), so AVFoundation cannot identify the container
                    // format. Move to a stable path with the correct extension first.
                    let correctExt = downloadExt.isEmpty ? "mov" : downloadExt
                    let videoSource = destination.appendingPathComponent("source.\(correctExt)")
                    if FileManager.default.fileExists(atPath: videoSource.path) {
                        try FileManager.default.removeItem(at: videoSource)
                    }
                    print("[ContentDownloader] Moving \(location.lastPathComponent) → \(videoSource.path)")
                    try FileManager.default.moveItem(at: location, to: videoSource)
                    print("[ContentDownloader] Starting frame extraction from \(videoSource.lastPathComponent)")

                    let frameCount = try await VideoFrameExtractor.extractFrames(
                        from: videoSource,
                        to: destination,
                        targetFPS: 5.0,
                        maxFrames: 120
                    )
                    // Log actual frame dimensions so we can verify the video is 2:1 equirectangular.
                    let firstFrame = destination.appendingPathComponent("0001.jpg")
                    if let src = CGImageSourceCreateWithURL(firstFrame as CFURL, nil),
                       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                       let w = props[kCGImagePropertyPixelWidth] as? Int,
                       let h = props[kCGImagePropertyPixelHeight] as? Int {
                        let ratio = Double(w) / Double(h)
                        print("[ContentDownloader] Frame size: \(w)×\(h) (aspect ratio \(String(format: "%.3f", ratio)), expected 2.000 for equirectangular)")
                    }
                    print("[ContentDownloader] Extracted \(frameCount) frames for \(id)")
                    // Remove the source video now that frames are extracted.
                    try? FileManager.default.removeItem(at: videoSource)
                    let updatedBundle = ContentBundle(
                        id: originalBundle?.id ?? id,
                        title: originalBundle?.title ?? "Animated Dataset",
                        description: originalBundle?.description ?? "",
                        category: originalBundle?.category ?? .ocean,
                        contentType: .imageSequence,
                        resolution: CodableSize(width: 2048, height: 1024),
                        source: .downloaded,
                        assets: ContentAssets(
                            sequenceDirectory: destination.path,
                            frameCount: frameCount,
                            framerate: 5.0
                        ),
                        attribution: originalBundle?.attribution ?? "NOAA Science on a Sphere",
                        license: originalBundle?.license ?? "Public Domain (U.S. Government Work)"
                    )
                    print("[ContentDownloader] Importing bundle \(updatedBundle.id) '\(updatedBundle.title)'")
                    await MainActor.run {
                        ContentManager.shared.importBundle(updatedBundle)
                        print("[ContentDownloader] importedContent count: \(ContentManager.shared.importedContent.count)")
                    }
                } catch {
                    print("[ContentDownloader] ❌ Frame extraction failed for \(id): \(error) — \(error.localizedDescription)")
                    // Clean up on failure (success path removes the file above).
                    try? FileManager.default.removeItem(at: location)
                }
                await MainActor.run { [weak self] in
                    self?.activeTasks.removeValue(forKey: id)
                    self?.downloadProgress.removeValue(forKey: id)
                }
            }
        } else {
            // Non-video path: treat as a pre-extracted SOS bundle directory.
            let destination = contentDirectory(for: id)
            do {
                try FileManager.default.createDirectory(
                    at: destination,
                    withIntermediateDirectories: true
                )
                let destFile = destination.appendingPathComponent(location.lastPathComponent)
                if FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.removeItem(at: destFile)
                }
                try FileManager.default.moveItem(at: location, to: destFile)
                let bundle = try BundleParser.parse(directory: destination)
                ContentManager.shared.importBundle(bundle)
            } catch {
                print("[ContentDownloader] Failed to process download for \(id): \(error.localizedDescription)")
            }
            activeTasks.removeValue(forKey: id)
            downloadProgress.removeValue(forKey: id)
        }
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
