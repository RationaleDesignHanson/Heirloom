//
//  BackgroundDownloadService.swift
//  Heirloom
//
//  Background download service for large files (images, PDFs, videos)
//  Uses URLSession background configuration so downloads continue
//  even when the app is suspended or terminated by the system.
//

import Foundation
import UIKit

/// Service for downloading large files in the background
/// Downloads continue even when app is backgrounded/terminated
@MainActor
final class BackgroundDownloadService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = BackgroundDownloadService()

    // MARK: - Published State

    /// Active downloads mapped by task identifier
    @Published private(set) var activeDownloads: [Int: DownloadTask] = [:]

    // MARK: - Types

    struct DownloadTask {
        let url: URL
        let destinationFileName: String
        let completion: (Result<URL, Error>) -> Void
        var progress: Double = 0.0
    }

    enum DownloadError: LocalizedError {
        case invalidURL
        case downloadFailed(Error)
        case noData
        case fileMoveFailed(Error)
        case sessionNotAvailable

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid download URL"
            case .downloadFailed(let error):
                return "Download failed: \(error.localizedDescription)"
            case .noData:
                return "No data received from download"
            case .fileMoveFailed(let error):
                return "Failed to save downloaded file: \(error.localizedDescription)"
            case .sessionNotAvailable:
                return "Background session not available"
            }
        }
    }

    // MARK: - Configuration

    private static let sessionIdentifier = "com.rationaledesign.heirloom.background-downloads"

    /// Directory for downloaded files
    private let downloadsDirectory: URL

    // MARK: - Session

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false // Don't delay downloads
        config.sessionSendsLaunchEvents = true // Wake app on completion
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 60 * 60 // 1 hour max

        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Completion handler provided by app delegate when app is launched for background download
    var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Initialization

    private override init() {
        // Create downloads directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsDirectory = documentsURL.appendingPathComponent("Downloads", isDirectory: true)

        super.init()

        // Create directory if needed
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        // Reconnect to existing downloads
        reconnectToExistingDownloads()

        Log.info("BackgroundDownloadService initialized", category: .network, metadata: [
            "downloadsDirectory": downloadsDirectory.path
        ])
    }

    // MARK: - Public API

    /// Download a file in the background
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - fileName: The destination filename (stored in Downloads directory)
    ///   - completion: Called when download completes (on main queue)
    /// - Returns: The task identifier for tracking
    @discardableResult
    func downloadFile(
        from url: URL,
        fileName: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Int? {
        let task = backgroundSession.downloadTask(with: url)

        let downloadTask = DownloadTask(
            url: url,
            destinationFileName: fileName,
            completion: completion
        )

        activeDownloads[task.taskIdentifier] = downloadTask

        Log.info("Starting background download", category: .network, metadata: [
            "url": url.absoluteString,
            "fileName": fileName,
            "taskId": task.taskIdentifier
        ])

        task.resume()

        return task.taskIdentifier
    }

    /// Download a recipe image in the background
    /// - Parameters:
    ///   - urlString: The image URL string
    ///   - recipeId: The recipe ID for naming the file
    ///   - completion: Called with the local file URL on success
    @discardableResult
    func downloadRecipeImage(
        from urlString: String,
        recipeId: UUID,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Int? {
        guard let url = URL(string: urlString) else {
            completion(.failure(DownloadError.invalidURL))
            return nil
        }

        let fileName = "recipe-\(recipeId.uuidString)-\(Int(Date().timeIntervalSince1970)).jpg"
        return downloadFile(from: url, fileName: fileName, completion: completion)
    }

    /// Download a PDF file in the background
    /// - Parameters:
    ///   - url: The PDF URL
    ///   - fileName: Optional custom filename (defaults to UUID)
    ///   - completion: Called with the local file URL on success
    @discardableResult
    func downloadPDF(
        from url: URL,
        fileName: String? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Int? {
        let pdfFileName = fileName ?? "\(UUID().uuidString).pdf"
        return downloadFile(from: url, fileName: pdfFileName, completion: completion)
    }

    /// Cancel a download
    func cancelDownload(taskIdentifier: Int) {
        backgroundSession.getTasksWithCompletionHandler { _, _, downloadTasks in
            if let task = downloadTasks.first(where: { $0.taskIdentifier == taskIdentifier }) {
                task.cancel()
                Log.info("Cancelled background download", category: .network, metadata: [
                    "taskId": taskIdentifier
                ])
            }
        }

        Task { @MainActor in
            activeDownloads.removeValue(forKey: taskIdentifier)
        }
    }

    /// Get current progress for a download
    func progress(for taskIdentifier: Int) -> Double {
        return activeDownloads[taskIdentifier]?.progress ?? 0.0
    }

    // MARK: - Private Methods

    private func reconnectToExistingDownloads() {
        backgroundSession.getTasksWithCompletionHandler { _, _, downloadTasks in
            Task { @MainActor in
                for task in downloadTasks {
                    if self.activeDownloads[task.taskIdentifier] == nil {
                        Log.info("Reconnected to existing background download", category: .network, metadata: [
                            "taskId": task.taskIdentifier,
                            "state": task.state.rawValue
                        ])
                    }
                }
            }
        }
    }

    /// Move downloaded file to final destination
    private func moveDownloadedFile(from location: URL, to fileName: String) throws -> URL {
        let destinationURL = downloadsDirectory.appendingPathComponent(fileName)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: location, to: destinationURL)

        return destinationURL
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadService: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier

        Task { @MainActor in
            guard let download = activeDownloads[taskId] else {
                Log.warning("Completed download not tracked", category: .network, metadata: [
                    "taskId": taskId
                ])
                return
            }

            do {
                let finalURL = try moveDownloadedFile(from: location, to: download.destinationFileName)

                Log.info("Background download completed", category: .network, metadata: [
                    "taskId": taskId,
                    "fileName": download.destinationFileName
                ])

                download.completion(.success(finalURL))
            } catch {
                Log.error("Failed to move downloaded file", category: .network, metadata: [
                    "taskId": taskId,
                    "error": error.localizedDescription
                ])

                download.completion(.failure(DownloadError.fileMoveFailed(error)))
            }

            activeDownloads.removeValue(forKey: taskId)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0

        Task { @MainActor in
            if var download = activeDownloads[taskId] {
                download.progress = progress
                activeDownloads[taskId] = download
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }

        let taskId = task.taskIdentifier

        Task { @MainActor in
            guard let download = activeDownloads[taskId] else { return }

            Log.error("Background download failed", category: .network, metadata: [
                "taskId": taskId,
                "error": error.localizedDescription
            ])

            download.completion(.failure(DownloadError.downloadFailed(error)))
            activeDownloads.removeValue(forKey: taskId)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            if let completion = backgroundCompletionHandler {
                Log.info("Background URL session events finished", category: .network)
                completion()
                backgroundCompletionHandler = nil
            }
        }
    }
}

// MARK: - URLSessionDelegate

extension BackgroundDownloadService: URLSessionDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        didBecomeInvalidWithError error: Error?
    ) {
        if let error = error {
            Log.error("Background session invalidated", category: .network, metadata: [
                "error": error.localizedDescription
            ])
        }
    }
}
