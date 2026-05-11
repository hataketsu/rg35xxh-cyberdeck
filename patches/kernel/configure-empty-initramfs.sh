#!/usr/bin/env bash
# Run inside the rocknix-builder Docker container as user `docker`.
# 1. Empty CONFIG_INITRAMFS_SOURCE so the built Image doesn't carry the ROCKNIX
#    recovery cpio (which would intercept boot and drop to busybox).
# 2. Flip MMC drivers to builtin (=y) so the kernel mounts mmcblk0p2 without
#    needing any initramfs.
# 3. Enable HIDRAW=y / UHID=m so BLE HID-over-GATT keyboards work.
# 4. Rebuild Image (+ matching modules).
set -euo pipefail

KSRC=/work/build.ROCKNIX-H700.aarch64/build/linux-7.0.2
cd "$KSRC"

export PATH=/work/build.ROCKNIX-H700.aarch64/toolchain/bin:$PATH
export ARCH=arm64
export CROSS_COMPILE=aarch64-rocknix-linux-gnu-

./scripts/config --file .config \
  --set-str  INITRAMFS_SOURCE "" \
  -e MMC -e MMC_BLOCK -e MMC_SUNXI \
  -e HIDRAW -m UHID -e HID_BATTERY_STRENGTH

yes "" | make olddefconfig
make -j"$(nproc)" Image modules dtbs
