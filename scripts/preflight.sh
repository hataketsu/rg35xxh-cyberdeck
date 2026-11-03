#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
mode="${1:-build}"
missing=0
for c in git curl make gcc python3 debootstrap qemu-aarch64-static kpartx bmaptool parted xz dtc fdtget rsync mkfs.vfat mkfs.ext4 mkimage losetup mount umount udevadm depmod modinfo fsck.vfat e2fsck mountpoint openssl patch sudo; do
  command -v "$c" >/dev/null || { echo "FALTA: $c"; missing=1; }
done
mkdir -p "$WORK" "$DIST"
avail=$(df -PB1 "$WORK" | awk 'NR==2 {print $4}')
(( avail >= 40*1024*1024*1024 )) || { echo 'Calen 40 GiB lliures'; missing=1; }
if [[ "$mode" == build ]]; then
  command -v docker >/dev/null && docker info >/dev/null 2>&1 || { echo 'Docker no està disponible'; missing=1; }
  sudo -n true 2>/dev/null || { echo 'Cal autenticar sudo des del terminal: sudo -v'; missing=1; }
  if [[ ! -r /proc/sys/fs/binfmt_misc/qemu-aarch64 ]] || ! grep -q 'flags:.*F' /proc/sys/fs/binfmt_misc/qemu-aarch64 || ! grep -qx enabled /proc/sys/fs/binfmt_misc/qemu-aarch64; then
    echo 'Cal binfmt qemu-aarch64 habilitat amb flag F'; missing=1
  fi
fi
exit "$missing"
