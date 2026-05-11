#!/usr/bin/env bash
# Stage 50: copy overlay/ verbatim into rootfs. Preserves permissions.
set -euo pipefail
ROOTFS="$1"
OVERLAY="$2"
. "$(dirname "$0")/../../VERSIONS"

rsync -aHAX "$OVERLAY/" "$ROOTFS/"

# Make scripts executable
chmod +x "$ROOTFS"/usr/local/bin/* 2>/dev/null || true
chmod +x "$ROOTFS"/usr/local/sbin/* 2>/dev/null || true

# Enable our services
run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  systemctl enable joy2mouse.service || true
  systemctl enable wifi-watchdog.service || true
  systemctl enable usb-mtp.service || true
  systemctl enable expand-rootfs.service || true
"

# Persistent journal dir
install -d -o root -g 100 -m 2755 "$ROOTFS/var/log/journal"

# fstab — labels set in pack-image.sh
cat > "$ROOTFS/etc/fstab" <<EOF
LABEL=rootfs   /        ext4   defaults,noatime,errors=remount-ro  0 1
LABEL=BOOT     /boot    vfat   defaults,noatime,umask=0022          0 2
proc           /proc    proc   defaults                             0 0
tmpfs          /tmp     tmpfs  defaults,nosuid,nodev,size=256M      0 0
EOF
