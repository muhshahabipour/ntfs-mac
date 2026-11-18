import SwiftUI
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case disks, settings, about
    var id: String { rawValue }
    var title: String {
        switch self { case .disks: S.sectionDisks; case .settings: S.settings; case .about: S.sectionAbout }
    }
    var icon: String {
        switch self { case .disks: "externaldrive"; case .settings: "gearshape"; case .about: "info.circle" }
    }
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
                    case .disks:
                        VStack(alignment: .leading, spacing: 20) {
                            SetupGuideView(model: model)
                            DiskToolsView(model: model)
                        }
                    case .settings: SettingsView(model: model)
                    case .about: AboutView()
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
