#!/usr/bin/env bash
# Compila només DTB, sense root, amb les fonts i pedaços exactes auditats.
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
archive="$(realpath "${1:?linux-7.0.2.tar.xz}")"
rocknix="$(realpath "${2:?checkout ROCKNIX fixat}")"
out="$(realpath -m "${3:?directori nou de sortida}")"
[[ $(git -C "$rocknix" rev-parse HEAD) == "$ROCKNIX_COMMIT" ]] || { echo 'Commit ROCKNIX incorrecte'; exit 1; }
echo "53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662  $archive" | sha256sum -c -
[[ ! -e "$out" ]] || { echo 'Cal un directori nou per no reaplicar pedaços'; exit 1; }
mkdir -p "$out"
tar -xf "$archive" -C "$out"
python3 - "$rocknix" "$out" <<'PY'
import pathlib, subprocess, sys
r, out = map(pathlib.Path, sys.argv[1:])
p = r/'projects/ROCKNIX/packages/linux/patches'
patches = sorted(p.glob('*.patch'))
# Ordre de scripts/unpack per H700 en la revisió fixada.
for sub in ['mainline','H700','default','7.0']:
    patches.extend(sorted((p/sub).glob('*.patch')))
patches.extend(sorted((r/'projects/ROCKNIX/devices/H700/patches/linux').glob('*.patch')))
with (out/'patch.log').open('w') as log:
    for patch in patches:
        log.write(str(patch)+'\n'); log.flush()
        with patch.open() as source:
            subprocess.run(['patch','--batch','-p1','-d',str(out/'linux-7.0.2')], stdin=source, stdout=log, stderr=log, check=True)
print(f'{len(patches)} fitxers de pedaços aplicats')
PY
ksrc="$out/linux-7.0.2"
rsync -a "$rocknix/projects/ROCKNIX/devices/H700/linux/dts/" "$ksrc/arch/arm64/boot/dts/"
for pair in rg35xxsp:standard:rg35xx-sp rg35xxsp:v2:rg35xx-sp-v2-panel rg35xxh:standard:rg35xx-h rg35xxh:rev6:rg35xx-h-rev6-panel; do
  IFS=: read -r target panel model <<< "$pair"
  gcc -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$ksrc/include" -I "$ksrc/arch/arm64/boot/dts/allwinner" \
    "$ksrc/arch/arm64/boot/dts/allwinner/sun50i-h700-anbernic-$model.dts" -o "$out/$model.dts"
  dtc -I dts -O dtb -o "$out/$model.dtb" "$out/$model.dts" 2> "$out/$model.warnings"
  TARGET="$target" PANEL="$panel" "$ROOT/scripts/validate-dtb.sh" "$out/$model.dtb" 2>> "$out/$model.warnings"
done
(cd "$out"; sha256sum ./*.dtb > DTB.SHA256)
echo 'DTB compilats; dt-schema, kernel complet i maquinari no validats per aquesta ordre.'
