#!/bin/bash
# Usage: make-test-image.sh <label> <size-mb> [image-path]
# Creates a raw NTFS image, attaches it WITHOUT mounting, prints the /dev/diskN node.
# Test images only: never run mkntfs against a real drive.
set -euo pipefail
LABEL="${1:?label}"
SIZE_MB="${2:?size in MB}"
IMG="${3:-/private/tmp/ntfs-test-${LABEL// /_}.img}"
MKNTFS=/opt/homebrew/sbin/mkntfs

rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1m count="$SIZE_MB" status=none
DEV=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "$IMG" | awk 'NR==1{print $1}')
case "$DEV" in /dev/disk[0-9]*) ;; *) echo "unexpected device: $DEV" >&2; exit 1;; esac
"$MKNTFS" -F -Q -L "$LABEL" "$DEV" >/dev/null
echo "$DEV"
