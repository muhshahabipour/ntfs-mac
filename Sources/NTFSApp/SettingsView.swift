import SwiftUI

/// The Settings section of the main window.
struct SettingsView: View {
    let model: DiskListViewModel
    @AppStorage("theme") private var themeRaw = AppTheme.auto.rawValue
    @AppStorage("language") private var languageRaw = AppLanguage.english.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NTFS").font(.system(size: 17, weight: .bold))
                    Text(S.version).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            row(title: S.themeHeader) {
                ForEach(AppTheme.allCases) { t in chip(t.label, selected: themeRaw == t.rawValue) { themeRaw = t.rawValue } }
            }
            row(title: S.languageHeader) {
                ForEach(AppLanguage.allCases) { l in chip(l.label, selected: languageRaw == l.rawValue) { languageRaw = l.rawValue } }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text(S.permissionsHeader).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                statusRow(S.helperRowTitle, ok: model.helperStatus == .enabled,
                          action: model.helperStatus == .enabled ? nil : (S.enable, { model.handleSetupAction("helper") }))
                statusRow(S.diskAccessRowTitle, ok: model.diskAccessOK,
                          action: (S.openSettings, { model.handleSetupAction("diskAccess") }))
            }
        }
    }

    private func statusRow(_ title: String, ok: Bool, action: (String, () -> Void)?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Palette.green : Palette.orange)
            Text(title).font(.system(size: 12))
            Spacer()
            if let action { Button(action.0, action: action.1).controlSize(.small) }
        }
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
