import Foundation
import NTFSCore

/// All user-facing copy (English default, Persian optional) lives here.
enum S {
    static var title: String { tr("Disk Manager", "مدیریت دیسک") }
    static func diskCount(_ n: Int) -> String {
        AppLanguage.current == .persian ? persianDigits("\(n) دیسک") : (n == 1 ? "1 disk" : "\(n) disks")
    }

    static var open: String { tr("Open", "باز کردن") }
    static var eject: String { tr("Eject Safely", "جدا کردن امن") }
    static var repair: String { tr("Repair & Connect", "ترمیم و اتصال") }
    static var mount: String { tr("Mount", "اتصال") }
    static var unmount: String { tr("Unmount", "جدا کردن اتصال") }
    static var unmounting: String { tr("Unmounting…", "در حال قطع اتصال…") }
    static var notMounted: String { tr("Not mounted", "متصل نیست") }
    static var erasing: String { tr("Erasing…", "در حال پاک‌سازی…") }
    static var diskTools: String { tr("Erase a Disk…", "پاک‌سازی دیسک…") }
    static var eraseTitle: String { tr("Erase Disk", "پاک‌سازی دیسک") }
    static var eraseIntro: String {
        tr("Formats the disk as NTFS (works with Windows and macOS). Everything on it is permanently deleted.",
           "دیسک را با فرمت NTFS (سازگار با ویندوز و مک) فرمت می‌کند. همهٔ اطلاعات آن برای همیشه پاک می‌شود.")
    }
    static var eraseNoDisks: String { tr("Connect an NTFS disk to erase it.", "برای پاک‌سازی، یک دیسک NTFS وصل کنید.") }
    static var newName: String { tr("New name", "نام جدید") }
    static var eraseButton: String { tr("Erase…", "پاک‌سازی…") }
    static var cancel: String { tr("Cancel", "انصراف") }
    static func eraseConfirm(_ name: String, _ size: String) -> String {
        tr("“\(name)” (\(size)) will be erased and cannot be recovered. Type the disk's current name to confirm.",
           "«\(name)» (\(size)) پاک می‌شود و قابل بازگردانی نیست. برای تأیید، نام فعلی دیسک را بنویسید.")
    }
    static var eraseNow: String { tr("Erase Now", "همین حالا پاک کن") }
    static var eraseDone: String { tr("Disk erased.", "دیسک پاک شد.") }
    static var sectionDisks: String { tr("Disks", "دیسک‌ها") }
    static var permissionsHeader: String { tr("Setup", "راه‌اندازی") }
    static var helperRowTitle: String { tr("Helper service", "سرویس کمکی") }
    static var diskAccessRowTitle: String { tr("Full Disk Access", "دسترسی کامل به دیسک") }
    static var openApp: String { tr("Open App", "باز کردن برنامه") }
    static var sectionAbout: String { tr("About", "درباره") }
    static var setupTitle: String { tr("Get started", "شروع کار") }
    static func setupProgress(_ done: Int, _ total: Int) -> String {
        let t = tr("\(done) of \(total) done", "\(done) از \(total) انجام شد")
        return AppLanguage.current == .persian ? persianDigits(t) : t
    }
    static var stepMacFUSE: String { tr("Install macFUSE 5", "نصب macFUSE نسخهٔ ۵") }
    static var stepMacFUSEHow: String { tr("Run in Terminal: brew install --cask macfuse, then enable its extension in System Settings → General → Login Items & Extensions → File System Extensions.",
                                          "در ترمینال: brew install --cask macfuse، سپس افزونهٔ آن را در تنظیمات سیستم ← عمومی ← ورودی‌ها و افزونه‌ها ← File System Extensions روشن کنید.") }
    static var stepNTFS3G: String { tr("Install ntfs-3g", "نصب ntfs-3g") }
    static var stepNTFS3GHow: String { tr("Run in Terminal: brew tap gromgit/fuse && brew install gromgit/fuse/ntfs-3g-mac",
                                         "در ترمینال: brew tap gromgit/fuse && brew install gromgit/fuse/ntfs-3g-mac") }
    static var stepHelper: String { tr("Enable the helper service", "فعال‌سازی سرویس کمکی") }
    static var stepHelperHow: String { tr("It mounts disks with the privileges macOS requires.", "برای وصل کردن دیسک‌ها با دسترسی‌ای که macOS می‌خواهد.") }
    static var stepAccess: String { tr("Allow Full Disk Access", "اجازهٔ دسترسی کامل به دیسک") }
    static var stepAccessHow: String { tr("Turn on “NTFS” in Privacy & Security → Full Disk Access. This lets the app write to disks.",
                                         "«NTFS» را در حریم خصوصی و امنیت ← Full Disk Access روشن کنید تا برنامه بتواند روی دیسک بنویسد.") }
    static var aboutBlurb: String { tr("Read and write NTFS disks on your Mac.", "خواندن و نوشتن روی دیسک‌های NTFS در مک.") }
    static var aboutBuiltOn: String { tr("Built on", "ساخته‌شده بر پایهٔ") }
    static var aboutDisclaimer: String {
        tr("A personal project. Keep backups of important disks.", "یک پروژهٔ شخصی. از دیسک‌های مهم نسخهٔ پشتیبان نگه دارید.")
    }
    static var generalHeader: String { tr("General", "عمومی") }
    static var launchAtLogin: String { tr("Open at login", "اجرا هنگام ورود به سیستم") }
    static var launchAtLoginFailed: String { tr("Couldn't change this. Move the app to /Applications and try again.", "تغییر انجام نشد. برنامه را در /Applications بگذارید و دوباره امتحان کنید.") }
    static var notificationsToggle: String { tr("Notifications", "اعلان‌ها") }
    static func notifyTransferTitle(_ name: String) -> String { tr("Transfer finished", "انتقال تمام شد") }
    static func notifyTransferBody(_ name: String) -> String {
        tr("“\(name)” is idle. You can eject it safely.", "«\(name)» دیگر مشغول نیست. می‌توانید با خیال راحت آن را جدا کنید.")
    }
    static func notifyAttentionTitle(_ name: String) -> String { tr("“\(name)” needs attention", "«\(name)» نیاز به رسیدگی دارد") }
    static var retry: String { tr("Try Again", "تلاش دوباره") }
    static var enable: String { tr("Enable", "فعال‌سازی") }

    static var readWrite: String { tr("Read & Write", "خواندن و نوشتن") }
    static var readOnly: String { tr("Read Only", "فقط خواندنی") }
    static var copying: String { tr("Transferring", "در حال انتقال") }
    static var connecting: String { tr("Connecting…", "در حال اتصال…") }
    static var ejecting: String { tr("Ejecting…", "در حال جدا کردن…") }
    static var reassure: String { tr("Your data stays safe", "اطلاعات شما حفظ می‌شود") }

    static var emptyTitle: String { tr("No disk connected", "دیسکی متصل نیست") }
    static var emptySub: String { tr("Connect a disk to get started.", "برای شروع، یک دیسک متصل کنید.") }

    static var settings: String { tr("Settings", "تنظیمات") }
    /// "Version 0.1.0 (12)" read from the app bundle.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let text = tr("Version \(short) (\(build))", "نسخهٔ \(short) (\(build))")
        return AppLanguage.current == .persian ? persianDigits(text) : text
    }
    static var quit: String { tr("Quit", "خروج") }
    static var themeHeader: String { tr("Appearance", "ظاهر") }
    static var languageHeader: String { tr("Language", "زبان") }
    static var themeAuto: String { tr("Auto", "خودکار") }
    static var themeLight: String { tr("Light", "روشن") }
    static var themeDark: String { tr("Dark", "تیره") }

    // MARK: number formats

    static func size(_ bytes: UInt64) -> String {
        AppLanguage.current == .persian ? persianSize(bytes) : englishSize(bytes)
    }
    static func percent(_ f: Double) -> String {
        AppLanguage.current == .persian ? persianPercent(f) : englishPercent(f)
    }
    static func speed(_ bps: Double) -> String {
        AppLanguage.current == .persian ? persianSpeed(bps) : englishSpeed(bps)
    }
    static func usedOfTotal(used: UInt64, total: UInt64) -> String {
        tr("\(size(used)) used of \(size(total))", "\(size(used)) پر شده از \(size(total))")
    }

    // MARK: messages

    static func warning(for health: VolumeHealth) -> String {
        switch health {
        case .dirty:
            tr("Windows didn't shut this disk down properly. It needs repair before it can be written to.",
               "ویندوز دیسک را درست خاموش نکرده است. برای نوشتن باید ترمیم شود.")
        case .hibernated:
            tr("Windows is hibernated. Fully shut Windows down (Shut down), then reconnect the disk.",
               "ویندوز در حالت خواب زمستانی (hibernate) است. در ویندوز آن را کامل خاموش (Shut down) کنید و دوباره وصل کنید.")
        case .needsWindowsCheck:
            tr("This disk needs a check in Windows (chkdsk).", "دیسک نیاز به بررسی در ویندوز دارد (chkdsk).")
        case .inUse:
            tr("Another driver (for example Paragon) is holding this disk.",
               "درایور دیگری (مثلاً Paragon) این دیسک را در اختیار گرفته است.")
        case .notNTFS:
            tr("This isn't a valid NTFS disk.", "این دیسک NTFS معتبر نیست.")
        case .unknown, .clean:
            tr("This disk can't be connected with write access.", "دیسک را نمی‌توان با نوشتن متصل کرد.")
        }
    }

    static func problem(_ p: Problem) -> String {
        switch p {
        case .macFUSEMissing: tr("macFUSE is not installed.", "macFUSE نصب نیست.")
        case .macFUSETooOld(let v):
            tr("macFUSE \(v) is too old. Version 5 or newer is required.",
               persianDigits("macFUSE قدیمی است (نسخهٔ \(v)). نسخهٔ ۵ یا بالاتر لازم است."))
        case .ntfs3gMissing: tr("ntfs-3g is not installed.", "ntfs-3g نصب نیست.")
        case .paragonConflict:
            tr("Paragon's NTFS driver is installed and may conflict.", "درایور Paragon روی این مک نصب است و ممکن است تداخل ایجاد کند.")
        }
    }

    static var openSettings: String { tr("Open Settings", "باز کردن تنظیمات") }
    static var diskAccessDeniedText: String {
        tr("macOS is blocking access to this disk. Turn on “NTFS” in System Settings → Privacy & Security → Full Disk Access, then reconnect the disk.",
           "macOS دسترسی به این دیسک را مسدود کرده است. در تنظیمات سیستم ← حریم خصوصی و امنیت ← Full Disk Access، «NTFS» را روشن کنید و دیسک را دوباره وصل کنید.")
    }
    static var diskAccessTip: String {
        tr("One-time setup: turn on “NTFS” in Full Disk Access so macOS lets the app write to disks.",
           "تنظیم یک‌باره: «NTFS» را در Full Disk Access روشن کنید تا macOS اجازهٔ نوشتن روی دیسک‌ها را بدهد.")
    }

    static var helperDisabled: String { tr("The helper service is not enabled.", "سرویس کمکی فعال نیست.") }
    static var helperNeedsApproval: String {
        tr("To finish setup, turn on “NTFS” in System Settings → General → Login Items & Extensions.",
           "برای فعال شدن، در تنظیمات سیستم ← عمومی ← ورودی‌ها و افزونه‌ها، «NTFS» را روشن کنید.")
    }

    static func message(for error: Error) -> String {
        guard let e = error as? MountError else { return tr("The helper service is unreachable.", "سرویس کمکی در دسترس نیست.") }
        switch e {
        case .extensionNotEnabled:
            return tr("The macFUSE extension is off. Turn it on in System Settings → General → Login Items & Extensions → File System Extensions.",
                      "افزونهٔ macFUSE روشن نیست. در تنظیمات سیستم ← عمومی ← ورودی‌ها و افزونه‌ها ← File System Extensions آن را روشن کنید.")
        case .busy(let holders):
            return tr("The disk is in use by: ", "دیسک در حال استفاده است: ") + holders.joined(separator: tr(", ", "، "))
        case .notClean(let h): return warning(for: h)
        case .toolMissing: return tr("ntfs-3g was not found.", "ntfs-3g پیدا نشد.")
        case .diskAccessDenied: return diskAccessDeniedText
        case .invalidDevice: return tr("Invalid device.", "دستگاه نامعتبر است.")
        case .failed(let detail): return detail.isEmpty ? tr("The operation failed.", "عملیات ناموفق بود.") : detail
        }
    }
}
