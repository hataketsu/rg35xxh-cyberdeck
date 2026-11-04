#!/usr/bin/env bash
# File-only derivative of the known minimal image; never accepts a device path.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE="$ROOT/dist/rg35xxsp-cyberdeck-standard-minimal-e807755.img"
DIAG="$ROOT/work/sp-lpddr3-diagnostic"
CHECKPOINTS=${RG_DIAG_CHECKPOINTS:-0}
variant=lpddr3-diag
case "$CHECKPOINTS" in
  0) ;;
  1) DIAG="$ROOT/work/sp-lpddr3-checkpoints"; variant=lpddr3-led ;;
  *) echo 'RG_DIAG_CHECKPOINTS must be 0 or 1'; exit 1 ;;
esac
DRAM=${RG_DIAG_DRAM:-lpddr3}
voltage=1200000
power_checkpoint=$CHECKPOINTS
description=lpddr3-stock-timings
case "$DRAM" in
  lpddr3) ;;
  lpddr4)
    [[ "$CHECKPOINTS" == 1 ]] || { echo 'LPDDR4 comparison requires checkpoints'; exit 1; }
    DIAG="$ROOT/work/sp-lpddr4-checkpoints"
    variant=lpddr4-led
    voltage=1100000
    description=lpddr4-original-profile-checkpoints
    ;;
  *) echo 'RG_DIAG_DRAM must be lpddr3 or lpddr4'; exit 1 ;;
esac
DIAG="$DIAG-gpio"
variant="$variant-gpio"
PANEL=${RG_DIAG_PANEL:-standard}
case "$PANEL" in
  standard|v2) ;;
  *) echo 'RG_DIAG_PANEL must be standard or v2'; exit 1 ;;
esac
DIST="${RG_DIAG_DIST:-$ROOT/dist}"
[[ -d "$DIST" && -f "$BASE" && ! -L "$BASE" ]] || exit 1
case "$DIST" in /dev|/dev/*) echo 'Device destinations are forbidden'; exit 1 ;; esac
[[ $(sha256sum "$BASE" | cut -d ' ' -f1) == 2067865108e50bcbaea6a904f7977e26a82070e592ec9cc5cd0821c728b53c1f ]] || { echo 'Wrong base image'; exit 1; }
UBOOT="$DIAG/u-boot-sunxi-with-spl.bin"
[[ -s "$UBOOT" && -f "$DIAG/source-revision.txt" ]] || exit 1
[[ $(cat "$DIAG/early-led-backend.txt") == direct-gpio ]] || exit 1
python3 "$ROOT/scripts/validate-spl-diagnostic.py" "$DIAG/u-boot/spl/u-boot-spl.sym"
if [[ "$CHECKPOINTS" == 1 ]]; then
  [[ $(cat "$DIAG/led-checkpoints.txt") == 1 ]] || exit 1
  # Older corrected LPDDR4 builds already had the identical power checkpoint.
  if [[ -f "$DIAG/power-checkpoint.txt" ]]; then
    [[ $(cat "$DIAG/power-checkpoint.txt") == 1 ]] || exit 1
  else
    [[ "$DRAM" == lpddr4 ]] || exit 1
  fi
fi
if [[ "$DRAM" == lpddr4 ]]; then
  [[ $(cat "$DIAG/dram-profile.txt") == lpddr4 ]] || exit 1
fi
revision="${RG_DIAG_REVISION:?Set the committed packaging revision}"
[[ "$revision" =~ ^[0-9a-f]{7,40}$ ]] || exit 1
IMG="$DIST/rg35xxsp-cyberdeck-$PANEL-minimal-$variant-$revision.img"
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
  if [[ "$DRAM" == lpddr3 ]]; then
    fdtput -t u "$DTB" "$REG" "$prop" "$voltage"
  fi
  [[ $(fdtget -tu "$DTB" "$REG" "$prop") == "$voltage" ]] || exit 1
  [[ $(fdtget -tu "$DIAG/u-boot/u-boot.dtb" "$REG" "$prop") == "$voltage" ]] || exit 1
done
if [[ "$PANEL" == v2 ]]; then
  # These are the two overrides in the pinned ROCKNIX SP v2 DTS.
  # Keep the existing boot-script filename and LPDDR3 memory rail intact.
  [[ $(fdtget -t s "$DTB" /spi/panel@0 compatible) == 'anbernic,rg35xx-plus-panel panel-mipi-dpi-spi' ]] || exit 1
  [[ $(fdtget -t s "$DTB" / rocknix-dt-id) == sun50i-h700-anbernic-rg35xx-sp ]] || exit 1
  fdtput -t s "$DTB" /spi/panel@0 compatible anbernic,rg35xx-sp-v2-panel panel-mipi-dpi-spi
  fdtput -t s "$DTB" / rocknix-dt-id sun50i-h700-anbernic-rg35xx-sp-v2-panel
  [[ $(fdtget -t s "$DTB" /spi/panel@0 compatible) == 'anbernic,rg35xx-sp-v2-panel panel-mipi-dpi-spi' ]] || exit 1
fi
uboot_hash=$(sha256sum "$UBOOT" | cut -d ' ' -f1)
cat >> "$TMP/BUILD-INFO.txt" <<INFO
DIAGNOSTIC=$description
IMAGE_SOURCE=$revision
BASE_IMAGE_SOURCE=e807755
BOOTLOADER_SOURCE=$(cat "$DIAG/source-revision.txt")
BOOTLOADER_SHA256=$uboot_hash
DRAM=${DRAM^^}
DRAM_CLK_MHZ=672
DRAM_SUPPLY_UV=$voltage
EARLY_SPL_STATUS_LED=yes
EARLY_LED_BACKEND=direct-gpio
LED_CHECKPOINTS=$CHECKPOINTS
POWER_CHECKPOINT=$power_checkpoint
PANEL=$PANEL
DTB_LOAD_NAME=sun50i-h700-anbernic-rg35xx-sp.dtb
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
