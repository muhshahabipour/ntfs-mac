import SwiftUI
import NTFSCore

struct SetupItem: Identifiable, Equatable {
    let id: String
    let text: String
    var action: String? = nil
}

struct PopoverView: View {
    let cards: [DiskCardModel]
    let setup: [SetupItem]
    let actions: DiskActions
    var onSetupAction: (String) -> Void = { _ in }
    @AppStorage("language") private var languageRaw = AppLanguage.english.rawValue
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(S.title).font(.system(size: 15, weight: .bold))
                Spacer()
                Text(S.diskCount(cards.count)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(setup) { item in setupRow(item) }
            if cards.isEmpty { emptyState } else {
                ForEach(cards) { DiskCardView(model: $0, actions: actions) }
            }
            footer
        }
        .padding(14)
        .frame(width: 310)
        .environment(\.layoutDirection, (AppLanguage(rawValue: languageRaw) ?? .english).layoutDirection)
        .fixedSize(horizontal: false, vertical: true)
        // No implicit layout animation: the menu bar window resizes in one step, so animating the
        // content inside it makes it lag behind the frame and look glitchy.
        .transaction { $0.animation = nil }
    }

    private func setupRow(_ item: SetupItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wrench.and.screwdriver").foregroundStyle(Palette.orange)
            Text(item.text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let action = item.action {
                Button(action) { onSetupAction(item.id) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.orange.opacity(0.12)))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "externaldrive").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
            Text(S.emptyTitle).font(.system(size: 14, weight: .semibold))
            Text(S.emptySub).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Button(action: onOpenSettings) { Label(S.settings, systemImage: "gearshape") }
                    .buttonStyle(.plain)
                Spacer()
                Text(S.version).font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Button(S.quit, action: onQuit).buttonStyle(.plain)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
