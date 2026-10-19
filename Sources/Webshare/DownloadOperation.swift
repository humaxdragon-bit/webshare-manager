import Foundation

// Async URLSession.download(for:delegate:) uses an internal download delegate on
// macOS and does not forward didWriteData. Own the task and delegate explicitly.
final class DownloadOperation: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var session: URLSession?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var cancelled = false
    private var saved: URL?
    private var fileError: Error?
    private let progress: TransferProgress
    init(progress: TransferProgress) { self.progress = progress }

    static func download(_ request: URLRequest, progress: TransferProgress) async throws -> (URL, URLResponse) {
        let operation = DownloadOperation(progress: progress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { operation.start(request, continuation: $0) }
        } onCancel: { operation.cancel() }
    }
    private func start(_ request: URLRequest, continuation: CheckedContinuation<(URL, URLResponse), Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 7 * 24 * 3600
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: request)
        self.task = task
        task.resume()
        lock.unlock()
    }
    private func cancel() {
        lock.lock(); cancelled = true; let task = task; lock.unlock()
        task?.cancel()
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.update(totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The URLSession temporary file exists only during this callback.
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("Webshare-" + UUID().uuidString)
        do { try FileManager.default.moveItem(at: location, to: target); saved = target }
        catch { fileError = error }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        let cancelled = cancelled
        self.task = nil; self.session = nil
        lock.unlock()
        let failure = cancelled ? CancellationError() : (error ?? fileError)
        if let failure {
            if let saved { try? FileManager.default.removeItem(at: saved) }
            continuation?.resume(throwing: failure)
        } else if let saved, let response = task.response {
            continuation?.resume(returning: (saved, response))
        } else { continuation?.resume(throwing: AppError("Server nedokončil stažení souboru.")) }
        session.finishTasksAndInvalidate()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
}
