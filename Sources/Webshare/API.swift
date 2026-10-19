import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import CryptoKit
import Security

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = L(message) }
    var errorDescription: String? { message }
}

final class XMLResponse: NSObject, XMLParserDelegate {
    var values: [String: String] = [:]
    var files: [[String: String]] = []
    var folders: [[String: String]] = []
    private var stack: [String] = []
    private var texts: [String] = []
    private var currentFile: [String: String]?

    static func document(_ data: Data) throws -> XMLResponse {
        let delegate = XMLResponse()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw AppError("Server vrátil neplatnou XML odpověď.") }
        let result = delegate.values
        guard result["status"] == "OK" else {
            throw AppError([result["message"] ?? L("Požadavek se nezdařil."), result["code"] ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        return delegate
    }
    static func parse(_ data: Data) throws -> [String: String] { try document(data).values }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        stack.append(elementName); texts.append("")
        if stack.count == 2 && ["file", "folder"].contains(elementName) { currentFile = [:] }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !texts.isEmpty { texts[texts.count - 1] += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = (texts.popLast() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if stack.count == 2 { values[elementName] = content }
        if stack.count == 3, ["file", "folder"].contains(stack[1]) { currentFile?[elementName] = content }
        if stack.count == 2, let entry = currentFile {
            if elementName == "file" { files.append(entry); currentFile = nil }
            if elementName == "folder" { folders.append(entry); currentFile = nil }
        }
        _ = stack.popLast()
    }
}

enum PasswordHash {
    static func md5(_ data: Data) -> Data { Data(Insecure.MD5.hash(data: data)) }
    static func crypt(_ password: String, salt raw: String) -> String {
        let salt = String(raw.replacingOccurrences(of: "$1$", with: "").prefix { $0 != "$" }.prefix(8))
        let p = Data(password.utf8), s = Data(salt.utf8)
        var context = p + Data("$1$".utf8) + s
        let alternate = md5(p + s + p)
        var remaining = p.count
        while remaining > 0 { context += alternate.prefix(min(16, remaining)); remaining -= 16 }
        var bits = p.count
        while bits > 0 { context.append(bits & 1 != 0 ? 0 : (p.first ?? 0)); bits >>= 1 }
        var digest = md5(context)
        for i in 0..<1000 {
            var round = i & 1 != 0 ? p : digest
            if i % 3 != 0 { round += s }
            if i % 7 != 0 { round += p }
            round += i & 1 != 0 ? digest : p
            digest = md5(round)
        }
        let alphabet = Array("./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        func encode(_ a: Int, _ b: Int, _ c: Int, _ count: Int) -> String {
            var n = (Int(digest[a]) << 16) | (Int(digest[b]) << 8) | Int(digest[c])
            var out = ""
            for _ in 0..<count { out.append(alphabet[n & 63]); n >>= 6 }
            return out
        }
        var tail = ""
        var last = Int(digest[11])
        for _ in 0..<2 { tail.append(alphabet[last & 63]); last >>= 6 }
        return "$1$" + salt + "$" + encode(0,6,12,4) + encode(1,7,13,4) + encode(2,8,14,4) + encode(3,9,15,4) + encode(4,10,5,4) + tail
    }
    static func webshare(_ password: String, salt: String) -> String {
        Insecure.SHA1.hash(data: Data(crypt(password, salt: salt).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum TokenStore {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cz.local.webshare.mac", kSecAttrAccount as String: "session"]
    static func read() -> String? {
        var q = query; q[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw AppError("Token se nepodařilo uložit do Klíčenky.") }
        } else if status != errSecSuccess { throw AppError("Klíčenka odmítla uložení tokenu.") }
    }
    static func delete() { SecItemDelete(query as CFDictionary) }
}

struct API {
    let token: String
    static func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return Data(values.sorted { $0.key < $1.key }.map { "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)" }.joined(separator: "&").utf8)
    }
    func call(_ method: String, _ fields: [String: String] = [:]) async throws -> [String: String] {
        try await document(method, fields).values
    }
    func uploads(limit: Int, offset: Int) async throws -> [UploadedFile] {
        let response = try await document("uploads", ["limit": String(limit), "offset": String(offset)])
        return try response.files.map { try UploadedFile(fields: $0) }
    }
    func folderContents(path: String, limit: Int, offset: Int) async throws -> [UploadedFile] {
        let response = try await document("files", ["path": path, "sort_by": "name", "sort_order": "asc", "include_removed": "0", "limit": String(limit), "offset": String(offset)])
        let folders = try response.folders.map { try UploadedFile(fields: $0, isFolder: true, parentPath: path) }
        let files = try response.files.map { try UploadedFile(fields: $0) }
        return folders + files
    }
    func search(query: String, sort: String, category: String, offset: Int) async throws -> PublicSearchPage {
        var fields = ["what": query, "sort": sort, "limit": "50", "offset": String(offset)]
        if !category.isEmpty { fields["category"] = category }
        let response = try await document("search", fields)
        return try PublicSearchPage(document: response)
    }
    private func document(_ method: String, _ fields: [String: String]) async throws -> XMLResponse {
        var fields = fields
        if !token.isEmpty { fields["wst"] = token }
        var request = URLRequest(url: URL(string: "https://webshare.cz/api/\(method)/")!)
        request.httpMethod = "POST"; request.httpBody = Self.form(fields)
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
        return try XMLResponse.document(data)
    }
    static func check(_ response: URLResponse) throws {
        guard let r = response as? HTTPURLResponse, (200..<300).contains(r.statusCode) else { throw AppError(LF("Server odmítl přenos (HTTP %lld).", (response as? HTTPURLResponse)?.statusCode ?? 0)) }
    }
    static func secureURL(_ value: String, webshareOnly: Bool = false) throws -> URL {
        guard let url = URL(string: value), url.scheme == "https", let host = url.host, url.user == nil, url.password == nil,
              !webshareOnly || host == "webshare.cz" || host.hasSuffix(".webshare.cz") || host == "wsup.cz" || host.hasSuffix(".wsup.cz") else { throw AppError("Server neposkytl platnou zabezpečenou adresu přenosu.") }
        return url
    }
    static func identifier(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }), (6...32).contains(value.count) { return value }
        guard let url = URL(string: value), ["webshare.cz", "www.webshare.cz"].contains(url.host?.lowercased() ?? "") else { return nil }
        let parts = (url.path + "/" + (url.fragment ?? "")).split(separator: "/").map(String.init)
        guard let index = parts.firstIndex(of: "file"), parts.indices.contains(index+1) else { return nil }
        return identifier(parts[index+1])
    }
}
