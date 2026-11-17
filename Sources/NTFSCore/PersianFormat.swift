import Foundation

public func persianDigits(_ s: String) -> String {
    let map: [Character: Character] = ["0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴",
                                       "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"]
    return String(s.map { map[$0] ?? $0 })
}

/// One decimal at most, no trailing ".0".
private func compact(_ v: Double) -> String {
    let r = (v * 10).rounded() / 10
    return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
}

/// Decimal units (like Finder): «۱.۲ ترابایت».
public func persianSize(_ bytes: UInt64) -> String {
    let b = Double(bytes)
    let text: String
    switch b {
    case 1e12...: text = "\(compact(b / 1e12)) ترابایت"
    case 1e9...:  text = "\(compact(b / 1e9)) گیگابایت"
    case 1e6...:  text = "\(compact(b / 1e6)) مگابایت"
    case 1e3...:  text = "\(compact(b / 1e3)) کیلوبایت"
    default:      text = "\(bytes) بایت"
    }
    return persianDigits(text)
}

/// «۶۲٪», clamped to 0...100.
public func persianPercent(_ fraction: Double) -> String {
    let f = fraction.isNaN ? 0 : min(1, max(0, fraction))
    return persianDigits("\(Int((f * 100).rounded()))٪")
}

public func persianSpeed(_ bytesPerSecond: Double) -> String {
    let b = bytesPerSecond.isNaN ? 0 : max(0, bytesPerSecond)
    let text = b >= 1e6
        ? "\(Int((b / 1e6).rounded())) مگابایت بر ثانیه"
        : "\(Int((b / 1e3).rounded())) کیلوبایت بر ثانیه"
    return persianDigits(text)
}
