import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self { case .auto: nil; case .light: .light; case .dark: .dark }
    }
    var label: String {
        switch self { case .auto: S.themeAuto; case .light: S.themeLight; case .dark: S.themeDark }
    }
}

enum Palette {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
}

extension View {
    /// The soft card used for each disk.
    func cardSurface(cornerRadius: CGFloat = 14) -> some View {
        background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
    }
}
