#!/usr/bin/env bash
# Compose final SD image: GPT, u-boot SPL @ 8KB, FAT boot p1, ext4 rootfs p2.
set -euo pipefail
WORK="$1"
DIST="$2"
. "$(dirname "$0")/../VERSIONS"

[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

IMG="$DIST/rg35xxh-cyberdeck-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d).img"
SIZE_BYTES=$(( IMAGE_SIZE_GB * 1024 * 1024 * 1024 ))

echo "[pack] creating $IMG (${IMAGE_SIZE_GB} GB)"
rm -f "$IMG"
truncate -s "$SIZE_BYTES" "$IMG"

# GPT: u-boot in gap 8KB..16MB, p1 FAT (256MB), p2 ext4 rest
parted -s "$IMG" mklabel gpt
parted -s "$IMG" mkpart BOOT   fat32 16MiB 272MiB
parted -s "$IMG" mkpart rootfs ext4  272MiB 100%

LOOP=$(losetup --find --show -P "$IMG")
trap 'losetup -d "$LOOP" 2>/dev/null || true' EXIT
partprobe "$LOOP" 2>/dev/null || true
udevadm settle
for i in 1 2 3 4 5; do
  [ -b "${LOOP}p2" ] && break
  sleep 1
  partprobe "$LOOP" 2>/dev/null || true
  udevadm settle
done
[ -b "${LOOP}p2" ] || { echo "loop partitions did not appear"; ls -la /dev/loop*; exit 1; }

# Format
mkfs.vfat -F 32 -n BOOT   "${LOOP}p1"
mkfs.ext4 -F   -L rootfs "${LOOP}p2"

# Install u-boot SPL @ 8KB
UBOOT="$WORK/rocknix/build.ROCKNIX-${DEVICE}.${ARCH}/install_pkg/u-boot-"*"/usr/share/bootloader/u-boot-sunxi-with-spl.bin"
UBOOT=$(ls -1 $UBOOT | head -1)
dd if="$UBOOT" of="$LOOP" bs=1024 seek=8 conv=notrunc

# Mount and populate
MNT=$(mktemp -d)
mount "${LOOP}p2" "$MNT"
mkdir -p "$MNT/boot"
mount "${LOOP}p1" "$MNT/boot"

# Copy kernel + DTB + boot.scr
KSRC="$WORK/rocknix/build.ROCKNIX-${DEVICE}.${ARCH}/build/${KERNEL_NAME}"
cp "$KSRC/arch/arm64/boot/Image" "$MNT/boot/"
cp "$KSRC/arch/arm64/boot/dts/allwinner/${DTB_NAME}" "$MNT/boot/"
cp "$(dirname "$0")/../patches/uboot/boot.scr" "$MNT/boot/"
cp "$(dirname "$0")/../patches/uboot/boot.cmd" "$MNT/boot/"

# Rootfs
rsync -aHAX "$WORK/rootfs/" "$MNT/" --exclude=/boot/\*

# Modules
MODS="$WORK/rocknix/build.ROCKNIX-${DEVICE}.${ARCH}/install_pkg/${KERNEL_NAME}/usr/lib/kernel-overlays/base/lib/modules"
[ -d "$MODS" ] && rsync -aHAX "$MODS/" "$MNT/lib/modules/"

# Joypad module (built separately)
JOYMOD="$WORK/rocknix-joypad-build/rocknix-singleadc-joypad.ko"
if [ -f "$JOYMOD" ]; then
  KVER=$(ls "$MNT/lib/modules/" | head -1)
  install -d "$MNT/lib/modules/$KVER/extra"
  cp "$JOYMOD" "$MNT/lib/modules/$KVER/extra/"
  chroot "$MNT" depmod -a "$KVER"
  echo rocknix-singleadc-joypad > "$MNT/etc/modules-load.d/rocknix-joypad.conf"
fi

sync
umount "$MNT/boot"
umount "$MNT"
rmdir "$MNT"
losetup -d "$LOOP"; trap - EXIT

# Bmap + xz
echo "[pack] creating bmap"
bmaptool create -o "$IMG.bmap" "$IMG"

echo "[pack] compressing → ${IMG}.xz"
xz -T 0 -6 -k "$IMG"
ls -lh "$IMG"* 
