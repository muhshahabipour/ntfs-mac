# Spike notes (Task 0) — 2026-11-17

## Environment
- macOS 27.0.1 (26A434), arm64, SIP enabled, Xcode 27.2, Swift 6.4.2.
- macFUSE **5.5.0** (upgraded from 4.6.0 via `brew upgrade --cask macfuse`). FSKit modules `io.macfuse.app.fsmodule.macfuse` / `-local` appear in `pluginkit` only after macfuse.app was launched once (`open /Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app`), and the user enabled the extension in System Settings (General → Login Items & Extensions → File System Extensions).
- ntfs-3g: Homebrew core's `ntfs-3g` is **Linux-only** (`depends_on :linux`). Working source: `gromgit/fuse` tap, formula `ntfs-3g-mac` 2026.9.28 (needs `brew trust --formula gromgit/fuse/ntfs-3g-mac`). Binaries in `/opt/homebrew/bin` (`ntfs-3g`, `ntfs-3g.probe`, `ntfsfix`, `ntfsinfo`), `mkntfs` in `/opt/homebrew/sbin`.

## Result: read/write mount works
Command (as root; unprivileged user is refused for block devices with external FUSE):

    /opt/homebrew/bin/ntfs-3g.probe --readwrite /dev/diskN        # exit 0 = clean
    /opt/homebrew/bin/ntfs-3g /dev/diskN <mountpoint> -o local,rw,volname=<label>

Verified on a 256 MB virtual NTFS image: mount table shows `(macfuse, local, nodev, synchronous)`, `df` reports 256Mi, a file was written and read back, `diskutil unmount <mountpoint>` unmounted cleanly.

## Things learned
- Without the FSKit extension enabled, `ntfs-3g` starts, `mount_macfuse` tries to open macfuse.app, and `ntfs-3g` unmounts itself within seconds — no error on the terminal. The app must detect this (mount not in `mount` table after ~10 s) and send the user to the extension setting.
- The mount is `synchronous`; performance with extra options (`big_writes`, `noatime`, `windows_names`) is still to be measured.
- `/dev/diskN` of an attached image vanishes after detach; always recreate in scripts.
- `/Library/Filesystems/ufsd_NTFS.fs` (Paragon) is present. It did **not** block the mount above, but it is not known whether it takes over real USB NTFS disks automatically.

## Still open (decide before / during Task 5)
- Dirty / hibernated volume output strings of `ntfs-3g.probe` (to capture for Task 2 fixtures).
- Remount read-back after unmount, and throughput numbers.
- **No code-signing identity on this Mac** (`security find-identity` → 0). `SMAppService` daemon registration likely needs a signed app. Options: sign in to Xcode with an Apple ID to get a free "Apple Development" identity; or fall back to a sudoers-restricted wrapper script.
