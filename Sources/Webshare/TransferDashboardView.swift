import SwiftUI
import UniformTypeIdentifiers

struct TransferDashboardView: View {
    @ObservedObject var store: Store
    let section: String
    let addLinks: () -> Void
    @ViewState<Bool> private var targeted = false
    private var visible: [Transfer] {
        store.jobs.filter {
            switch section { case "Stahování": return $0.kind == .download; case "Nahrávání": return $0.kind == .upload; case "Dokončené": return $0.state == .done; default: return true }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                WMPageHeading(title: section, subtitle: "Vaše soubory. Jedna přehledná fronta.", icon: "arrow.up.arrow.down")
                Spacer(minLength: 8)
                Button(action: addLinks) { Label("Přidat odkazy", systemImage: "link") }
                Button { store.chooseFiles() } label: { Label("Nahrát soubory", systemImage: "plus") }.buttonStyle(WMButtonStyle(primary: true))
            }.padding(28)
            HStack(spacing: 12) {
                statistic("Stahování", icon: "arrow.down", count: store.jobs.filter { $0.kind == .download && $0.state != .done }.count, color: WMTheme.accent)
                statistic("Nahrávání", icon: "arrow.up", count: store.jobs.filter { $0.kind == .upload && $0.state != .done }.count, color: WMTheme.teal)
                statistic("Dokončené", icon: "checkmark", count: store.jobs.filter { $0.state == .done }.count, color: WMTheme.teal)
            }.padding(.horizontal, 28).padding(.bottom, 22)
            HStack(spacing: 14) {
                HStack(spacing: 6) { Circle().fill(store.jobs.contains { $0.state == .running } ? WMTheme.teal : Color.secondary.opacity(0.5)).frame(width: 6, height: 6); Text(LF("%lld aktivní", store.jobs.filter { $0.state == .running }.count)) }.font(.system(size: 11, weight: .medium))
                Text(LF("%lld ve frontě", store.jobs.filter { $0.state == .waiting }.count)).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Picker("Současně", selection: $store.limit) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.frame(width: 133).controlSize(.small).onChange(of: store.limit) { store.pump() }
                Button { if store.running { store.stop() } else { store.start() } } label: { Label(L(store.running ? "Zastavit" : "Spustit frontu"), systemImage: store.running ? "stop.fill" : "play.fill") }.disabled(!store.signedIn)
            }.padding(.horizontal, 28).padding(.bottom, 14)
            if visible.isEmpty {
                GeometryReader { geometry in
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    WMTransferIllustration().scaleEffect(geometry.size.height < 330 ? 0.75 : 1).frame(height: geometry.size.height < 330 ? 130 : 175)
                    Text("Připraveno na vaše soubory").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(-0.4)
                    Text("Přidejte odkazy ke stažení nebo sem přetáhněte\nsoubory, které chcete nahrát na Webshare.").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4).lineLimit(2).frame(height: 36)
                    HStack(spacing: 10) {
                        Button { store.chooseFiles() } label: { Label("Nahrát soubory", systemImage: "arrow.up.to.line") }.buttonStyle(WMButtonStyle(primary: true))
                        Button(action: addLinks) { Label("Přidat odkazy", systemImage: "link") }
                    }.padding(.top, 12)
                    Spacer(minLength: 0)
                }.frame(width: geometry.size.width, height: geometry.size.height)
                }
                    .background(WMTheme.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
                    .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(targeted ? WMTheme.accent : WMTheme.line, style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: [6, 5])) }
                    .padding(.horizontal, 28).padding(.bottom, 20)
            } else {
                ScrollView { LazyVStack(spacing: 12) { ForEach(visible) { TransferRow(job: $0, store: store) } }.padding(.horizontal, 28).padding(.vertical, 8) }
            }
            HStack(spacing: 10) {
                Image(systemName: "folder").foregroundStyle(WMTheme.accent)
                Button { store.chooseFolder() } label: { Text(URL(fileURLWithPath: store.folder).lastPathComponent).font(.system(size: 11, weight: .medium)) }.buttonStyle(.plain).help(store.folder)
                Text("Cíl pro nově přidaná stahování").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("Vyčistit dokončené") { store.clear() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.horizontal, 28).padding(.vertical, 16).background(WMTheme.surface.opacity(0.4)).overlay(alignment: .top) { WMTheme.line.frame(height: 1) }
        }
        .background(WMTheme.canvas)
        .buttonStyle(WMButtonStyle())
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in store.addFiles([url]) } } } }
            return true
        }
    }
    private func statistic(_ title: String, icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color).frame(width: 40, height: 40).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)").font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(L(title)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity).background(WMTheme.surface, in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(WMTheme.line.opacity(0.6)) }
    }
}
