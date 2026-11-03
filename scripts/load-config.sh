#!/usr/bin/env bash
# Biblioteca comuna: els perfils no poden travessar directoris.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a
. "$ROOT/VERSIONS"
TARGET="${TARGET:-rg35xxh}"
PANEL="${PANEL:-standard}"
PROFILE="${PROFILE:-desktop}"
case "$TARGET" in rg35xxh|rg35xxsp) ;; *) echo 'TARGET invàlid' >&2; return 1 ;; esac
case "$PROFILE" in minimal|desktop) ;; *) echo 'PROFILE invàlid' >&2; return 1 ;; esac
if [[ "$TARGET" == rg35xxh && "$PROFILE" != desktop ]]; then
  echo "El perfil minimal només està implementat per SP" >&2; return 1
fi
RG_COMPACT="${RG_COMPACT:-0}"
case "$RG_COMPACT" in 0|1) ;; *) echo 'RG_COMPACT invàlid' >&2; return 1 ;; esac
if [[ "$RG_COMPACT" == 1 && ( "$TARGET" != rg35xxsp || "$PROFILE" != minimal ) ]]; then
  echo 'El format compacte només és per SP minimal' >&2; return 1
fi
# shellcheck disable=SC1090
. "$ROOT/config/targets/$TARGET.conf"
WORK="$(realpath -m "${RG_WORK:-$ROOT/work/$TARGET-$PANEL-$PROFILE}")"
DIST="$(realpath -m "${RG_DIST:-$ROOT/dist}")"
BUILD_TREE="build.ROCKNIX-${DEVICE}.${ARCH}"
KSRC="$WORK/rocknix/$BUILD_TREE/build/$KERNEL_NAME"
BUILD_ID="$TARGET-$PANEL-$PROFILE"
export DIST KSRC BUILD_ID
set +a
# No admetre directoris de sistema com a espai de treball.
case "$WORK" in /|/dev|/dev/*|/etc|/etc/*|/usr|/usr/*|/home|/tmp) echo 'RG_WORK insegur' >&2; return 1 ;; esac
