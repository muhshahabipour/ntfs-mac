#!/bin/bash
# Usage: scripts/make-dmg.sh   → dist/NTFS-<version>.dmg
# Builds the app, then packs it with an Applications shortcut, a prerequisites installer and a short guide.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/NTFS.app/Contents/Info.plist)
STAGE=$(mktemp -d)/NTFS
mkdir -p "$STAGE" dist
cp -R build/NTFS.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/1 - Install prerequisites.command" <<'EOS'
#!/bin/bash
# Installs macFUSE and ntfs-3g with Homebrew (https://brew.sh must already be installed).
set -e
command -v brew >/dev/null || { echo "Homebrew is not installed. See https://brew.sh"; read -r -p "Press Return"; exit 1; }
brew install --cask macfuse
brew tap gromgit/fuse
brew install gromgit/fuse/ntfs-3g-mac
echo
echo "Done. Next: open System Settings → General → Login Items & Extensions → File System Extensions and enable macFUSE."
echo "You may need to restart the Mac once."
read -r -p "Press Return to close"
EOS
chmod +x "$STAGE/1 - Install prerequisites.command"

cat > "$STAGE/2 - Allow the app.command" <<'EOS'
#!/bin/bash
# Removes the download quarantine flag so macOS lets the app start (the app is not notarized).
xattr -dr com.apple.quarantine /Applications/NTFS.app && echo "OK. Open NTFS from Applications." || echo "Drag NTFS.app into Applications first."
read -r -p "Press Return to close"
EOS
chmod +x "$STAGE/2 - Allow the app.command"

cat > "$STAGE/README.txt" <<EOS
NTFS $VERSION — read and write NTFS disks on a Mac

1. Drag NTFS.app into Applications.
2. Double-click "1 - Install prerequisites.command" (needs Homebrew), then enable the macFUSE extension
   in System Settings → General → Login Items & Extensions → File System Extensions. Restart if asked.
3. Double-click "2 - Allow the app.command".
4. Open NTFS from Applications. It lives in the menu bar; follow the "Get started" card in its window
   (helper service, Full Disk Access).

Windows tip: turn off Fast Startup in Windows, and use Shut down (not Restart/Hibernate), so disks open read/write on the Mac.
EOS

OUT="dist/NTFS-$VERSION.dmg"
rm -f "$OUT"
hdiutil create -volname "NTFS $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
