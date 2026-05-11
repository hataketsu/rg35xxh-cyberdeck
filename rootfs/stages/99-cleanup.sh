#!/usr/bin/env bash
set -euo pipefail
ROOTFS="$1"
run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  chroot "$ROOTFS" /bin/bash -e -c "$1"
}
run "
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  rm -rf /tmp/* /var/tmp/*
  journalctl --vacuum-time=1s 2>/dev/null || true
  rm -f /etc/machine-id /var/lib/dbus/machine-id
  touch /etc/machine-id
"
rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
rm -f "$ROOTFS/etc/resolv.conf"
ln -s /run/systemd/resolve/stub-resolv.conf "$ROOTFS/etc/resolv.conf" || true
