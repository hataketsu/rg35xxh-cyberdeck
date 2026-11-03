#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
dtb="${1:?fitxer DTB}"
compat=$(fdtget -t s "$dtb" / compatible)
[[ " $compat " == *" $DT_COMPATIBLE "* ]] || { echo "DTB incompatible: $compat" >&2; exit 1; }
panel_compat=$(fdtget -t s "$dtb" /spi/panel@0 compatible)
[[ " $panel_compat " == *" $PANEL_COMPATIBLE "* ]] || { echo "Panell incompatible: $panel_compat" >&2; exit 1; }
dtc -I dtb -O dts "$dtb" >/dev/null
if [[ "$TARGET" == rg35xxsp ]]; then
  [[ $(fdtget -t s "$dtb" /gpio-keys-lid compatible) == gpio-keys ]]
  [[ $(fdtget -t s "$dtb" /soc/usb@5100000 dr_mode) == otg ]]
fi
echo "DTB llegible i compatible declarat correcte: $DTB_NAME (no prova el maquinari)"
