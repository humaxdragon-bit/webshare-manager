import SwiftUI
import AppKit

enum WMTheme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        func rgb(_ hex: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
        return Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? rgb(dark) : rgb(light) })
    }
    static let canvas = adaptive(0xF4F7FC, 0x101723)
    static let sidebar = adaptive(0xEAF0F8, 0x111B2C)
    static let surface = adaptive(0xFFFFFF, 0x1A2535)
    static let elevated = adaptive(0xEDF3FC, 0x223147)
    static let accent = adaptive(0x2563EB, 0x6AA9FF)
    static let teal = adaptive(0x00897B, 0x55D6C2)
    static let line = adaptive(0xDCE4EF, 0x2D3B4E)
    static let blue = Color(red: 0.19, green: 0.43, blue: 0.94)
}

struct WMButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(primary ? Color.white : Color.primary)
            .background {
                if primary { RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [WMTheme.blue, Color(red: 0.15, green: 0.34, blue: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                else { RoundedRectangle(cornerRadius: 10).fill(WMTheme.elevated.opacity(0.7)) }
            }
            .overlay { if !primary { RoundedRectangle(cornerRadius: 10).strokeBorder(WMTheme.line.opacity(0.8)) } }
            .shadow(color: primary && enabled ? WMTheme.blue.opacity(0.18) : .clear, radius: 8, y: 3)
            .opacity(enabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
struct WMPageHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon).foregroundStyle(WMTheme.accent)
                Text("Webshare Manager").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(L(title)).font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.6)
            Text(L(subtitle)).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}
struct WMSearchField: View {
    let placeholder: String
    @Binding var text: String
    var submit: () -> Void = {}
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(WMTheme.accent)
            TextField(LocalizedStringKey(placeholder), text: $text).textFieldStyle(.plain).font(.system(size: 13)).onSubmit(submit)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Vymazat hledání") }
        }.padding(13).background(WMTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(WMTheme.line) }
    }
}
struct WMTransferIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(WMTheme.blue.opacity(0.06)).frame(width: 172, height: 172)
            Circle().stroke(WMTheme.accent.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 7])).frame(width: 148, height: 148)
            RoundedRectangle(cornerRadius: 20).fill(WMTheme.elevated).frame(width: 88, height: 102).rotationEffect(.degrees(-14)).offset(x: -34, y: 1)
            RoundedRectangle(cornerRadius: 20).fill(WMTheme.surface).frame(width: 88, height: 102).overlay { RoundedRectangle(cornerRadius: 20).stroke(WMTheme.line) }.rotationEffect(.degrees(12)).offset(x: 24, y: -10)
            Image(systemName: "folder.fill").font(.system(size: 70)).foregroundStyle(LinearGradient(colors: [Color(red: 0.40, green: 0.69, blue: 1), WMTheme.blue], startPoint: .top, endPoint: .bottom)).offset(y: 10).shadow(color: WMTheme.blue.opacity(0.2), radius: 16, y: 10)
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 23, weight: .bold)).foregroundStyle(.white).offset(y: 17)
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(WMTheme.teal).padding(11).background(WMTheme.surface, in: Circle()).overlay { Circle().stroke(WMTheme.line) }.offset(x: 60, y: 46)
        }.frame(width: 210, height: 175).accessibilityHidden(true)
    }
}

struct WMTableCard: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 12)).scrollContentBackground(.hidden)
            .background(WMTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(WMTheme.line) }
            .padding(.horizontal, 24).padding(.top, 14)
    }
}
