import SwiftUI
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case disks, settings
    var id: String { rawValue }
    var title: String { self == .disks ? S.sectionDisks : S.settings }
    var icon: String { self == .disks ? "externaldrive" : "gearshape" }
}

@MainActor @Observable
final class WindowRouter { var section: AppSection = .disks }

/// The app's main window: a sidebar with Disks and Settings. The menu bar popover stays the quick-access surface.
struct MainWindowView: View {
    let model: DiskListViewModel
    @Bindable var router: WindowRouter
    @AppStorage("language") private var languageRaw = AppLanguage.english.rawValue
    @AppStorage("theme") private var themeRaw = AppTheme.auto.rawValue

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: Binding(get: { router.section }, set: { router.section = $0 ?? .disks })) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            ScrollView {
                Group {
                    switch router.section {
                    case .disks: DiskToolsView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                .padding(24)
                .frame(maxWidth: 460, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .navigationTitle(router.section.title)
        }
        .environment(\.layoutDirection, (AppLanguage(rawValue: languageRaw) ?? .english).layoutDirection)
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .frame(minWidth: 640, minHeight: 420)
    }
}
