#!/usr/bin/env bash
# Stage 10: base packages in chroot.
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run_chroot() {
  # bind mounts
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  cp /etc/resolv.conf "$ROOTFS/etc/"
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run_chroot "
  locale-gen
  apt-get update
  apt-get install -y --no-install-recommends \
    linux-base initramfs-tools \
    e2fsprogs dosfstools parted gdisk cloud-guest-utils \
    openssh-server cron rsync wget \
    pulseaudio pulseaudio-utils alsa-utils \
    network-manager network-manager-gnome dnsmasq-base \
    bluez bluez-tools blueman rfkill \
    python3 python3-evdev \
    upower brightnessctl \
    bmap-tools
  # SSH on by default for first boot
  systemctl enable ssh
"
