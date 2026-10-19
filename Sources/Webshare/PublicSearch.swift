import Foundation
import Combine

struct PublicSearchPage {
    let files: [UploadedFile]
    let total: Int
    init(document: XMLResponse) throws {
        guard let total = Int(document.values["total"] ?? ""), total >= 0 else { throw AppError("Server nevrátil počet výsledků hledání.") }
        self.total = total
        files = try document.files.map { try UploadedFile(fields: $0) }
    }
}

@MainActor final class PublicSearch: ObservableObject {
    @Published private(set) var files: [UploadedFile] = []
    @Published private(set) var total = 0
    @Published private(set) var loading = false
    @Published private(set) var hasMore = false
    @Published private(set) var searched = false
    @Published private(set) var query = ""
    @Published private(set) var error: String?
    @Published private(set) var sort = "recent"
    @Published private(set) var category = ""
    private var offset = 0
    private var generation = UUID()
    private var task: Task<Void, Never>?
    // Injectable loader lets regression checks exercise overlapping requests.
    typealias Loader = @Sendable (String, String, String, Int) async throws -> PublicSearchPage
    private let loader: Loader
    init(loader: @escaping Loader = { query, sort, category, offset in
        try await API(token: "").search(query: query, sort: sort, category: category, offset: offset)
    }) { self.loader = loader }

    func submit(_ text: String, sort: String, category: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task?.cancel(); generation = UUID()
        query = trimmed; self.sort = sort; self.category = category
        files = []; total = 0; offset = 0; searched = true; hasMore = false
        load()
    }
    func more() { guard hasMore, !loading else { return }; load() }
    func retry() { guard !loading, searched else { return }; load() }
    private func load() {
        let id = generation, text = query, ordering = sort, filter = category, start = offset
        let loader = loader
        loading = true; error = nil
        task = Task { [weak self] in
            do {
                let page = try await loader(text, ordering, filter, start)
                guard let self, self.generation == id, !Task.isCancelled else { return }
                var seen = Set(self.files.map(\.id))
                let fresh = page.files.filter { seen.insert($0.id).inserted }
                self.files += fresh; self.total = page.total
                self.offset = start + page.files.count
                self.hasMore = self.offset < page.total && !fresh.isEmpty
                self.loading = false
            } catch {
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.error = error.localizedDescription; self.loading = false
            }
        }
    }
}
