import SwiftUI
import NTFSCore

struct CapacityRing: View {
    let fraction: Double
    var tint: Color = Palette.blue
    var active = false
    var size: CGFloat = 64

    @State private var shown = 0.0
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if active {
                Circle()
                    .trim(from: 0, to: 0.12)
                    .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 270 : -90))
                    .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: spin)
            }
            Text(S.percent(fraction))
                .font(.system(size: size * 0.2, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { shown = min(1, max(0, fraction)) }
            spin = active
        }
        .onChange(of: fraction) { _, new in withAnimation(.easeOut(duration: 0.4)) { shown = min(1, max(0, new)) } }
        .onChange(of: active) { _, new in spin = new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(S.percent(fraction)))
    }
}
