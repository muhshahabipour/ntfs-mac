import SwiftUI

struct NTFSMenuApp: App {
    @State private var model = DiskListViewModel()
    @AppStorage("theme") private var themeRaw = AppTheme.auto.rawValue

    init() {
        // The popover content is created lazily, so start watching disks at launch.
        let m = DiskListViewModel()
        _model = State(initialValue: m)
        m.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                cards: model.cardModels,
                setup: model.setupItems,
                actions: DiskActions(open: model.open, eject: model.eject, repair: model.repair, retry: model.retry),
                onSetupAction: model.handleSetupAction,
                themeRaw: $themeRaw,
                onQuit: { NSApplication.shared.terminate(nil) })
            .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        } label: {
            Image(systemName: model.needsAttention ? "externaldrive.badge.exclamationmark" : "externaldrive")
        }
        .menuBarExtraStyle(.window)
    }
}
