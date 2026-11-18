import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("NTFS").font(.system(size: 22, weight: .bold))
            Text(S.version).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(S.aboutBlurb).font(.system(size: 13)).multilineTextAlignment(.center).padding(.top, 6)

            Divider().padding(.vertical, 10)

            VStack(spacing: 6) {
                Text(S.aboutBuiltOn).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Link("macFUSE", destination: URL(string: "https://macfuse.github.io")!)
                    Link("ntfs-3g", destination: URL(string: "https://github.com/tuxera/ntfs-3g")!)
                }
                .font(.system(size: 12))
            }

            Text(S.aboutDisclaimer).font(.system(size: 10)).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
