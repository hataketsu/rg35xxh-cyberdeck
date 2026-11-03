#!/usr/bin/env bash
# Root només dins del contenidor; codi de projecte en lectura i artefactes a WORK/DIST.
set -euo pipefail
. "$(dirname "$0")/load-config.sh"
stage="${1:?rootfs|image}"
case "$stage" in rootfs|image) ;; *) exit 2 ;; esac
mkdir -p "$WORK" "$DIST"
docker build -t cyberdeck-rootfs -f "$ROOT/docker/rootfs.Dockerfile" "$ROOT/docker"
args=(--rm --user 0:0 --workdir "$ROOT"
  --mount "type=bind,source=$ROOT,target=$ROOT,readonly"
  --mount "type=bind,source=$WORK,target=$WORK"
  --mount "type=bind,source=$DIST,target=$DIST"
  -e TARGET -e PANEL -e PROFILE -e "RG_WORK=$WORK" -e "RG_DIST=$DIST")
if [[ "$stage" == rootfs ]]; then
  [[ "$TARGET" == rg35xxsp ]] || { echo 'Rootfs Docker només implementat per SP'; exit 1; }
  secret=$(realpath "${RG_PASSWORD_HASH_FILE:?Cal un fitxer privat de hash}")
  args+=(--cap-add SYS_ADMIN --security-opt apparmor=unconfined
    --mount "type=bind,source=$secret,target=/run/cyberdeck-password.hash,readonly"
    -e RG_PASSWORD_HASH_FILE=/run/cyberdeck-password.hash)
  script="$ROOT/rootfs/build-rg35xxsp.sh"
else
  # L'empaquetador només opera amb fitxers: no munta ni necessita dispositius.
  args+=(-e "RG_SOURCE_REVISION=$(git -C "$ROOT" rev-parse --short HEAD)")
  [[ -z $(git -C "$ROOT" status --porcelain) ]] || args+=(-e "RG_SOURCE_REVISION=$(git -C "$ROOT" rev-parse --short HEAD)-dirty")
  script="$ROOT/image/pack-image.sh"
fi
status=0
docker run "${args[@]}" cyberdeck-rootfs "$script" || status=$?
# Els artefactes públics han de continuar sent gestionables per l'usuari de WSL.
# No canviar la propietat del rootfs: forma part de la imatge de destí.
docker run --rm --user 0:0 --mount "type=bind,source=$DIST,target=/output" \
  cyberdeck-rootfs find /output -maxdepth 1 -type f -user root \
  -name "$TARGET-cyberdeck-*" -exec chown "$(id -u):$(id -g)" {} +
exit "$status"
