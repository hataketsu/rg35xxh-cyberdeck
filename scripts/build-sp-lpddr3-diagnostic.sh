#!/usr/bin/env bash
# Isolated diagnostic build. Does not write any SD or alter the normal H/SP build.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROCKNIX="$ROOT/work/rg35xxsp-standard-minimal/rocknix"
SRC="$ROCKNIX/build.ROCKNIX-H700.aarch64/build/u-boot-v2025.07-rc3"
OUT="$ROOT/work/sp-lpddr3-diagnostic"
CHECKPOINTS=${RG_DIAG_CHECKPOINTS:-0}
case "$CHECKPOINTS" in
  0) ;;
  1) OUT="$ROOT/work/sp-lpddr3-checkpoints" ;;
  *) echo 'RG_DIAG_CHECKPOINTS must be 0 or 1'; exit 1 ;;
esac
DRAM=${RG_DIAG_DRAM:-lpddr3}
case "$DRAM" in
  lpddr3) ;;
  lpddr4)
    [[ "$CHECKPOINTS" == 1 ]] || { echo 'LPDDR4 comparison requires checkpoints'; exit 1; }
    OUT="$ROOT/work/sp-lpddr4-checkpoints"
    ;;
  *) echo 'RG_DIAG_DRAM must be lpddr3 or lpddr4'; exit 1 ;;
esac
# Preserve every earlier diagnostic, including the faulty generic-LED builds.
OUT="$OUT-gpio"
[[ -f "$SRC/Makefile" && -f "$SRC/u-boot-sunxi-with-spl.bin" ]] || { echo 'Missing original pinned U-Boot build'; exit 1; }
[[ ! -e "$OUT" ]] || { echo 'Diagnostic workspace already exists; preserved for inspection'; exit 1; }
mkdir "$OUT"
cp -a "$SRC" "$OUT/u-boot"
cp "$ROOT/config/diagnostics/rg35xxsp-${DRAM}_defconfig" "$OUT/diagnostic_defconfig"
# Fix the pre-DRAM helper before adding further checkpoints.
patch --batch --fuzz=0 -d "$OUT/u-boot" -p1 < "$ROOT/patches/u-boot/h700-sp-early-led-no-bss.patch"
if [[ "$DRAM" == lpddr3 ]]; then
  patch --batch --fuzz=0 -d "$OUT/u-boot" -p1 < "$ROOT/patches/u-boot/h700-lpddr3-phy-byte.patch"
fi
if [[ "$CHECKPOINTS" == 1 ]]; then
  patch --batch --fuzz=0 -d "$OUT/u-boot" -p1 < "$ROOT/patches/u-boot/h700-sp-diagnostic-led-checkpoints.patch"
  sed -i 's/-sp-lpddr3-diag/-sp-lpddr3-led/' "$OUT/diagnostic_defconfig"
fi
if [[ "$CHECKPOINTS" == 1 ]]; then
  patch --batch --fuzz=0 -d "$OUT/u-boot" -p1 < "$ROOT/patches/u-boot/h700-sp-diagnostic-power-checkpoint.patch"
fi
sed -i -e 's/-sp-lpddr3-diag/-sp-lpddr3-gpio/' \
  -e 's/-sp-lpddr3-led/-sp-lpddr3-gpio/' \
  -e 's/-sp-lpddr4-led/-sp-lpddr4-gpio/' "$OUT/diagnostic_defconfig"
# Keep the U-Boot control DT consistent with the documented LPDDR3 rail setting.
if [[ "$DRAM" == lpddr3 ]]; then
python3 - "$OUT/u-boot/dts/upstream/src/arm64/allwinner/sun50i-h700-anbernic-rg35xx-2024.dts" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); text = p.read_text()
pattern = r'(reg_dcdc3: dcdc3\s*\{)(.*?)(\n\s*\};)'
m = re.search(pattern, text, re.S)
if not m or m.group(2).count('1100000') != 2 or 'vdd-dram' not in m.group(2):
    raise SystemExit('Unexpected DRAM regulator definition')
text = text[:m.start(2)] + m.group(2).replace('1100000', '1200000') + text[m.end(2):]
p.write_text(text)
PY
fi
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$ROCKNIX,dst=/work,readonly" \
  --mount "type=bind,src=$OUT,dst=/variant" \
  -e HOME=/tmp -e CCACHE_DISABLE=1 -w /variant/u-boot cyberdeck-builder bash -euc '
    tc=/work/build.ROCKNIX-H700.aarch64/toolchain
    export PATH="$tc/bin:$PATH"
    export ARCH=arm CROSS_COMPILE=aarch64-rocknix-linux-gnu-
    export _python_sysroot="$tc" _python_prefix=/ _python_exec_prefix=/
    make mrproper
    cp /variant/diagnostic_defconfig configs/rg35xxsp_lpddr3_diagnostic_defconfig
    make HOSTCC=gcc HOSTCFLAGS="-I$tc/include" HOSTLDFLAGS="-L$tc/lib -Wl,-rpath,$tc/lib" rg35xxsp_lpddr3_diagnostic_defconfig
    make -j8 BL31=/work/build.ROCKNIX-H700.aarch64/install_pkg/atf-2.12.0/usr/share/bootloader/bl31.bin \
      HOSTCC=gcc HOSTCFLAGS="-I$tc/include" HOSTLDFLAGS="-L$tc/lib -Wl,-rpath,$tc/lib" \
      HOSTSTRIP=true CONFIG_MKIMAGE_DTC_PATH=scripts/dtc/dtc
  '
python3 "$ROOT/scripts/validate-spl-diagnostic.py" "$OUT/u-boot/spl/u-boot-spl.sym"
python3 - "$OUT/u-boot" "$DRAM" <<'PY'
from pathlib import Path
import struct, sys
p = Path(sys.argv[1]); config = (p/'.config').read_text()
dram = sys.argv[2]
voltage, tpr11, other = ('1200', '0x0f121112', 'LPDDR4') if dram == 'lpddr3' else ('1100', '0x1b1f1e1c', 'LPDDR3')
for setting in [f'CONFIG_SUNXI_DRAM_H616_{dram.upper()}=y', f'CONFIG_AXP_DCDC3_VOLT={voltage}',
                'CONFIG_SPL_DRIVERS_MISC=y', f'CONFIG_DRAM_SUNXI_TPR11={tpr11}']:
    if setting not in config: raise SystemExit('Missing expected config: '+setting)
if f'CONFIG_SUNXI_DRAM_H616_{other}=y' in config: raise SystemExit('Wrong DRAM type')
b = bytearray((p/'u-boot-sunxi-with-spl.bin').read_bytes())
length = struct.unpack_from('<I', b, 16)[0]
expected = struct.unpack_from('<I', b, 12)[0]
if b[4:12] != b'eGON.BT0' or not 32 <= length <= 49152 or length % 4:
    raise SystemExit('Invalid SPL header or size')
struct.pack_into('<I', b, 12, 0x5f0a6c39)
if sum(struct.unpack_from('<%dI' % (length//4), b)) & 0xffffffff != expected:
    raise SystemExit('Invalid SPL checksum')
if b[max(32768,length):max(32768,length)+4] != bytes.fromhex('d00dfeed'):
    raise SystemExit('FIT missing after SPL')
print(f'{dram.upper()} diagnostic U-Boot: configuration, SPL checksum, early LED and FIT placement verified')
PY
cp "$OUT/u-boot/u-boot-sunxi-with-spl.bin" "$OUT/u-boot-sunxi-with-spl.bin"
sha256sum "$OUT/u-boot-sunxi-with-spl.bin" > "$OUT/UBOOT.SHA256"
git -C "$ROOT" rev-parse HEAD > "$OUT/source-revision.txt"
printf '%s\n' "$CHECKPOINTS" > "$OUT/led-checkpoints.txt"
printf '%s\n' "$CHECKPOINTS" > "$OUT/power-checkpoint.txt"
printf '%s\n' "$DRAM" > "$OUT/dram-profile.txt"
printf '%s\n' direct-gpio > "$OUT/early-led-backend.txt"
echo "Diagnostic bootloader ready in $OUT; hardware boot remains unverified."
