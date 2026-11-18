import SwiftUI
import AppKit

struct NTFSMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusController?
    func applicationDidFinishLaunching(_ notification: Notification) { controller = StatusController() }
}

/// The menu bar item and its popover. An NSPopover (instead of MenuBarExtra's window) resizes
/// cleanly when the content grows or shrinks.
@MainActor
final class StatusController: NSObject {
    private let model = DiskListViewModel()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private let router = WindowRouter()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: PopoverRoot(model: model, onOpenApp: { [weak self] in self?.openMainWindow(.disks) }, onQuit: { NSApplication.shared.terminate(nil) }))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        trackIcon()
        applyTheme()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyTheme() }
        }
        model.start()
    }

    private func applyTheme() {
        let raw = UserDefaults.standard.string(forKey: "theme") ?? AppTheme.auto.rawValue
        switch AppTheme(rawValue: raw) ?? .auto {
        case .auto: popover.appearance = nil
        case .light: popover.appearance = NSAppearance(named: .aqua)
        case .dark: popover.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func trackIcon() {
        withObservationTracking {
            let name = model.needsAttention ? "externaldrive.badge.exclamationmark" : "externaldrive"
            statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "NTFS")
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.trackIcon() } }
        }
    }

    private func openMainWindow(_ section: AppSection) {
        popover.performClose(nil)
        router.section = section
        if mainWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: MainWindowView(model: model, router: router)))
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.title = "NTFS"
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 720, height: 480))
            w.contentMinSize = NSSize(width: 640, height: 420)
            w.center()
            mainWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggle() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

struct PopoverRoot: View {
    let model: DiskListViewModel
    var onOpenApp: () -> Void
    var onQuit: () -> Void
    @AppStorage("theme") private var themeRaw = AppTheme.auto.rawValue

    var body: some View {
        PopoverView(
            cards: model.cardModels,
            setup: model.setupItems,
            actions: DiskActions(open: model.open, eject: model.eject, mount: model.mount, unmount: model.unmount, repair: model.repair, retry: model.retry),
            onSetupAction: model.handleSetupAction,
            onOpenApp: onOpenApp,
            onQuit: onQuit)
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
    }
}
