#!/usr/bin/env bash
# File-only derivative of the known minimal image; never accepts a device path.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE="$ROOT/dist/rg35xxsp-cyberdeck-standard-minimal-e807755.img"
DIAG="$ROOT/work/sp-lpddr3-diagnostic"
DIST="${RG_DIAG_DIST:-$ROOT/dist}"
[[ -d "$DIST" && -f "$BASE" && ! -L "$BASE" ]] || exit 1
case "$DIST" in /dev|/dev/*) echo 'Device destinations are forbidden'; exit 1 ;; esac
[[ $(sha256sum "$BASE" | cut -d ' ' -f1) == 2067865108e50bcbaea6a904f7977e26a82070e592ec9cc5cd0821c728b53c1f ]] || { echo 'Wrong base image'; exit 1; }
UBOOT="$DIAG/u-boot-sunxi-with-spl.bin"
[[ -s "$UBOOT" && -f "$DIAG/source-revision.txt" ]] || exit 1
revision="${RG_DIAG_REVISION:?Set the committed packaging revision}"
[[ "$revision" =~ ^[0-9a-f]{7,40}$ ]] || exit 1
IMG="$DIST/rg35xxsp-cyberdeck-standard-minimal-lpddr3-diag-$revision.img"
[[ ! -e "$IMG" && ! -L "$IMG" ]] || { echo 'Output already exists; not overwritten'; exit 1; }
cp --reflink=auto --sparse=always --no-clobber "$BASE" "$IMG"
[[ -f "$IMG" && ! -L "$IMG" ]] || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mcopy -i "$IMG@@16777216" '::/*' "$TMP/"
DTB="$TMP/sun50i-h700-anbernic-rg35xx-sp.dtb"
REG=/soc/i2c@7081400/pmic@34/regulators/dcdc3
[[ $(fdtget "$DTB" "$REG" regulator-name) == vdd-dram ]] || exit 1
for prop in regulator-min-microvolt regulator-max-microvolt; do
  [[ $(fdtget -tu "$DTB" "$REG" "$prop") == 1100000 ]] || exit 1
  fdtput -t u "$DTB" "$REG" "$prop" 1200000
  [[ $(fdtget -tu "$DTB" "$REG" "$prop") == 1200000 ]] || exit 1
  [[ $(fdtget -tu "$DIAG/u-boot/u-boot.dtb" "$REG" "$prop") == 1200000 ]] || exit 1
done
uboot_hash=$(sha256sum "$UBOOT" | cut -d ' ' -f1)
cat >> "$TMP/BUILD-INFO.txt" <<INFO
DIAGNOSTIC=lpddr3-stock-timings
IMAGE_SOURCE=$revision
BASE_IMAGE_SOURCE=e807755
BOOTLOADER_SOURCE=$(cat "$DIAG/source-revision.txt")
BOOTLOADER_SHA256=$uboot_hash
DRAM=LPDDR3
DRAM_CLK_MHZ=672
DRAM_SUPPLY_UV=1200000
EARLY_SPL_STATUS_LED=yes
BOOT_STATUS=unverified
INFO
(cd "$TMP"; sha256sum Image sun50i-h700-anbernic-rg35xx-sp.dtb boot.scr boot.cmd > BOOT.SHA256)
mcopy -o -i "$IMG@@16777216" "$DTB" "$TMP/BUILD-INFO.txt" "$TMP/BOOT.SHA256" ::/
dd if="$UBOOT" of="$IMG" bs=1024 seek=8 conv=notrunc status=none
python3 - "$BASE" "$IMG" "$UBOOT" "$TMP/boot.part" <<'PY'
from pathlib import Path
import sys
base, image, bootloader, fat = map(Path, sys.argv[1:])
with base.open('rb') as original, image.open('rb') as variant:
    if original.read(512) != variant.read(512): raise SystemExit('MBR changed')
    variant.seek(8192); binary = bootloader.read_bytes()
    if variant.read(len(binary)) != binary: raise SystemExit('Bootloader incorporation mismatch')
    variant.seek(16 << 20)
    with fat.open('xb') as out:
        for _ in range(256): out.write(variant.read(1 << 20))
    original.seek(272 << 20); variant.seek(272 << 20)
    while chunk := original.read(8 << 20):
        if variant.read(len(chunk)) != chunk: raise SystemExit('Root filesystem unexpectedly changed')
    if variant.read(1): raise SystemExit('Image size changed')
print('MBR and entire root partition unchanged; bootloader bytes match')
PY
fsck.fat -n "$TMP/boot.part"
mkdir "$TMP/check"
mcopy -i "$TMP/boot.part" '::/*' "$TMP/check/"
(cd "$TMP/check"; sha256sum -c BOOT.SHA256)
cmp "$DTB" "$TMP/check/sun50i-h700-anbernic-rg35xx-sp.dtb"
python3 "$ROOT/scripts/validate-image.py" "$IMG"
cp "$TMP/BUILD-INFO.txt" "$IMG.build-info.txt"
xz -T2 -6 -k "$IMG"
xz -t "$IMG.xz"
(cd "$DIST"; sha256sum "$(basename "$IMG")" "$(basename "$IMG").xz" > "$(basename "$IMG").SHA256")
echo "Diagnostic image ready: $IMG. No physical boot success claimed."
