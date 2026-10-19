import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var store: Store
    @Binding var section: String
    let login: () -> Void
    private let transfers = ["Všechny přenosy", "Stahování", "Nahrávání", "Dokončené"]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Webshare").font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("Manager").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30)
            Text("PŘENOSY").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary).padding(.leading, 24).padding(.bottom, 10)
            ForEach(transfers, id: \.self) { item in navigation(item) }
            Text("KNIHOVNA").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary).padding(.leading, 24).padding(.top, 28).padding(.bottom, 10)
            navigation("Moje soubory")
            navigation("Hledat na Webshare")
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill").font(.system(size: 15)).foregroundStyle(WMTheme.accent).frame(width: 35, height: 35).background(WMTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.signedIn ? store.account : L("Nejste přihlášeni")).font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                        if store.signedIn { HStack(spacing: 5) { Circle().fill(WMTheme.teal).frame(width: 5, height: 5); Text("Přihlášeno").font(.caption2).foregroundStyle(.secondary) } }
                    }
                }
                if store.signedIn {
                    Button { Task { await store.logout() } } label: { Label("Odhlásit se", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity) }.disabled(store.busy)
                } else {
                    Button(action: login) { Label("Přihlásit se", systemImage: "arrow.right").frame(maxWidth: .infinity) }.buttonStyle(WMButtonStyle(primary: true)).disabled(store.busy)
                }
            }.padding(14).background(WMTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).stroke(WMTheme.line.opacity(0.6)) }.padding(12)
            Text("Neoficiální klient pro Webshare.cz").font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 18)
        }.background(WMTheme.sidebar).buttonStyle(WMButtonStyle()).navigationSplitViewColumnWidth(min: 225, ideal: 240, max: 280)
    }
    private func navigation(_ item: String) -> some View {
        let active = section == item
        return Button { section = item } label: {
            HStack(spacing: 11) {
                Image(systemName: icon(item)).font(.system(size: 15, weight: .medium)).foregroundStyle(active ? Color.white : WMTheme.accent).frame(width: 22)
                Text(L(item)).font(.system(size: 12, weight: active ? .semibold : .medium))
                Spacer(minLength: 2)
                if transfers.contains(item) {
                    Text("\(count(item))").font(.system(size: 10, weight: .semibold)).monospacedDigit().padding(.horizontal, 7).padding(.vertical, 3).background((active ? Color.white : WMTheme.accent).opacity(0.12), in: Capsule())
                }
            }.foregroundStyle(active ? Color.white : Color.primary).padding(.horizontal, 12).padding(.vertical, 12)
                .background { if active { RoundedRectangle(cornerRadius: 11).fill(LinearGradient(colors: [WMTheme.blue, Color(red: 0.14, green: 0.33, blue: 0.75)], startPoint: .leading, endPoint: .trailing)) } }
                .contentShape(RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 2)
    }
    private func icon(_ item: String) -> String {
        switch item { case "Stahování": return "arrow.down.circle"; case "Nahrávání": return "arrow.up.circle"; case "Dokončené": return "checkmark.circle"; case "Moje soubory": return "folder"; case "Hledat na Webshare": return "magnifyingglass"; default: return "square.stack.3d.up" }
    }
    private func count(_ item: String) -> Int {
        store.jobs.filter { item == "Všechny přenosy" || (item == "Stahování" && $0.kind == .download) || (item == "Nahrávání" && $0.kind == .upload) || (item == "Dokončené" && $0.state == .done) }.count
    }
}
