import SwiftUI
import NTFSCore

struct DiskCardModel: Identifiable, Equatable {
    let id: String
    let name: String
    let totalBytes: UInt64
    let usedBytes: UInt64
    let state: CardState
}

struct DiskActions {
    var open: (String) -> Void = { _ in }
    var eject: (String) -> Void = { _ in }
    var repair: (String) -> Void = { _ in }
    var retry: (String) -> Void = { _ in }
}

struct DiskCardView: View {
    let model: DiskCardModel
    let actions: DiskActions

    var body: some View {
        VStack(spacing: 10) {
            header
            if case .needsAttention(let health, _) = model.state { warning(health) }
            if case .failed(let text) = model.state { failure(text) }
            buttons
        }
        .padding(12)
        .cardSurface()
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 12) {
            CapacityRing(fraction: fraction, tint: ringTint, active: isCopying)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                badge
            }
            Spacer(minLength: 0)
        }
    }

    private var fraction: Double {
        switch model.state {
        case .ready(let f), .needsAttention(_, let f), .copying(_, let f): f
        default: usedFraction(used: model.usedBytes, total: model.totalBytes)
        }
    }

    private var isCopying: Bool { if case .copying = model.state { true } else { false } }

    private var ringTint: Color {
        if case .needsAttention = model.state { return Palette.orange }
        if case .failed = model.state { return Palette.red }
        return Palette.blue
    }

    private var subtitle: String {
        switch model.state {
        case .copying(let bps, _): "\(S.copying) · \(S.speed(bps))"
        case .mounting: S.connecting
        case .ejecting: S.ejecting
        default: S.usedOfTotal(used: model.usedBytes, total: model.totalBytes)
        }
    }

    @ViewBuilder private var badge: some View {
        switch model.state {
        case .ready, .copying: pill(S.readWrite, Palette.green)
        case .needsAttention: pill(S.readOnly, Palette.orange)
        case .mounting, .ejecting: ProgressView().controlSize(.small)
        case .failed: EmptyView()
        }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: warning / failure

    private func warning(_ health: VolumeHealth) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Palette.orange)
                Text(S.warning(for: health)).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            if health.isRepairable {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield")
                    Text(S.reassure)
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.orange.opacity(0.25)))
    }

    private func failure(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.octagon").foregroundStyle(Palette.red)
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.red.opacity(0.1)))
    }

    // MARK: buttons

    @ViewBuilder private var buttons: some View {
        switch model.state {
        case .ready, .copying:
            HStack(spacing: 8) {
                button(S.open, icon: "folder", style: .secondary) { actions.open(model.id) }
                button(S.eject, icon: "eject.fill", style: .primary) { actions.eject(model.id) }
            }
        case .needsAttention(let health, _):
            if health.isRepairable {
                button(S.repair, icon: nil, style: .primary) { actions.repair(model.id) }
            } else {
                button(S.eject, icon: "eject.fill", style: .secondary) { actions.eject(model.id) }
            }
        case .failed:
            HStack(spacing: 8) {
                button(S.retry, icon: "arrow.clockwise", style: .primary) { actions.retry(model.id) }
                button(S.eject, icon: "eject.fill", style: .secondary) { actions.eject(model.id) }
            }
        case .mounting, .ejecting:
            EmptyView()
        }
    }

    private enum Style { case primary, secondary }

    private func button(_ title: String, icon: String?, style: Style, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .foregroundStyle(style == .primary ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(style == .primary ? Palette.blue : Color.primary.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
