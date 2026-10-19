import SwiftUI
import AppKit
import Sparkle
import UniformTypeIdentifiers

// Keep the property wrapper available with SDKs that also expose a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

@main struct WebshareApp: App {
    @StateObject private var store: Store
    @StateObject private var updater: AppUpdater
    init() {
        let store = Store()
        _store = StateObject(wrappedValue: store)
        _updater = StateObject(wrappedValue: AppUpdater(store: store))
    }
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("Webshare Manager") {
            ContentView(store: store).frame(minWidth: 900, minHeight: 620)
                .task { await store.restore() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in store.save() }
        }.defaultSize(width: 1080, height: 740)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Zkontrolovat aktualizace…") { updater.check() }.disabled(!updater.canCheck)
            }
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updating = false
    private var updateObserver: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        updateObserver = NotificationCenter.default.addObserver(forName: .SUUpdaterWillRestart, object: nil, queue: .main) { [weak self] _ in self?.updating = true }
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if updating { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "Ukončit Webshare Manager?"; alert.informativeText = "Probíhající přenosy se přeruší. Uloženou frontu lze při příštím spuštění spustit znovu od začátku."
        alert.addButton(withTitle: "Ukončit"); alert.addButton(withTitle: "Zpět")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @ViewState<String> private var section = "Všechny přenosy"
    @ViewState<String> private var links = ""
    @ViewState<Bool> private var showLinks = false
    @ViewState<Bool> private var showLogin = false
    @ViewState<Bool> private var dropTarget = false
    private let sections = ["Všechny přenosy", "Stahování", "Nahrávání", "Dokončené", "Moje soubory", "Hledat na Webshare"]
    private var visible: [Transfer] {
        store.jobs.filter { job in
            switch section { case "Stahování": return job.kind == .download
            case "Nahrávání": return job.kind == .upload
            case "Dokončené": return job.state == .done
            default: return true }
        }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 24) {
                Label { Text("Webshare Manager") } icon: { Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 26, height: 26) }.font(.headline).foregroundStyle(.tint).padding(.top, 20)
                VStack(spacing: 6) {
                    ForEach(sections, id: \.self) { item in
                        Button { section = item } label: {
                            HStack { Label(item, systemImage: icon(item)); Spacer()
                                if item != "Moje soubory" && item != "Hledat na Webshare" { Text("\(count(item))").foregroundStyle(.secondary) } }.padding(10).background(section == item ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Label(store.signedIn ? store.account : "Nejste přihlášeni", systemImage: "person.crop.circle").font(.headline).lineLimit(1)
                    if store.signedIn { Button("Odhlásit se") { Task { await store.logout() } }.disabled(store.busy) }
                    else { Button("Přihlásit se") { showLogin = true }.buttonStyle(.borderedProminent).disabled(store.busy) }
                    Text("Neoficiální klient pro Webshare.cz").font(.caption).foregroundStyle(.secondary)
                }.padding(.bottom, 16)
            }.padding(.horizontal, 14).navigationSplitViewColumnWidth(240)
        } detail: {
            if section == "Hledat na Webshare" {
                PublicSearchView(store: store, search: store.publicSearch)
            } else if section == "Moje soubory" {
                UploadedFilesView(store: store) { showLogin = true }
            } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section).font(.largeTitle.bold())
                        Text("Vaše soubory. Jedna přehledná fronta.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showLinks = true } label: { Label("Přidat odkazy", systemImage: "link.badge.plus") }
                    Button { store.chooseFiles() } label: { Label("Nahrát soubory", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent)
                }.padding(24)
                HStack(spacing: 16) {
                    Label("\(store.jobs.filter { $0.state == .running }.count) aktivní", systemImage: "arrow.triangle.2.circlepath")
                    Text("\(store.jobs.filter { $0.state == .waiting }.count) ve frontě").foregroundStyle(.secondary)
                    Spacer()
                    Picker("Současně", selection: $store.limit) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.frame(width: 145).onChange(of: store.limit) { store.pump() }
                    Button(store.running ? "Zastavit" : "Spustit frontu", systemImage: store.running ? "stop.fill" : "play.fill") { if store.running { store.stop() } else { store.start() } }.disabled(!store.signedIn)
                }.font(.callout).padding(.horizontal, 24).padding(.bottom, 18)
                Divider()
                if visible.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.and.arrow.down").font(.system(size: 46, weight: .light)).foregroundStyle(.tint)
                        Text("Připraveno na vaše soubory").font(.title2.bold())
                        Text("Přidejte odkazy ke stažení nebo sem přetáhněte\nsoubory, které chcete nahrát na Webshare.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Přidat odkazy") { showLinks = true }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView { LazyVStack(spacing: 12) { ForEach(visible) { job in TransferRow(job: job, store: store) } }.padding(20) }
                }
                Divider()
                HStack {
                    Button { store.chooseFolder() } label: { Label(URL(fileURLWithPath: store.folder).lastPathComponent, systemImage: "folder") }.help(store.folder)
                    Text("Cíl pro nově přidaná stahování").font(.caption).foregroundStyle(.secondary)
                    Spacer(); Button("Vyčistit dokončené") { store.clear() }
                }.padding(16)
            }.background(Color(nsColor: .windowBackgroundColor))
            .overlay { if dropTarget { RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8])).padding(10).allowsHitTesting(false) } }
            .onDrop(of: [UTType.fileURL], isTargeted: $dropTarget) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in store.addFiles([url]) } } }
                }
                return true
            }
            }
        }
        .sheet(isPresented: $showLogin) { LoginView(store: store) }
        .sheet(isPresented: $showLinks) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Přidat odkazy ke stažení").font(.title2.bold())
                Text("Každý odkaz na samostatný řádek. Lze vložit i identifikátory souborů.").foregroundStyle(.secondary)
                TextEditor(text: $links).font(.system(.body, design: .monospaced)).frame(height: 200).border(.quaternary)
                HStack { Button("Zrušit") { showLinks = false }; Spacer(); Button("Přidat do fronty") { if store.addLinks(links) { links = ""; showLinks = false } }.buttonStyle(.borderedProminent) }
            }.padding(24).frame(width: 560)
        }
        .alert("Webshare Manager", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    func icon(_ item: String) -> String { switch item { case "Hledat na Webshare": return "magnifyingglass"; case "Stahování": return "arrow.down.circle"; case "Nahrávání": return "arrow.up.circle"; case "Dokončené": return "checkmark.circle"; case "Moje soubory": return "folder.badge.person.crop"; default: return "tray.full" } }
    func count(_ item: String) -> Int { if item == "Moje soubory" { return store.uploadedFiles.count }; return store.jobs.filter { item == "Všechny přenosy" || (item == "Stahování" && $0.kind == .download) || (item == "Nahrávání" && $0.kind == .upload) || (item == "Dokončené" && $0.state == .done) }.count }
}

struct TransferRow: View {
    let job: Transfer
    @ObservedObject var store: Store
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: job.kind == .download ? "arrow.down.document" : "arrow.up.document").font(.title).foregroundStyle(.tint).frame(width: 38).padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(job.name).font(.headline).lineLimit(1); Spacer(); Text(job.kind == .download ? "STAŽENÍ" : "NAHRÁNÍ").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
                if job.state == .running { ProgressView(value: job.fraction) }
                HStack(alignment: .top) {
                    Text(job.message).foregroundStyle(job.state == .failed ? Color.red : Color.secondary).textSelection(.enabled)
                    Spacer()
                    if job.state == .running && job.speed > 0 { Text(ByteCountFormatter.string(fromByteCount: Int64(job.speed), countStyle: .file) + "/s").monospacedDigit() }
                }.font(.caption)
                if job.state == .running && job.total > 0 {
                    Text("\(ByteCountFormatter.string(fromByteCount: job.completed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: job.total, countStyle: .file))").font(.caption).foregroundStyle(.secondary)
                }
            }
            if [.running, .waiting].contains(job.state) { Button { store.cancel(job.id) } label: { Image(systemName: "xmark.circle") }.help("Zastavit přenos") }
            if [.failed, .cancelled].contains(job.state) { Button { store.retry(job.id) } label: { Image(systemName: "arrow.clockwise") }.help("Spustit znovu od začátku") }
            if job.state == .done {
                Button {
                    if job.kind == .download { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: job.result)]) }
                    else { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(job.result, forType: .string) }
                } label: { Image(systemName: job.kind == .download ? "folder" : "doc.on.doc") }.help(job.kind == .download ? "Ukázat ve Finderu" : "Zkopírovat odkaz")
            }
        }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}
struct LoginView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @ViewState<String> private var username = ""
    @ViewState<String> private var password = ""
    @ViewState<Bool> private var remember = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Přihlášení k Webshare", systemImage: "person.crop.circle").font(.title2.bold())
            Text("Použijte svůj účet na Webshare.cz.").foregroundStyle(.secondary)
            TextField("E-mail nebo uživatelské jméno", text: $username).textFieldStyle(.roundedBorder)
            SecureField("Heslo", text: $password).textFieldStyle(.roundedBorder)
            Toggle("Zapamatovat přihlášení v Klíčence", isOn: $remember)
            Text("Vaše heslo se na disk neukládá.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Zrušit") { dismiss() }.disabled(store.busy); Spacer(); if store.busy { ProgressView().controlSize(.small) }; Button("Přihlásit se") { Task { await store.login(username.trimmingCharacters(in: .whitespacesAndNewlines), password: password, remember: remember); if store.signedIn { password = ""; dismiss() } } }.buttonStyle(.borderedProminent).disabled(store.busy || username.isEmpty || password.isEmpty) }
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }.padding(28).frame(width: 440)
    }
}
