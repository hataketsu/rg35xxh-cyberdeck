#!/usr/bin/env bash
# Només crea una imatge nova regular dins de DIST. Mai rep un disc de destí.
set -euo pipefail
. "$(dirname "$0")/../scripts/load-config.sh"
[[ $EUID == 0 ]] || { echo 'Cal root per muntar el fitxer imatge'; exit 1; }
for marker in kernel rootfs; do
  [[ -f "$WORK/$marker.target" && $(cat "$WORK/$marker.target") == "$BUILD_ID" ]] || { echo "Falta etapa $marker per $BUILD_ID"; exit 1; }
done
UBOOT="$WORK/rocknix/$BUILD_TREE/install_pkg/u-boot-v2025.07-rc3/usr/share/bootloader/u-boot-sunxi-with-spl.bin"
# Alguns noms de paquet conserven la v i altres no; cap selecció amb head -1.
if [[ ! -f "$UBOOT" ]]; then
  shopt -s nullglob
  candidates=("$WORK/rocknix/$BUILD_TREE/install_pkg/"u-boot-*/usr/share/bootloader/u-boot-sunxi-with-spl.bin)
  [[ ${#candidates[@]} == 1 ]] || { echo 'U-Boot absent o ambigu'; exit 1; }
  UBOOT=${candidates[0]}
fi
JOYMOD="$WORK/rocknix-joypad-build/rocknix-singleadc-joypad.ko"
KVER=$(cat "$WORK/rocknix/cyberdeck-kernelrelease")
MODS="$WORK/rocknix/cyberdeck-modules/lib/modules/$KVER"
for file in "$UBOOT" "$JOYMOD" "$KSRC/arch/arm64/boot/Image" "$KSRC/arch/arm64/boot/dts/allwinner/$DTB_NAME"; do
  [[ -s "$file" ]] || { echo "Falta $file"; exit 1; }
done
[[ -d "$MODS" ]] || { echo 'Falten els mòduls recompilats'; exit 1; }
[[ $(modinfo -F vermagic "$JOYMOD") == "$KVER "* ]] || { echo 'ABI del gamepad incorrecta'; exit 1; }
"$ROOT/scripts/validate-dtb.sh" "$KSRC/arch/arm64/boot/dts/allwinner/$DTB_NAME"
(( $(stat -c %s "$UBOOT") < 16*1024*1024-8192 )) || { echo 'U-Boot massa gran'; exit 1; }
mkdir -p "$DIST"
revision=$(git -C "$ROOT" rev-parse --short HEAD)
[[ -z $(git -C "$ROOT" status --porcelain --untracked-files=normal) ]] || revision="$revision-dirty"
IMG="$DIST/$TARGET-cyberdeck-$PANEL-$PROFILE-$revision.img"
# noclobber rebutja també enllaços a dispositius existents.
(set -o noclobber; : > "$IMG") || { echo 'La sortida ja existeix; no se sobreescriu'; exit 1; }
[[ -f "$IMG" && ! -L "$IMG" ]] || exit 1
truncate -s "$((IMAGE_SIZE_GB*1024*1024*1024))" "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 16MiB 272MiB
parted -s "$IMG" mkpart primary ext4 272MiB 100%
parted -s "$IMG" set 1 boot on
# Identificador MBR únic: el kernel resol PARTUUID sense initramfs.
diskid=$(python3 - "$IMG" <<'PY'
import secrets, struct, sys
n=secrets.randbelow(0xffffffff)+1
with open(sys.argv[1], 'r+b') as f:
    f.seek(440); f.write(struct.pack('<I', n))
print(f'{n:08x}')
PY
)
LOOP=''; MNT=''
cleanup() {
  local rc=$?
  if [[ -n "$MNT" ]]; then
    if mountpoint -q "$MNT/boot"; then umount "$MNT/boot" || rc=1; fi
    if mountpoint -q "$MNT"; then umount "$MNT" || rc=1; fi
    rmdir "$MNT" 2>/dev/null || true
  fi
  if [[ -n "$LOOP" ]]; then kpartx -d "$LOOP" || rc=1; losetup -d "$LOOP" || rc=1; fi
  exit "$rc"
}
trap cleanup EXIT
LOOP=$(losetup --find --show "$IMG")
[[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || exit 1
kpartx -a -s "$LOOP"
udevadm settle
P1="/dev/mapper/$(basename "$LOOP")p1"; P2="/dev/mapper/$(basename "$LOOP")p2"
[[ -b "$P1" && -b "$P2" ]] || { echo 'Mapeig loop incomplet'; exit 1; }
mkfs.vfat -F32 -n BOOT "$P1"
mkfs.ext4 -F -L rootfs "$P2"
dd if="$UBOOT" of="$LOOP" bs=1024 seek=8 conv=notrunc,fsync status=none
MNT=$(mktemp -d)
mount "$P2" "$MNT"
rsync -aHAX "$WORK/rootfs/" "$MNT/"
mkdir -p "$MNT/boot"
mount "$P1" "$MNT/boot"
cp "$KSRC/arch/arm64/boot/Image" "$KSRC/arch/arm64/boot/dts/allwinner/$DTB_NAME" "$MNT/boot/"
"$ROOT/scripts/render-boot.sh" "$MNT/boot" "$diskid-02"
mkdir -p "$MNT/lib/modules/$KVER" "$MNT/lib/firmware"
rsync -aHAX --chown=0:0 --exclude=build --exclude=source "$MODS/" "$MNT/lib/modules/$KVER/"
# Firmware utilitzat pel mateix kernel; ja incrustat per ROCKNIX, també disponible al rootfs.
rsync -a --chown=0:0 "$KSRC/external-firmware/" "$MNT/lib/firmware/"
install -D -m644 "$JOYMOD" "$MNT/lib/modules/$KVER/extra/rocknix-singleadc-joypad.ko"
mkdir -p "$MNT/etc/modules-load.d"
echo rocknix-singleadc-joypad > "$MNT/etc/modules-load.d/rocknix-joypad.conf"
depmod -b "$MNT" "$KVER"
# Identificadors únics als dos muntatges; no depenen de la numeració MMC.
sed -i "s|LABEL=rootfs|PARTUUID=$diskid-02|; s|LABEL=BOOT|PARTUUID=$diskid-01|" "$MNT/etc/fstab"
cat > "$MNT/boot/BUILD-INFO.txt" <<INFO
TARGET=$TARGET
PANEL=$PANEL
PROFILE=$PROFILE
SOURCE=$revision
ROCKNIX=$ROCKNIX_COMMIT
KERNEL=$KVER
DTB=$DTB_NAME
JOYPAD=$JOYPAD_COMMIT
HARDWARE_VALIDATED=no
INFO
cp "$MNT/boot/BUILD-INFO.txt" "$IMG.build-info.txt"
(cd "$MNT/boot"; sha256sum Image "$DTB_NAME" boot.scr boot.cmd > BOOT.SHA256)
[[ ! -f "$MNT/opt/meshtastic/installed.txt" ]] || cp "$MNT/opt/meshtastic/installed.txt" "$IMG.python-packages.txt"
sync
umount "$MNT/boot"
umount "$MNT"
rmdir "$MNT"; MNT=''
e2fsck -fn "$P2"
fsck.vfat -n "$P1"
kpartx -d "$LOOP"
losetup -d "$LOOP"; LOOP=''
python3 "$ROOT/scripts/validate-image.py" "$IMG"
bmaptool create -o "$IMG.bmap" "$IMG"
xz -T0 -6 -k "$IMG"
xz -t "$IMG.xz"
(cd "$DIST"; sha256sum "$(basename "$IMG").xz" "$(basename "$IMG").bmap" > "$(basename "$IMG").SHA256")
echo "Compilació i estructura verificades; arrencada i maquinari PENDENTS: $IMG.xz"
