#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
mode="${1:-build}"
backend="${RG_ROOT_BACKEND:-sudo}"
case "$backend" in sudo|docker) ;; *) echo 'RG_ROOT_BACKEND invàlid'; exit 2 ;; esac
if [[ "$backend" == docker && "$TARGET" != rg35xxsp && ( "$mode" == rootfs || "$mode" == build ) ]]; then
  echo 'El rootfs amb backend Docker només està implementat per RG35XXSP'; exit 2
fi
missing=0
case "$mode" in
  kernel|docker) commands='git python3 dtc fdtget' ;;
  rootfs) commands='python3 debootstrap qemu-aarch64-static rsync mount umount sudo' ;;
  image) commands='python3 bmaptool parted xz dtc fdtget rsync mkfs.vfat mkfs.ext4 mkimage depmod modinfo fsck.vfat e2fsck mcopy sudo' ;;
  build) commands='git curl make gcc python3 debootstrap qemu-aarch64-static bmaptool parted xz dtc fdtget rsync mkfs.vfat mkfs.ext4 mkimage mount umount udevadm depmod modinfo fsck.vfat e2fsck mountpoint mcopy openssl patch sudo' ;;
  *) echo "Mode de preflight desconegut: $mode" >&2; exit 2 ;;
esac
if [[ "$backend" == docker && ( "$mode" == rootfs || "$mode" == image || "$mode" == build ) ]]; then
  commands='git python3'
  [[ "$mode" != build ]] || commands+=' dtc fdtget'
fi
for c in $commands; do
  command -v "$c" >/dev/null || { echo "FALTA: $c"; missing=1; }
done
mkdir -p "$WORK" "$DIST"
avail=$(df -PB1 "$WORK" | awk 'NR==2 {print $4}')
(( avail >= 40*1024*1024*1024 )) || { echo 'Calen 40 GiB lliures'; missing=1; }
if [[ "$mode" == build || "$mode" == kernel || "$mode" == docker || "$backend" == docker ]]; then
  if ! command -v docker >/dev/null; then
    echo 'Docker no està instal·lat o no és al PATH'; missing=1
  elif ! docker info >/dev/null; then
    echo 'Docker instal·lat però no accessible; reviseu el daemon i els permisos del socket'; missing=1
  fi
fi
if [[ "$backend" == sudo && ( "$mode" == build || "$mode" == rootfs || "$mode" == image ) ]]; then
  sudo -n true 2>/dev/null || { echo 'Cal autenticar sudo al terminal que executa la compilació'; missing=1; }
fi
if [[ "$mode" == build || "$mode" == rootfs ]]; then
  if [[ ! -r /proc/sys/fs/binfmt_misc/qemu-aarch64 ]] || ! grep -q 'flags:.*F' /proc/sys/fs/binfmt_misc/qemu-aarch64 || ! grep -qx enabled /proc/sys/fs/binfmt_misc/qemu-aarch64; then
    echo 'Cal binfmt qemu-aarch64 habilitat amb flag F'; missing=1
  fi
fi
exit "$missing"
