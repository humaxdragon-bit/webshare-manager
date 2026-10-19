import SwiftUI
import AppKit

@MainActor final class Store: ObservableObject {
    let publicSearch = PublicSearch()
    @Published var jobs: [Transfer] = []
    @Published var uploadsFolderPath = "/"
    @Published var uploadsFolderMode = true
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var uploadsLoading = false
    @Published var uploadsLoaded = false
    @Published var uploadsHasMore = false
    @Published var uploadsError: String?
    private var uploadsOffset = 0
    private var uploadsRequest = UUID()
    @Published var account = ""
    @Published var signedIn = false
    @Published var busy = false
    @Published var error: String?
    @Published var running = false
    @Published var limit = 2
    @Published var folder = UserDefaults.standard.string(forKey: "folder") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path
    private var token = ""
    private var workers: [UUID: Task<Void, Never>] = [:]
    private let file: URL
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WebshareMac")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("queue.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([Transfer].self, from: data) {
            jobs = saved.map { job in
                var job = job
                if job.state == .running { job.state = .waiting; job.message = "Přerušeno zavřením aplikace — připraveno znovu"; job.completed = 0; job.speed = 0 }
                return job
            }
        }
    }
    func restore() async {
        guard let saved = TokenStore.read() else { return }
        busy = true; defer { busy = false }
        do {
            let user = try await API(token: saved).call("user_data")
            token = saved; signedIn = true; account = user["username"] ?? "Přihlášeno"
            Task { [weak self] in await self?.loadUploads() }
        } catch { self.error = "Uložené přihlášení se nepodařilo ověřit: \(error.localizedDescription)" }
    }
    func login(_ username: String, password: String, remember: Bool) async {
        busy = true; defer { busy = false }
        do {
            let api = API(token: "")
            let salt = try await api.call("salt", ["username_or_email": username])
            guard let salt = salt["salt"], !salt.isEmpty else { throw AppError("Server neposkytl přihlašovací údaje.") }
            let response = try await api.call("login", ["username_or_email": username, "password": PasswordHash.webshare(password, salt: salt), "keep_logged_in": remember ? "1" : "0"])
            guard let value = response["token"], !value.isEmpty else { throw AppError("Server nevrátil token.") }
            if remember { try TokenStore.save(value) } else { TokenStore.delete() }
            token = value; account = username; signedIn = true
            Task { [weak self] in await self?.loadUploads() }
        } catch { self.error = error.localizedDescription }
    }
    func logout() async {
        stop()
        uploadsRequest = UUID(); uploadedFiles = []; uploadsLoading = false; uploadsLoaded = false
        uploadsHasMore = false; uploadsOffset = 0; uploadsError = nil; uploadsFolderPath = "/"
        let old = token; token = ""; signedIn = false; account = ""; TokenStore.delete()
        _ = try? await API(token: old).call("logout")
    }
    func loadUploads(refresh: Bool = false) async {
        guard signedIn, !uploadsLoading else { return }
        if !refresh && uploadsLoaded && !uploadsHasMore { return }
        let requestID = UUID()
        uploadsRequest = requestID
        uploadsLoading = true; uploadsError = nil
        let api = API(token: token)
        let offset = refresh ? 0 : uploadsOffset
        defer { if uploadsRequest == requestID { uploadsLoading = false } }
        do {
            let page: [UploadedFile]
            if uploadsFolderMode { page = try await api.folderContents(path: uploadsFolderPath, limit: 100, offset: offset) }
            else { page = try await api.uploads(limit: 100, offset: offset) }
            guard uploadsRequest == requestID, signedIn, api.token == token else { return }
            var seen = Set(refresh ? [] : uploadedFiles.map(\.id))
            let newFiles = page.filter { seen.insert($0.id).inserted }
            uploadedFiles = (refresh ? [] : uploadedFiles) + newFiles
            uploadsOffset = offset + page.count
            uploadsHasMore = page.count == 100
            uploadsLoaded = true
        } catch {
            guard uploadsRequest == requestID else { return }
            uploadsError = error.localizedDescription
        }
    }
    func browseUploads(path: String = "/", folders: Bool = true) async {
        uploadsRequest = UUID()
        uploadsFolderPath = UploadedFile.normalizedPath(path)
        uploadsFolderMode = folders
        uploadedFiles = []; uploadsLoaded = false; uploadsHasMore = false
        uploadsLoading = false; uploadsOffset = 0; uploadsError = nil
        await loadUploads()
    }
    func downloadUploads(_ files: [UploadedFile]) {
        let files = files.filter { !$0.isFolder }
        let available = files.filter { !$0.passwordProtected }
        for file in available where !jobs.contains(where: { $0.kind == .download && $0.source == file.id && [.waiting, .running].contains($0.state) }) {
            var job = Transfer(kind: .download, source: file.id, name: file.name, destination: folder)
            job.total = file.size; jobs.append(job)
        }
        if available.count != files.count { error = "Soubory chráněné heslem zatím nelze stáhnout v aplikaci. Ostatní vybrané soubory byly přidány do fronty." }
        save(); pump()
    }
    func save() { do { try JSONEncoder().encode(jobs).write(to: file, options: .atomic) } catch { self.error = "Frontu se nepodařilo uložit: \(error.localizedDescription)" } }
    func addLinks(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let ids = lines.compactMap(API.identifier)
        guard !lines.isEmpty, ids.count == lines.count else { error = "Vložte platné odkazy na soubory Webshare, oddělené mezerou nebo novým řádkem."; return false }
        for ident in ids where !jobs.contains(where: { $0.kind == .download && $0.source == ident && [.waiting, .running].contains($0.state) }) {
            jobs.append(Transfer(kind: .download, source: ident, name: ident, destination: folder))
        }
        save(); pump(); return true
    }
    func addFiles(_ urls: [URL]) {
        for url in urls {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { error = "Složky nelze nahrávat přímo. Vyberte soubory nebo ZIP archiv."; continue }
            jobs.append(Transfer(kind: .upload, source: url.path, name: url.lastPathComponent, destination: "Webshare.cz"))
        }
        save(); pump()
    }
    func chooseFiles() { let p = NSOpenPanel(); p.canChooseDirectories = false; p.allowsMultipleSelection = true; if p.runModal() == .OK { addFiles(p.urls) } }
    func chooseFolder() { let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true; p.canCreateDirectories = true; if p.runModal() == .OK, let url = p.url { folder = url.path; UserDefaults.standard.set(folder, forKey: "folder") } }
    func start() { guard signedIn else { error = "Nejdřív se přihlaste k Webshare."; return }; running = true; pump() }
    func stop() { running = false; for id in Array(workers.keys) { cancel(id) } }
    func cancel(_ id: UUID) { workers[id]?.cancel(); edit(id) { $0.state = .cancelled; $0.message = "Zastaveno"; $0.speed = 0 }; save() }
    func retry(_ id: UUID) { guard workers[id] == nil else { return }; edit(id) { $0.state = .waiting; $0.message = "Čeká ve frontě"; $0.completed = 0; $0.speed = 0 }; save(); pump() }
    func clear() { jobs.removeAll { [.done, .cancelled].contains($0.state) && workers[$0.id] == nil }; save() }
    private func edit(_ id: UUID, _ body: (inout Transfer) -> Void) { if let i = jobs.firstIndex(where: { $0.id == id }) { body(&jobs[i]) } }
    func pump() {
        guard running, signedIn else { return }
        while workers.count < limit, let job = jobs.first(where: { $0.state == .waiting && workers[$0.id] == nil }) {
            edit(job.id) { $0.state = .running; $0.message = job.kind == .upload ? "Příprava nahrávání…" : "Získávám odkaz…" }
            let api = API(token: token)
            workers[job.id] = Task { [weak self] in
                guard let self else { return }
                let started = Date()
                let progress = TransferProgress { [weak self] done, total in
                    Task { @MainActor in self?.edit(job.id) {
                        guard $0.state == .running else { return }
                        $0.completed = done; $0.total = total; $0.speed = Double(done) / max(0.1, Date().timeIntervalSince(started)); $0.message = "Probíhá přenos"
                    } }
                }
                do {
                    let result: String
                    if job.kind == .download {
                        result = try await Transfers.download(job, api: api, progress: progress, rename: { [weak self] name in
                            Task { @MainActor in self?.edit(job.id) { $0.name = name } }
                        }, phase: { [weak self] message in
                            Task { @MainActor in self?.edit(job.id) {
                                if $0.state == .running && $0.completed == 0 { $0.message = message }
                            } }
                        })
                    } else { result = try await Transfers.upload(job, api: api, progress: progress) }
                    self.edit(job.id) { $0.state = .done; $0.message = "Dokončeno"; $0.result = result; $0.completed = $0.total; $0.speed = 0 }
                } catch {
                    self.edit(job.id) {
                        if Task.isCancelled { $0.state = .cancelled; $0.message = "Zastaveno" }
                        else { $0.state = .failed; $0.message = error.localizedDescription }
                        $0.speed = 0
                    }
                }
                self.workers[job.id] = nil; self.save(); self.pump()
            }
        }
        save()
    }
}
