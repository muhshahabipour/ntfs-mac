#!/bin/bash
# Run as root: sudo scripts/spike-mount.sh /dev/diskN
# Mounts a TEST image read/write, round-trips a file, unmounts. Prints diagnostics.
set -u
DEV="${1:?device}"
case "$DEV" in /dev/disk[0-9]*) ;; *) echo "bad device"; exit 1;; esac
MNT=/private/tmp/ntfs-spike-mnt
mkdir -p "$MNT"

/opt/homebrew/bin/ntfs-3g.probe --readwrite "$DEV"; echo "probe exit=$?"
/opt/homebrew/bin/ntfs-3g "$DEV" "$MNT" -o local,rw,volname=SpikeTest 2>&1; echo "mount exit=$?"

for i in 1 2 3 4 5 6 7 8 9 10; do
  mount | grep -q "$MNT" && break
  sleep 1
done
echo "--- mount table:"; mount | grep -i -E "spike|macfuse"
echo "--- df:"; df -h "$MNT" | tail -1

if mount | grep -q "$MNT"; then
  echo "hello-ntfs" > "$MNT/spike.txt" && echo "write ok"
  cat "$MNT/spike.txt"
  sync
  diskutil unmount "$MNT" 2>&1 || umount "$MNT"
  echo "unmounted"
else
  echo "NOT MOUNTED"
  pgrep -fl ntfs-3g
fi
