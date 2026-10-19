import SwiftUI
import AppKit

struct PublicSearchView: View {
    @ObservedObject var store: Store
    @ObservedObject var search: PublicSearch
    @ViewState<String> private var text = ""
    @ViewState<String> private var sort = "recent"
    @ViewState<String> private var category = ""
    @ViewState<Set<String>> private var selection = []
    @ViewState<Bool> private var copied = false
    @ViewState<Bool> private var added = false
    private var selected: [UploadedFile] { search.files.filter { selection.contains($0.id) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hledat na Webshare").font(.largeTitle.bold())
                Text("Vyhledávání ve veřejných souborech na celém Webshare.").foregroundStyle(.secondary)
            }.padding(24)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Zadejte název souboru", text: $text).textFieldStyle(.roundedBorder).onSubmit { submit() }
                Button("Hledat") { submit() }.buttonStyle(.borderedProminent).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.horizontal, 24)
            HStack(spacing: 20) {
                Picker("Řazení", selection: $sort) {
                    Text("Nejnovější").tag("recent")
                    Text("Nejlépe hodnocené").tag("rating")
                    Text("Největší").tag("largest")
                    Text("Nejmenší").tag("smallest")
                }.frame(width: 245)
                Picker("Kategorie", selection: $category) {
                    Text("Všechny").tag("")
                    Text("Video").tag("video")
                    Text("Zvuk").tag("audio")
                    Text("Obrázky").tag("images")
                    Text("Dokumenty").tag("docs")
                    Text("Archivy").tag("archives")
                }.frame(width: 220)
                Spacer()
                if search.loading { ProgressView().controlSize(.small) }
            }.padding(24)
            Divider()
            if let error = search.error {
                HStack {
                    Label(L(error), systemImage: "exclamationmark.triangle").font(.callout).textSelection(.enabled)
                    Spacer()
                    Button("Zkusit znovu") { search.retry() }.disabled(search.loading)
                }.padding(16).background(Color.orange.opacity(0.08))
            }
            if search.files.isEmpty {
                VStack(spacing: 14) {
                    if search.loading { ProgressView(); Text(LF("Hledám „%@“…", search.query)) }
                    else {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 44, weight: .light)).foregroundStyle(.tint)
                        Text(L(search.searched ? "Žádné výsledky" : "Co chcete najít?")).font(.title2.bold())
                        Text(L(search.searched ? "Zkuste jiný název nebo kategorii." : "Zadejte název a stiskněte Enter nebo Hledat.")).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(search.files, selection: $selection) {
                    TableColumn("Název") { file in
                        Label(file.name, systemImage: file.passwordProtected ? "lock.doc" : "doc").lineLimit(1).help(file.name)
                    }.width(min: 200, ideal: 450)
                    TableColumn("Velikost") { file in Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).monospacedDigit() }.width(100)
                    TableColumn("Typ") { file in Text(URL(fileURLWithPath: file.name).pathExtension.uppercased()).foregroundStyle(.secondary) }.width(65)
                }
            }
            HStack {
                Text(search.searched ? LF("„%@“ · načteno %lld z %lld výsledků", search.query, search.files.count, search.total) : L("Výsledky poskytuje Webshare.cz")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if search.hasMore { Button("Načíst další výsledky") { search.more() }.disabled(search.loading) }
            }.padding(16)
            Divider()
            HStack {
                Text(LF("Vybráno: %lld", selected.count)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selected.map(\.link).joined(separator: "\n"), forType: .string)
                    copied = true
                } label: { Label(L(copied ? "Zkopírováno" : "Kopírovat odkazy"), systemImage: "doc.on.doc") }.disabled(selected.isEmpty)
                Button {
                    store.downloadUploads(selected)
                    added = true
                } label: { Label(L(added ? "Přidáno do fronty" : "Přidat ke stažení"), systemImage: added ? "checkmark" : "arrow.down.to.line") }.disabled(selected.isEmpty)
            }.padding(16)
            Text("Vybrané soubory se přidají do fronty Stahování. Soubory se zámkem vyžadují heslo a zatím je nelze stáhnout v aplikaci.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if text.isEmpty { text = search.query }; sort = search.sort; category = search.category }
        .onChange(of: sort) { if search.searched && (sort != search.sort || category != search.category) { submit() } }
        .onChange(of: category) { if search.searched && (sort != search.sort || category != search.category) { submit() } }
        .onChange(of: selection) { copied = false; added = false }
    }
    private func submit() {
        selection = []; copied = false; added = false
        search.submit(text, sort: sort, category: category)
    }
}
