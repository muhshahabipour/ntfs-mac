import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en", persian = "fa"
    var id: String { rawValue }

    /// Read at call time so a change in settings applies on the next view update. English is the default.
    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    var layoutDirection: LayoutDirection { self == .persian ? .rightToLeft : .leftToRight }
    var label: String { self == .persian ? "فارسی" : "English" }
}

/// Picks the English or Persian text for the current language.
func tr(_ en: String, _ fa: String) -> String { AppLanguage.current == .persian ? fa : en }
