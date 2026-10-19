import Foundation

struct UploadedFile: Identifiable, Hashable {
    let isFolder: Bool
    let id: String
    let name: String
    let size: Int64
    let uploaded: String
    let downloads: Int
    let path: String
    let passwordProtected: Bool
    var link: String { "https://webshare.cz/#/file/\(id)" }

    init(fields: [String: String], isFolder: Bool = false, parentPath: String = "/") throws {
        guard let ident = fields["ident"], API.identifier(ident) == ident,
              let name = fields["name"], !name.isEmpty,
              let size = Int64(fields["size"] ?? (isFolder ? "0" : "")), size >= 0 else {
            throw AppError("Server vrátil neúplné údaje nahraného souboru.")
        }
        self.isFolder = isFolder
        id = ident; self.name = name; self.size = size
        uploaded = fields["uploaded"] ?? fields["created"] ?? ""
        downloads = Int(fields["downloads"] ?? "") ?? 0
        path = fields["path"] ?? (isFolder ? Self.join(parentPath, name) : parentPath)
        passwordProtected = fields["password"] == "1"
    }
    var folderPath: String { Self.normalizedPath(path) }
    static func normalizedPath(_ path: String) -> String { "/" + path.split(separator: "/").joined(separator: "/") }
    static func join(_ parent: String, _ name: String) -> String { normalizedPath(parent + "/" + name) }
    static func parent(_ path: String) -> String {
        let parts = path.split(separator: "/").dropLast()
        return "/" + parts.joined(separator: "/")
    }

}
