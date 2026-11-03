#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
out="${1:?directori de sortida}"
partuuid="${2:?PARTUUID arrel}"
[[ "$partuuid" =~ ^[0-9a-fA-F]{8}-02$ ]] || { echo 'PARTUUID invàlid' >&2; exit 1; }
mkdir -p "$out"
cat > "$out/boot.cmd" <<BOOT
# Generat per a $BUILD_ID; DTB compilat amb el mateix kernel.
setenv bootargs "root=PARTUUID=$partuuid rw rootwait console=ttyS0,115200 console=tty1 loglevel=4"
if fatload mmc 0:1 0x44000000 Image; then
  if fatload mmc 0:1 0x4FA00000 $DTB_NAME; then
    booti 0x44000000 - 0x4FA00000
  fi
fi
echo "ERROR: no s'ha pogut carregar Image o $DTB_NAME"
BOOT
mkimage -A arm64 -O linux -T script -C none -n "$TARGET-cyberdeck" -d "$out/boot.cmd" "$out/boot.scr"
