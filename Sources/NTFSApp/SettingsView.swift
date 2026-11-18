import SwiftUI

/// Content of the standalone Settings window.
struct SettingsView: View {
    @AppStorage("theme") private var themeRaw = AppTheme.auto.rawValue
    @AppStorage("language") private var languageRaw = AppLanguage.english.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NTFS").font(.system(size: 15, weight: .bold))
                    Text(S.settings).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            row(title: S.themeHeader) {
                ForEach(AppTheme.allCases) { t in chip(t.label, selected: themeRaw == t.rawValue) { themeRaw = t.rawValue } }
            }
            row(title: S.languageHeader) {
                ForEach(AppLanguage.allCases) { l in chip(l.label, selected: languageRaw == l.rawValue) { languageRaw = l.rawValue } }
            }
        }
        .padding(22)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.layoutDirection, (AppLanguage(rawValue: languageRaw) ?? .english).layoutDirection)
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
    }

    private func row<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) { content() }
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(Capsule().fill(selected ? Palette.blue : Color.primary.opacity(0.08)))
        }
        .buttonStyle(PressableStyle())
    }
}
