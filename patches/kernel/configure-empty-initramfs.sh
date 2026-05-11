#!/usr/bin/env bash
# Run inside the rocknix-builder Docker container as user `docker`.
#
# CRITICAL: ROCKNIX's `scripts/build linux` wrapper invokes `usr/gen_initramfs.sh`
# with their own initramfs source dir (build.ROCKNIX-*/initramfs/) — bypassing
# CONFIG_INITRAMFS_SOURCE. Editing .config alone leaves the embedded cpio intact.
#
# Real fix: empty the initramfs staging dir AND empty .config setting AND
# regenerate cpio + Image. Also flip MMC drivers to builtin so kernel can
# mount mmcblk0p2 without any initramfs.
set -euo pipefail

KSRC=/work/build.ROCKNIX-H700.aarch64/build/linux-7.0.2
INITRAMFS_DIR=/work/build.ROCKNIX-H700.aarch64/initramfs

# 1. Wipe ROCKNIX's initramfs source dir → cpio will be empty
if [ -d "$INITRAMFS_DIR" ]; then
  echo "[fix] wiping ROCKNIX initramfs staging dir"
  find "$INITRAMFS_DIR" -mindepth 1 -delete
fi

# 2. Empty kernel .config setting (belt-and-braces) + flip MMC builtin + HID userspace
cd "$KSRC"
export PATH=/work/build.ROCKNIX-H700.aarch64/toolchain/bin:$PATH
export ARCH=arm64
export CROSS_COMPILE=aarch64-rocknix-linux-gnu-

./scripts/config --file .config \
  --set-str  INITRAMFS_SOURCE "" \
  -e MMC -e MMC_BLOCK -e MMC_SUNXI \
  -e HIDRAW -m UHID -e HID_BATTERY_STRENGTH

yes "" | make olddefconfig

# 3. Force regen cpio + relink Image
rm -f usr/initramfs_data.cpio usr/initramfs_data.cpio.gz \
      usr/initramfs_data.o usr/initramfs_inc_data.o \
      arch/arm64/boot/Image
make -j"$(nproc)" Image modules dtbs

# 4. Verify the embedded cpio is gone
if grep -aob "TRAILER!!!" arch/arm64/boot/Image | head -1 | grep -q .; then
  # tiny empty cpio still has TRAILER but only ~120 bytes — any rocknix paths inside?
  if strings arch/arm64/boot/Image | grep -qE "^/storage|^/flash|rocknix-init"; then
    echo "[FAIL] kernel Image still contains ROCKNIX initramfs strings" >&2
    exit 1
  fi
  echo "[ok] only empty cpio TRAILER present (no rocknix paths)"
fi
echo "[ok] kernel Image rebuilt without ROCKNIX initramfs"
