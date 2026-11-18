import SwiftUI
import NTFSCore

/// The "Erase a Disk" window. Deliberately separate from the menu bar popover: destructive work gets room and friction.
struct DiskToolsView: View {
    let model: DiskListViewModel

    @State private var selectedID: String?
    @State private var newName = ""
    @State private var confirming = false
    @State private var typed = ""
    @State private var working = false
    @State private var message: (text: String, isError: Bool)?

    private var disks: [DiskCardModel] { model.cardModels }
    private var selected: DiskCardModel? { disks.first { $0.id == selectedID } ?? disks.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(S.eraseTitle).font(.system(size: 16, weight: .bold))
            Text(S.eraseIntro).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            if disks.isEmpty {
                Text(S.eraseNoDisks).font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Picker("", selection: Binding(get: { selected?.id ?? "" }, set: { selectedID = $0; confirming = false; typed = "" })) {
                    ForEach(disks) { Text("\($0.name) · \(S.size($0.totalBytes))").tag($0.id) }
                }
                .labelsHidden().disabled(working)

                VStack(alignment: .leading, spacing: 6) {
                    Text(S.newName).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("NTFS", text: $newName).textFieldStyle(.roundedBorder).disabled(working)
                }

                if confirming, let disk = selected {
                    confirmation(disk)
                } else {
                    Button(role: .destructive) { confirming = true; typed = ""; message = nil } label: {
                        Text(S.eraseButton).frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent).tint(Palette.red).disabled(working || selected == nil)
                }
            }

            if working { ProgressView().controlSize(.small) }
            if let message {
                Label(message.text, systemImage: message.isError ? "xmark.octagon" : "checkmark.circle")
                    .font(.system(size: 12)).foregroundStyle(message.isError ? Palette.red : Palette.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func confirmation(_ disk: DiskCardModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(S.eraseConfirm(disk.name, S.size(disk.totalBytes)), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12)).foregroundStyle(Palette.orange).fixedSize(horizontal: false, vertical: true)
            TextField(disk.name, text: $typed).textFieldStyle(.roundedBorder).disabled(working)
            HStack(spacing: 8) {
                Button(S.cancel) { confirming = false; typed = "" }.disabled(working)
                Button(role: .destructive) { run(disk) } label: { Text(S.eraseNow) }
                    .buttonStyle(.borderedProminent).tint(Palette.red)
                    .disabled(working || typed != disk.name)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.orange.opacity(0.1)))
    }

    private func run(_ disk: DiskCardModel) {
        working = true; message = nil
        let label = newName
        Task {
            let failure = await model.erase(disk.id, label: label)
            working = false; confirming = false; typed = ""
            message = failure.map { ($0, true) } ?? (S.eraseDone, false)
        }
    }
}
