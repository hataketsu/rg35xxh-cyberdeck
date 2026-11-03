#!/usr/bin/env bash
# Run inside the rocknix-builder Docker container as user `docker`.
#
# La recepta local ja omet l'initramfs ROCKNIX. Netejar també qualsevol staging
# anterior, regenerar el CPIO i verificar-ne les entrades. MMC/ext4 han de ser
# incorporats perquè el kernel pugui muntar directament el rootfs Debian.
set -euo pipefail

KSRC=/work/build.ROCKNIX-H700.aarch64/build/${KERNEL_NAME:?}
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
  -e EXT4_FS -e DEVTMPFS -e DEVTMPFS_MOUNT \
  -e HIDRAW -m UHID -e HID_BATTERY_STRENGTH -e INPUT_UINPUT \
  -e USB_ACM -e USB_SERIAL -e USB_SERIAL_CP210X -e USB_SERIAL_CH341

make olddefconfig </dev/null

# 3. Force regen cpio + relink Image
rm -f usr/initramfs_data.cpio usr/initramfs_data.cpio.gz \
      usr/initramfs_data.o usr/initramfs_inc_data.o \
      arch/arm64/boot/Image
make -j"$(nproc)" Image modules dtbs
# Els DTS addicionals no sempre són entrades del Makefile principal.
make allwinner/sun50i-h700-anbernic-rg35xx-sp-v2-panel.dtb \
     allwinner/sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb
# Instal·lar els mòduls RECOMPILATS, no els anteriors de ROCKNIX.
make INSTALL_MOD_PATH=/work/cyberdeck-modules modules_install
make -s kernelrelease > /work/cyberdeck-kernelrelease
for symbol in MMC MMC_BLOCK MMC_SUNXI EXT4_FS DEVTMPFS USB_ACM INPUT_UINPUT; do
  grep -qx "CONFIG_${symbol}=y" .config || { echo "Falta $symbol=y"; exit 1; }
done

# 4. Comprovar l'arxiu real, sense dependre de strings sobre una Image comprimida.
grep -qx 'CONFIG_INITRAMFS_SOURCE=""' .config
python3 - <<'PY'
from pathlib import Path
data = Path('usr/initramfs_data.cpio').read_bytes()
assert 0 < len(data) <= 4096, 'CPIO inesperadament gran'
offset = 0
names = []
while offset + 110 <= len(data):
    header = data[offset:offset+110]
    assert header[:6] == b'070701', 'Format CPIO inesperat'
    size, length = int(header[54:62], 16), int(header[94:102], 16)
    assert 0 < length <= 256 and size == 0, 'Contingut inesperat al CPIO'
    name = data[offset+110:offset+110+length-1].decode()
    names.append(name)
    offset = (offset+110+length+3) & ~3
    if name == 'TRAILER!!!':
        assert not any(data[offset:]), 'Dades addicionals al CPIO'
        break
assert names and names[-1] == 'TRAILER!!!', 'CPIO incomplet'
assert set(names) <= {'dev', 'dev/console', 'root', 'TRAILER!!!'}, names
print('[ok] CPIO sense programa init:', names)
PY
echo "[ok] kernel Image rebuilt without ROCKNIX initramfs"
