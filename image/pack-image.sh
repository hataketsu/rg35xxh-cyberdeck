#!/usr/bin/env bash
# Només crea una imatge nova regular dins de DIST. Mai rep un disc de destí.
set -euo pipefail
. "$(dirname "$0")/../scripts/load-config.sh"
[[ $EUID == 0 ]] || { echo 'Cal root (host o contenidor) per preservar propietaris del rootfs'; exit 1; }
for marker in kernel rootfs; do
  [[ -f "$WORK/$marker.target" && $(cat "$WORK/$marker.target") == "$BUILD_ID" ]] || { echo "Falta etapa $marker per $BUILD_ID"; exit 1; }
done
if [[ "$TARGET" == rg35xxsp ]]; then
  python3 "$ROOT/scripts/verify-rootfs.py" "$WORK/rootfs" "$PROFILE"
fi
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
revision="${RG_SOURCE_REVISION:-}"
if [[ -z "$revision" ]]; then
  revision=$(git -C "$ROOT" rev-parse --short HEAD)
  [[ -z $(git -C "$ROOT" status --porcelain --untracked-files=normal) ]] || revision="$revision-dirty"
fi
[[ "$revision" =~ ^[0-9a-f]+(-dirty)?$ ]] || { echo 'Revisió de font invàlida'; exit 1; }
image_mib=$((IMAGE_SIZE_GB*1024))
boot_mib=256
suffix=""
if [[ "$RG_COMPACT" == 1 ]]; then
  image_mib=960
  boot_mib=64
  suffix=-compact
fi
root_start_mib=$((16+boot_mib))
IMG="$DIST/$TARGET-cyberdeck-$PANEL-$PROFILE$suffix-$revision.img"
# noclobber rebutja també enllaços a dispositius existents.
(set -o noclobber; : > "$IMG") || { echo 'La sortida ja existeix; no se sobreescriu'; exit 1; }
[[ -f "$IMG" && ! -L "$IMG" ]] || exit 1
truncate -s "$((image_mib*1024*1024))" "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 16MiB "${root_start_mib}MiB"
parted -s "$IMG" mkpart primary ext4 "${root_start_mib}MiB" 100%
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
# Fitxers de sistema separats: no s'utilitzen loop, device-mapper ni mounts.
PACK=$(mktemp -d "$WORK/pack.XXXXXX")
MNT="$PACK/root"
P1="$PACK/boot.part"
P2="$PACK/root.part"
# En cas d'error, conservar el staging per diagnosticar; no esborra rootfs.
trap 'echo "Staging conservat a $PACK"' EXIT
mkdir -p "$MNT"
rsync -aHAX "$WORK/rootfs/" "$MNT/"
mkdir -p "$MNT/boot"
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
IMAGE_SIZE_MIB=$image_mib
BOOT_SIZE_MIB=$boot_mib
HARDWARE_VALIDATED=no
INFO
cp "$MNT/boot/BUILD-INFO.txt" "$IMG.build-info.txt"
(cd "$MNT/boot"; sha256sum Image "$DTB_NAME" boot.scr boot.cmd > BOOT.SHA256)
[[ ! -f "$MNT/opt/meshtastic/installed.txt" ]] || cp "$MNT/opt/meshtastic/installed.txt" "$IMG.python-packages.txt"
python3 - "$MNT/var/lib/dpkg/status" "$IMG.deb-packages.txt" <<'PYPACKAGES'
from pathlib import Path
import sys
packages = []
for paragraph in Path(sys.argv[1]).read_text().split('\n\n'):
    fields = dict(line.split(': ', 1) for line in paragraph.splitlines()
                  if ': ' in line and not line.startswith(' '))
    if fields.get('Status') == 'install ok installed':
        packages.append('\t'.join(fields[key] for key in ('Package', 'Version', 'Architecture')))
Path(sys.argv[2]).write_text('\n'.join(sorted(packages))+'\n')
PYPACKAGES
# Generar FAT i ext4 en fitxers nous. mke2fs -d preserva metadades del staging.
mv "$MNT/boot" "$PACK/boot"
mkdir "$MNT/boot"
truncate -s "${boot_mib}M" "$P1"
mkfs.vfat -F32 -n BOOT "$P1"
mcopy -i "$P1" "$PACK/boot/"* ::/
truncate -s "$(((image_mib-root_start_mib)*1024*1024))" "$P2"
mkfs.ext4 -F -L rootfs -d "$MNT" "$P2"
e2fsck -fn "$P2"
fsck.vfat -n "$P1"
if [[ "$RG_COMPACT" == 1 ]]; then
  python3 - "$P2" <<'PYSPACE'
import subprocess, sys
result = subprocess.run(['dumpe2fs', '-h', sys.argv[1]], check=True, capture_output=True, text=True, env={'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C'})
fields = dict(line.split(':', 1) for line in result.stdout.splitlines() if ':' in line)
available = (int(fields['Free blocks']) - int(fields['Reserved block count'])) * int(fields['Block size'])
print(f'Espai ext4 disponible per a l’usuari: {available / 2**20:.1f} MiB')
if available < 128 * 2**20:
    raise SystemExit('La imatge compacta no deixa 128 MiB lliures; no es pot utilitzar')
PYSPACE
fi
dd if="$UBOOT" of="$IMG" bs=1024 seek=8 conv=notrunc status=none
dd if="$P1" of="$IMG" bs=1M seek=16 conv=notrunc,sparse status=none
dd if="$P2" of="$IMG" bs=1M seek="$root_start_mib" conv=notrunc,sparse status=none
# Comparar el contingut incorporat: evita validar només els fitxers intermedis.
python3 - "$IMG" "$P1" "$P2" "$root_start_mib" <<'PYVERIFY'
import sys
with open(sys.argv[1], 'rb') as image:
    for filename, offset in [(sys.argv[2], 16 << 20), (sys.argv[3], int(sys.argv[4]) << 20)]:
        image.seek(offset)
        with open(filename, 'rb') as source:
            while chunk := source.read(8 << 20):
                if image.read(len(chunk)) != chunk:
                    raise SystemExit('La partició incorporada no coincideix: '+filename)
print('Contingut de les particions incorporades verificat')
PYVERIFY
python3 "$ROOT/scripts/validate-image.py" "$IMG" "$boot_mib"
bmaptool create -o "$IMG.bmap" "$IMG"
xz -T0 -6 -k "$IMG"
xz -t "$IMG.xz"
(cd "$DIST"; sha256sum "$(basename "$IMG").xz" "$(basename "$IMG").bmap" > "$(basename "$IMG").SHA256")
echo "Compilació i estructura verificades; arrencada i maquinari PENDENTS: $IMG.xz"
