import AppKit
import SwiftUI
import NTFSCore

/// Four popovers side by side, like the reference design. Used for `--render-demo` and previews.
struct DemoGallery: View {
    private static let tb: UInt64 = 1_000_000_000_000
    private func card(_ state: CardState, used: UInt64 = 1_200_000_000_000) -> [DiskCardModel] {
        [DiskCardModel(id: "d", name: "Seagate Backup", totalBytes: 2 * Self.tb, usedBytes: used, state: state)]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            demo(card(.ready(usedFraction: 0.62)))
            demo(card(.needsAttention(.dirty, usedFraction: 0.62)))
            demo(card(.copying(bytesPerSecond: 185_000_000, usedFraction: 0.62)))
            demo([])
        }
        .padding(28)
    }

    private func demo(_ cards: [DiskCardModel]) -> some View {
        PopoverView(cards: cards, setup: [], actions: DiskActions())
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
    }
}

@MainActor
func renderDemo(to directory: String) {
    for (name, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
        let view = DemoGallery()
            .environment(\.colorScheme, scheme)
            .background(scheme == .light ? Color(white: 0.92) : Color(white: 0.1))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
        try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("demo-\(name).png"))
    }
}
