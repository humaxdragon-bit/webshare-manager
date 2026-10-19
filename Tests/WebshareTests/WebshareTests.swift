import Foundation
@main struct Checks {
    @MainActor static func main() async throws {
        precondition(PasswordHash.crypt("password", salt: "salt") == "$1$salt$qJH7.N4xYta3aEG/dfqo/0")
        precondition(PasswordHash.crypt("", salt: "salt") == "$1$salt$UsdFqFVB.FsuinRDK5eE..")
        precondition(API.identifier("https://webshare.cz/#/file/Abc123def4/name.zip") == "Abc123def4")
        precondition(API.identifier("https://webshare.cz/file/Abc123def4/name.zip") == "Abc123def4")
        precondition(API.identifier("https://example.com/file/Abc123def4") == nil)
        precondition(API.identifier("https://webshare.cz.evil.com/file/Abc123def4") == nil)
        precondition(API.identifier("../secret") == nil)
        precondition(String(data: API.form(["password": "a+b&č"]), encoding: .utf8) == "password=a%2Bb%26%C4%8D")
        let parsed = try XMLResponse.parse(Data("<response><status>OK</status><name>A &amp; B.zip</name></response>".utf8))
        precondition(parsed["name"] == "A & B.zip")
        func rejects(_ body: () throws -> Void) { do { try body(); fatalError("Expected an error") } catch {} }
        rejects { _ = try XMLResponse.parse(Data("<response><status>FATAL</status><message>Access denied.</message></response>".utf8)) }
        rejects { _ = try XMLResponse.parse(Data("not xml".utf8)) }
        rejects { _ = try API.secureURL("http://webshare.cz/upload", webshareOnly: true) }
        rejects { _ = try API.secureURL("https://webshare.cz.evil.test/upload", webshareOnly: true) }
        _ = try API.secureURL("https://upload2.wsup.cz/api/upload/index.php", webshareOnly: true)
        let ident = try Transfers.uploadIdentifier(Data("{\"ident\":\"Abc123def4\"}".utf8))
        precondition(ident == "Abc123def4")
        rejects { _ = try Transfers.uploadIdentifier(Data("{\"error\":{\"code\":1}}".utf8)) }
        print("Všech 16 kontrol prošlo: hesla, odkazy, XML/JSON, kódování a HTTPS.")
        let listing = Data("""
        <response><status>OK</status>
          <file><ident>Abc123def4</ident><name>A &amp; B.zip</name><size>4294967296</size><uploaded>2026-10-19 20:00:00</uploaded><downloads>12</downloads><password>0</password><path>/Archiv/</path></file>
          <file><ident>Other12345</ident><name>Soukromé.txt</name><size>0</size><password>1</password></file>
        </response>
        """.utf8)
        let document = try XMLResponse.document(listing)
        let files = try document.files.map { try UploadedFile(fields: $0) }
        precondition(files.count == 2 && files[0].id != files[1].id)
        precondition(files[0].name == "A & B.zip" && files[0].size == 4294967296)
        precondition(files[0].path == "/Archiv/" && files[0].downloads == 12)
        precondition(!files[0].passwordProtected && files[1].passwordProtected)
        precondition(files[1].downloads == 0 && files[1].path == "/")
        precondition(files[0].link == "https://webshare.cz/#/file/Abc123def4")
        let empty = try XMLResponse.document(Data("<response><status>OK</status></response>".utf8))
        precondition(empty.files.isEmpty)
        rejects { _ = try UploadedFile(fields: ["ident": "https://example.com", "name": "bad", "size": "1"]) }
        rejects { _ = try UploadedFile(fields: ["ident": "Abc123def4", "name": "bad", "size": "-1"]) }
        print("Kontroly seznamu souborů prošly: více položek, velké velikosti, hesla, prázdný seznam a neplatná data.")
        let tree = try XMLResponse.document(Data("""
        <response><status>OK</status>
          <folder><ident>Folder1234</ident><name>Serialy</name><path>/Serialy</path><created>2026-01-01</created></folder>
          <folder><ident>Folder5678</ident><name>Prázdná</name></folder>
          <file><ident>Episode123</ident><name>Díl 1.mkv</name><size>1024</size><created>2026-10-19</created><path>/Serialy/Díl 1.mkv</path></file>
        </response>
        """.utf8))
        precondition(tree.folders.count == 2 && tree.files.count == 1)
        let folder = try UploadedFile(fields: tree.folders[0], isFolder: true)
        let nested = try UploadedFile(fields: tree.folders[1], isFolder: true, parentPath: "/Serialy/")
        let episode = try UploadedFile(fields: tree.files[0])
        precondition(folder.isFolder && folder.folderPath == "/Serialy" && folder.size == 0)
        precondition(nested.folderPath == "/Serialy/Prázdná")
        precondition(!episode.isFolder && episode.uploaded == "2026-10-19")
        precondition(UploadedFile.parent("/Serialy/Seriál/") == "/Serialy")
        precondition(UploadedFile.parent("/Serialy") == "/" && UploadedFile.parent("/") == "/")
        precondition(UploadedFile.join("/Serialy/", "Seriál č. 1") == "/Serialy/Seriál č. 1")
        print("Kontroly složek prošly: smíšený seznam, podsložky, chybějící velikost, Unicode a návrat do kořene.")
        func searchPage(_ id: String, total: Int = 1) throws -> PublicSearchPage {
            try PublicSearchPage(document: XMLResponse.document(Data("<response><status>OK</status><total>\(total)</total><file><ident>\(id)</ident><name>Test.zip</name><size>1024</size></file></response>".utf8)))
        }
        let oldPage = try searchPage("Older12345")
        let newPage = try searchPage("Newer12345", total: 2)
        let nextPage = try searchPage("Next123456", total: 2)
        let publicSearch = PublicSearch { query, sort, category, offset in
            if query == "old" { try? await Task.sleep(nanoseconds: 200_000_000); return oldPage }
            precondition(sort == "largest" && category == "archives")
            try await Task.sleep(nanoseconds: 10_000_000)
            return offset == 0 ? newPage : nextPage
        }
        publicSearch.submit("old", sort: "recent", category: "")
        await Task.yield()
        publicSearch.submit("  new  ", sort: "largest", category: "archives")
        try await Task.sleep(nanoseconds: 300_000_000)
        precondition(publicSearch.query == "new" && publicSearch.files.map(\.id) == ["Newer12345"])
        precondition(publicSearch.hasMore && !publicSearch.loading)
        publicSearch.more()
        try await Task.sleep(nanoseconds: 100_000_000)
        precondition(publicSearch.files.map(\.id) == ["Newer12345", "Next123456"] && !publicSearch.hasMore)
        let emptySearch = try PublicSearchPage(document: XMLResponse.document(Data("<response><status>OK</status><total>0</total></response>".utf8)))
        precondition(emptySearch.files.isEmpty && emptySearch.total == 0)
        rejects { _ = try PublicSearchPage(document: XMLResponse.document(Data("<response><status>OK</status><total>-1</total></response>".utf8))) }
        print("Kontroly veřejného hledání prošly: nové dotazy nahradí staré, filtry, stránkování a prázdné výsledky.")
        if ProcessInfo.processInfo.environment["WEBSHARE_LIVE_SEARCH"] == "1" {
            let live = try await API(token: "").search(query: "ubuntu", sort: "largest", category: "archives", offset: 0)
            precondition(live.total > 0 && !live.files.isEmpty)
            print("Živé API veřejného hledání: načteno \(live.files.count) z \(live.total) výsledků.")
        }
        if let endpoint = ProcessInfo.processInfo.environment["WEBSHARE_TEST_ENDPOINT"], let url = URL(string: endpoint) {
            let counter = ProgressCounter()
            let progress = TransferProgress { bytes, _ in counter.record(bytes) }
            let (file, response) = try await DownloadOperation.download(URLRequest(url: url), progress: progress)
            defer { try? FileManager.default.removeItem(at: file) }
            try API.check(response)
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
            precondition(size == 2097152, "Downloaded bytes must match fixture")
            precondition(counter.callbacks > 1 && counter.bytes == 2097152, "Progress must arrive before completion")
            let cancelled = Task { try await DownloadOperation.download(URLRequest(url: url), progress: TransferProgress { _, _ in }) }
            try await Task.sleep(nanoseconds: 150_000_000)
            cancelled.cancel()
            do { _ = try await cancelled.value; fatalError("Cancelled download must throw") }
            catch is CancellationError { }
            print("Síťové kontroly prošly: stažení 2 MB, průběžné aktualizace a zastavení přenosu.")
        }
    }
}

final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var received: Int64 = 0
    func record(_ value: Int64) { lock.lock(); count += 1; received = value; lock.unlock() }
    var callbacks: Int { lock.lock(); defer { lock.unlock() }; return count }
    var bytes: Int64 { lock.lock(); defer { lock.unlock() }; return received }
}
