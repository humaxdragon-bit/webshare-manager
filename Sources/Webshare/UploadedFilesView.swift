import SwiftUI
import AppKit

struct UploadedFilesView: View {
    @ObservedObject var store: Store
    let login: () -> Void
    @ViewState<String> private var search = ""
    @ViewState<Set<String>> private var selection = []
    @ViewState<Bool> private var copied = false
    private var filtered: [UploadedFile] {
        store.uploadedFiles.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.path.localizedStandardContains(search) }
    }
    private var selected: [UploadedFile] { filtered.filter { selection.contains($0.id) && !$0.isFolder } }
    private var selectedFolder: UploadedFile? { filtered.first { selection.contains($0.id) && $0.isFolder } }
    private var crumbs: [(title: String, path: String)] {
        var path = ""
        return [(title: "Moje soubory", path: "/")] + store.uploadsFolderPath.split(separator: "/").map { part in
            path += "/" + part
            return (title: String(part), path: path)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                WMPageHeading(title: "Moje soubory", subtitle: "Soubory nahrané na váš účet Webshare.", icon: "folder")
                Spacer()
                Button { Task { await store.loadUploads(refresh: true) } } label: { Label("Obnovit", systemImage: "arrow.clockwise") }.disabled(!store.signedIn || store.uploadsLoading)
                Button { store.chooseFiles(destination: store.uploadsFolderMode ? store.uploadsFolderPath : "/") } label: {
                    Label(L(store.uploadsFolderMode ? "Nahrát sem" : "Nahrát soubory"), systemImage: "square.and.arrow.up")
                }.buttonStyle(WMButtonStyle(primary: true)).disabled(!store.signedIn)
                    .help(LF("Cílová složka na Webshare: %@", store.uploadsFolderMode ? store.uploadsFolderPath : "/"))
            }.padding(24)
            if !store.signedIn {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle").font(.system(size: 42)).foregroundStyle(.tint)
                    Text("Přihlaste se pro zobrazení svých souborů").font(.title3)
                    Button("Přihlásit se", action: login).buttonStyle(WMButtonStyle(primary: true)).disabled(store.busy)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Picker("Zobrazení", selection: Binding(get: { store.uploadsFolderMode }, set: { mode in
                        Task { await store.browseUploads(folders: mode) }
                    })) {
                        Text("Složky").tag(true)
                        Text("Všechny soubory").tag(false)
                    }.pickerStyle(.segmented).frame(width: 280)
                    Spacer()
                }.padding(.horizontal, 24).padding(.bottom, 12)
                if store.uploadsFolderMode {
                    HStack(spacing: 8) {
                        Button { openPath(UploadedFile.parent(store.uploadsFolderPath)) } label: { Image(systemName: "arrow.up") }
                            .disabled(store.uploadsFolderPath == "/").help("Nadřazená složka")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(crumbs, id: \.path) { crumb in
                                    Button(crumb.path == "/" ? L("Moje soubory") : crumb.title) { openPath(crumb.path) }.buttonStyle(.link)
                                    if crumb.path != store.uploadsFolderPath { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 12)
                }
                HStack {
                    WMSearchField(placeholder: "Hledat v načtených souborech a složkách", text: $search)
                    if store.uploadsLoading { ProgressView().controlSize(.small) }
                }.padding(.horizontal, 24).padding(.bottom, 16)
                if let error = store.uploadsError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        Text(L(error)).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button("Zkusit znovu") { Task { await store.loadUploads(refresh: !store.uploadsLoaded) } }
                    }.padding(16).background(Color.orange.opacity(0.08))
                }
                Divider()
                if store.uploadedFiles.isEmpty {
                    VStack(spacing: 12) {
                        if store.uploadsLoading { ProgressView(); Text("Načítám obsah…") }
                        else if store.uploadsLoaded { Image(systemName: "folder").font(.largeTitle).foregroundStyle(.secondary); Text(L(store.uploadsFolderMode ? "Tato složka je prázdná." : "Zatím tu nemáte žádné nahrané soubory.")) }
                        else { Text("Seznam souborů není načtený.").foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(filtered, selection: $selection) {
                        TableColumn("Název") { file in
                            if file.isFolder {
                                Button { openPath(file.folderPath) } label: {
                                    Label(file.name, systemImage: "folder.fill").foregroundStyle(Color.accentColor).lineLimit(1)
                                }.buttonStyle(.plain).help(LF("Otevřít složku %@", file.name))
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: file.passwordProtected ? "lock.doc" : "doc").foregroundStyle(.secondary)
                                    Text(file.name).lineLimit(1).help(file.name + "\n" + file.path)
                                }
                            }
                        }.width(min: 180, ideal: 320)
                        TableColumn("Velikost") { file in Text(file.isFolder ? L("Složka") : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)).monospacedDigit() }.width(85)
                        TableColumn("Nahráno") { file in Text(file.uploaded).font(.caption).foregroundStyle(.secondary) }.width(135)
                        TableColumn("Stažení") { file in Text(file.isFolder ? "—" : "\(file.downloads)").monospacedDigit() }.width(60)
                    }
                    .modifier(WMTableCard())
                    .contextMenu(forSelectionType: String.self) { ids in
                        if let folder = filtered.first(where: { ids.contains($0.id) && $0.isFolder }) {
                            Button("Otevřít složku") { openPath(folder.folderPath) }
                        }
                    } primaryAction: { ids in
                        if let folder = filtered.first(where: { ids.contains($0.id) && $0.isFolder }) { openPath(folder.folderPath) }
                    }
                    .overlay {
                        if filtered.isEmpty { Text("Žádný z načtených souborů neodpovídá hledání.").foregroundStyle(.secondary).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) }
                    }
                }
                HStack {
                    Text(LF("%lld z %lld načtených položek", filtered.count, store.uploadedFiles.count)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if store.uploadsHasMore {
                        Button("Načíst dalších 100") { Task { await store.loadUploads() } }.disabled(store.uploadsLoading)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)
                Divider()
                HStack {
                    Text(LF("Vybráno: %lld", selected.count)).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    if let folder = selectedFolder { Button("Otevřít složku") { openPath(folder.folderPath) } }
                    Button { copyLinks() } label: { Label(L(copied ? "Zkopírováno" : "Kopírovat odkazy"), systemImage: copied ? "checkmark" : "doc.on.doc") }.disabled(selected.isEmpty)
                    Button { store.downloadUploads(selected) } label: { Label("Přidat ke stažení", systemImage: "arrow.down.to.line") }.buttonStyle(WMButtonStyle(primary: true)).disabled(selected.isEmpty)
                }.padding(16)
                Text(L(store.uploadsFolderMode ? "Složku otevřete kliknutím na její název nebo dvojklikem na řádek. Hledání prochází načtený obsah této složky." : "Stahování se přidá do fronty. Hledání prochází načtené soubory; další načtete tlačítkem výše.")).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
        .background(WMTheme.canvas)
        .buttonStyle(WMButtonStyle())
        .task(id: store.signedIn) { if store.signedIn && !store.uploadsLoaded { await store.loadUploads() } }
        .onChange(of: search) { selection = []; copied = false }
        .onChange(of: selection) { copied = false }
        .onChange(of: store.uploadedFiles) { selection = []; copied = false }
    }
    private func openPath(_ path: String) {
        search = ""; selection = []; copied = false
        Task { await store.browseUploads(path: path) }
    }
    private func copyLinks() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selected.map(\.link).joined(separator: "\n"), forType: .string)
        copied = true
    }
}
