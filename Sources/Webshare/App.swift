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
            ContentView(store: store).frame(minWidth: 1000, minHeight: 700)
                .task { await store.restore() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in store.save() }
        }.defaultSize(width: 1160, height: 800)
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
        let alert = NSAlert(); alert.messageText = L("Ukončit Webshare Manager?"); alert.informativeText = L("Probíhající přenosy se přeruší. Uloženou frontu lze při příštím spuštění spustit znovu od začátku.")
        alert.addButton(withTitle: L("Ukončit")); alert.addButton(withTitle: L("Zpět"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @ViewState<String> private var section = "Všechny přenosy"
    @ViewState<String> private var links = ""
    @ViewState<Bool> private var showLinks = false
    @ViewState<Bool> private var showLogin = false
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, section: $section) { showLogin = true }
        } detail: {
            if section == "Hledat na Webshare" {
                PublicSearchView(store: store, search: store.publicSearch)
            } else if section == "Moje soubory" {
                UploadedFilesView(store: store) { showLogin = true }
            } else {
                TransferDashboardView(store: store, section: section) { showLinks = true }
            }
        }
        .tint(WMTheme.accent)
        .buttonStyle(WMButtonStyle())
        .sheet(isPresented: $showLogin) { LoginView(store: store) }
        .sheet(isPresented: $showLinks) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Přidat odkazy ke stažení").font(.title2.bold())
                Text("Každý odkaz na samostatný řádek. Lze vložit i identifikátory souborů.").foregroundStyle(.secondary)
                TextEditor(text: $links).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(12).frame(height: 200).background(WMTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
                HStack { Button("Zrušit") { showLinks = false }; Spacer(); Button("Přidat do fronty") { if store.addLinks(links) { links = ""; showLinks = false } }.buttonStyle(WMButtonStyle(primary: true)) }
            }.padding(28).frame(width: 560).background(WMTheme.canvas)
        }
        .alert("Webshare Manager", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(L(store.error ?? "")) }
    }
}

struct TransferRow: View {
    let job: Transfer
    @ObservedObject var store: Store
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: job.state == .done ? "checkmark" : (job.kind == .download ? "arrow.down" : "arrow.up"))
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(job.kind == .download ? WMTheme.accent : WMTheme.teal)
                .frame(width: 46, height: 50).background((job.kind == .download ? WMTheme.accent : WMTheme.teal).opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(job.name).font(.headline).lineLimit(1); Spacer(); Text(L(job.kind == .download ? "STAŽENÍ" : "NAHRÁNÍ")).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(job.kind == .download ? WMTheme.accent : WMTheme.teal).padding(.horizontal, 8).padding(.vertical, 5).background(WMTheme.elevated, in: Capsule()) }
                if job.kind == .upload {
                    Label(LF("Cílová složka: %@", job.uploadFolder), systemImage: "folder").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if job.state == .running { ProgressView(value: job.fraction) }
                HStack(alignment: .top) {
                    Text(L(job.message)).foregroundStyle(job.state == .failed ? Color.red : Color.secondary).textSelection(.enabled)
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
                } label: { Image(systemName: job.kind == .download ? "folder" : "doc.on.doc") }.help(L(job.kind == .download ? "Ukázat ve Finderu" : "Zkopírovat odkaz"))
            }
        }.padding(18).background(WMTheme.surface, in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(WMTheme.line.opacity(0.7)) }.buttonStyle(WMButtonStyle())
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
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 58, height: 58)
            Text("Přihlášení k Webshare").font(.system(size: 25, weight: .bold, design: .rounded))
            Text("Použijte svůj účet na Webshare.cz.").foregroundStyle(.secondary)
            TextField("E-mail nebo uživatelské jméno", text: $username).textFieldStyle(.roundedBorder)
            SecureField("Heslo", text: $password).textFieldStyle(.roundedBorder)
            Toggle("Zapamatovat přihlášení v Klíčence", isOn: $remember)
            Text("Vaše heslo se na disk neukládá.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Zrušit") { dismiss() }.disabled(store.busy); Spacer(); if store.busy { ProgressView().controlSize(.small) }; Button("Přihlásit se") { Task { await store.login(username.trimmingCharacters(in: .whitespacesAndNewlines), password: password, remember: remember); if store.signedIn { password = ""; dismiss() } } }.buttonStyle(WMButtonStyle(primary: true)).disabled(store.busy || username.isEmpty || password.isEmpty) }
            if let error = store.error { Text(L(error)).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }.padding(32).frame(width: 460).controlSize(.large).background(WMTheme.canvas).buttonStyle(WMButtonStyle())
    }
}
