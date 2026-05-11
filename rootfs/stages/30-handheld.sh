#!/usr/bin/env bash
# Stage 30: handheld-specific hardware enablement (joypad, audio, USB gadget tools).
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  apt-get install -y --no-install-recommends \
    evtest joystick \
    build-essential bc bison flex libssl-dev libelf-dev kmod git \
    ffmpeg
"

# Note: rocknix-singleadc-joypad.ko is shipped via /lib/modules/$VER/extra/
# from the kernel build stage — built separately by image/pack-image.sh
# which copies it from the staged ROCKNIX artifacts.
