#!/bin/bash
# Usage: sudo scripts/bench-mount.sh /dev/diskNsM
# Benchmarks several ntfs-3g mount-option sets on ONE disk (writes only a temp 256 MB file, then deletes it).
# The disk is unmounted first; afterwards use the app's "Mount" button to reconnect it.
set -u
DEV="${1:?device, e.g. /dev/disk12s1}"
case "$DEV" in /dev/disk[0-9]*s[0-9]*) ;; *) echo "bad device"; exit 1;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
MP=/Volumes/ntfs-bench
diskutil unmount "$DEV" >/dev/null 2>&1
for opts in "local,rw,volname=bench" \
            "local,rw,volname=bench,big_writes" \
            "local,rw,volname=bench,big_writes,noatime" \
            "local,rw,volname=bench,big_writes,noatime,iosize=1048576" \
            "local,rw,volname=bench,big_writes,noatime,max_read=1048576,iosize=1048576"; do
  mkdir -p "$MP"
  echo "== $opts"
  /opt/homebrew/bin/ntfs-3g "$DEV" "$MP" -o "$opts" 2>&1 | head -2
  sleep 3
  if mount | grep -q " on $MP "; then
    python3 "$HERE/bench-io.py" "$MP"
    diskutil unmount "$MP" >/dev/null 2>&1 || diskutil unmount force "$MP" >/dev/null 2>&1
  else
    echo "(did not mount with these options)"
  fi
  sleep 2
done
rmdir "$MP" 2>/dev/null
echo "done. Press Mount in the app to reconnect the disk."
