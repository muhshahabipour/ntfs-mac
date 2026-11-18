import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("NTFS").font(.system(size: 22, weight: .bold))
            Text(S.version).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(S.aboutBlurb).font(.system(size: 13)).padding(.top, 6)
            Text(S.aboutBuiltOn).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}
