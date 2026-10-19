import Foundation

final class TransferProgress: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let update: @Sendable (Int64, Int64) -> Void
    init(update: @escaping @Sendable (Int64, Int64) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) { update(totalBytesWritten, totalBytesExpectedToWrite) }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) { update(totalBytesSent, totalBytesExpectedToSend) }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
}

struct Transfer: Identifiable, Codable {
    enum Kind: String, Codable { case download, upload }
    enum State: String, Codable { case waiting, running, done, failed, cancelled }
    var id = UUID()
    var kind: Kind
    var source: String
    var name: String
    var destination: String
    var state: State = .waiting
    var message = "Čeká ve frontě"
    var completed: Int64 = 0
    var total: Int64 = 0
    var result: String = ""
    var speed: Double = 0
    var fraction: Double { total > 0 ? min(1, Double(completed) / Double(total)) : 0 }
}

enum Transfers {
    static func download(_ job: Transfer, api: API, progress: TransferProgress, rename: @escaping @Sendable (String) -> Void, phase: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        let info = try await api.call("file_info", ["ident": job.source])
        let raw = info["name"] ?? job.source
        let name = URL(fileURLWithPath: raw).lastPathComponent
        guard !name.isEmpty, name != ".", name != ".." else { throw AppError("Neplatný název souboru.") }
        rename(name)
        phase("Získávám odkaz ke stažení…")
        let link = try await api.call("file_link", ["ident": job.source, "download_type": "file_download", "force_https": "1"])
        let url = try API.secureURL(link["link"] ?? "")
        phase("Připojuji se ke stahovacímu serveru…")
        var request = URLRequest(url: url); request.timeoutInterval = 60
        let (temporary, response) = try await DownloadOperation.download(request, progress: progress)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try API.check(response); try Task.checkCancellation()
        if let expected = Int64(info["size"] ?? ""), expected > 0 {
            let actual = (try FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)?.int64Value
            guard actual == expected else { throw AppError("Velikost staženého souboru nesouhlasí. Zkuste přenos znovu.") }
        }
        let folder = URL(fileURLWithPath: job.destination, isDirectory: true)
        let base = folder.appendingPathComponent(name)
        var target = base; var suffix = 1
        while true {
            do { try FileManager.default.moveItem(at: temporary, to: target); break }
            catch CocoaError.fileWriteFileExists {
                target = folder.appendingPathComponent("\(base.deletingPathExtension().lastPathComponent) (\(suffix))\(base.pathExtension.isEmpty ? "" : "." + base.pathExtension)")
                suffix += 1
            }
        }
        return target.path
    }
    static func upload(_ job: Transfer, api: API, progress: TransferProgress) async throws -> String {
        let source = URL(fileURLWithPath: job.source)
        let metadata = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard metadata.isRegularFile == true, let fileSize = metadata.fileSize else { throw AppError("Vyberte běžný soubor.") }
        let response = try await api.call("upload_url")
        let url = try API.secureURL(response["url"] ?? "", webshareOnly: true)
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var offset: Int64 = 0
        var ident: String?
        repeat {
            try Task.checkCancellation()
            let chunkSize = min(64 * 1024 * 1024, fileSize - Int(offset))
            let boundary = "Webshare-" + UUID().uuidString
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else { throw AppError("Nelze připravit dočasný soubor.") }
            let output = try FileHandle(forWritingTo: temporary)
            defer { try? output.close() }
            func write(_ text: String) throws { try output.write(contentsOf: Data(text.utf8)) }
            var fields = [("wst", api.token), ("total", String(fileSize)), ("offset", String(offset)), ("folder", "/")]
            if let ident { fields.append(("ident", ident)) }
            for (key, value) in fields {
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
            }
            let name = source.lastPathComponent.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_").replacingOccurrences(of: "\\", with: "_")
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
            var remaining = chunkSize
            while remaining > 0 {
                try Task.checkCancellation()
                guard let chunk = try input.read(upToCount: min(1024*1024, remaining)), !chunk.isEmpty else { throw AppError("Soubor se během nahrávání změnil nebo jej nelze přečíst.") }
                try output.write(contentsOf: chunk); remaining -= chunk.count
                await Task.yield()
            }
            try write("\r\n--\(boundary)--\r\n"); try output.synchronize()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"; request.timeoutInterval = 3600
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("text/xml, application/json", forHTTPHeaderField: "Accept")
            let base = offset
            let chunkProgress = TransferProgress { sent, expected in
                let uploaded = expected > 0 ? Int64(Double(chunkSize) * Double(sent) / Double(expected)) : 0
                progress.update(base + uploaded, Int64(fileSize))
            }
            let (data, reply) = try await URLSession.shared.upload(for: request, fromFile: temporary, delegate: chunkProgress)
            try API.check(reply)
            ident = try uploadIdentifier(data)
            offset += Int64(chunkSize)
            progress.update(offset, Int64(fileSize))
        } while offset < Int64(fileSize)
        guard let ident else { throw AppError("Server nepotvrdil dokončení nahrávání.") }
        return "https://webshare.cz/#/file/\(ident)"
    }
    static func uploadIdentifier(_ data: Data) throws -> String {
        let ident: String?
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any] {
                throw AppError("Webshare odmítl nahrávání: \(error["message"] as? String ?? "kód \(error["code"] ?? "?")")")
            }
            ident = json["ident"] as? String
        } else { ident = try XMLResponse.parse(data)["ident"] }
        guard let ident, API.identifier(ident) != nil else { throw AppError("Server nepotvrdil identifikátor nahraného souboru.") }
        return ident
    }
}
