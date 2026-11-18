import SwiftUI

/// First-run checklist shown at the top of the Disks section until every step is done.
struct SetupGuideView: View {
    let model: DiskListViewModel

    var body: some View {
        let steps = model.setupSteps
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(S.setupTitle).font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text(S.setupProgress(steps.filter(\.done).count, steps.count))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16)).foregroundStyle(step.done ? Palette.green : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(.system(size: 13, weight: .semibold))
                            if !step.done {
                                Text(step.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            }
                        }
                        Spacer(minLength: 0)
                        if !step.done, let action = step.actionTitle {
                            Button(action) { model.handleSetupAction(step.id) }.controlSize(.small)
                        }
                    }
                }
            }
            .padding(14)
            .cardSurface()
        }
    }
}
