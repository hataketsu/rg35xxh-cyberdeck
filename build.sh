#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/scripts/load-config.sh"
[[ $# -le 1 ]] || { echo "Indiqueu una sola etapa per invocació" >&2; exit 1; }
STAGE="${1:-all}"
mkdir -p "$WORK" "$DIST"
log() { printf '[build %s] %s\n' "$BUILD_ID" "$*"; }
die() { echo "$*" >&2; exit 1; }
# Registre automàtic per execució, també en cas d'error.
if [[ "$STAGE" != config && "${RG_LOGGED:-0}" != 1 ]]; then
  export RG_LOGGED=1
  exec > >(tee -a "$DIST/$BUILD_ID-$(date -u +%Y%m%dT%H%M%SZ)-$STAGE.log") 2>&1
fi
run_root() { sudo env TARGET="$TARGET" PANEL="$PANEL" PROFILE="$PROFILE" RG_WORK="$WORK" RG_DIST="$DIST" RG_PASSWORD_HASH_FILE="${RG_PASSWORD_HASH_FILE:-}" "$@"; }
stage_fetch() {
  if [[ ! -d "$WORK/rocknix/.git" ]]; then git init "$WORK/rocknix"; git -C "$WORK/rocknix" remote add origin "$ROCKNIX_REPO"; fi
  git -C "$WORK/rocknix" fetch --depth=1 origin "$ROCKNIX_COMMIT"
  git -C "$WORK/rocknix" checkout --detach "$ROCKNIX_COMMIT"
  [[ $(git -C "$WORK/rocknix" rev-parse HEAD) == "$ROCKNIX_COMMIT" ]] || die 'Commit incorrecte'
  # Miralls de fonts amb la mateixa versió i SHA256; aplicació idempotent.
  local patchfile
  for patchfile in "$ROOT"/patches/rocknix/*.patch; do
    if git -C "$WORK/rocknix" apply --check "$patchfile" 2>/dev/null; then
      git -C "$WORK/rocknix" apply "$patchfile"
    else
      git -C "$WORK/rocknix" apply --reverse --check "$patchfile" || die "Pedaç no aplicable: $patchfile"
    fi
  done
}
stage_docker() {
  docker build -t rocknix-builder -f "$WORK/rocknix/tools/docker/jammy/Dockerfile" "$WORK/rocknix/tools/docker/jammy"
  docker build -t cyberdeck-builder - <<'DOCKER'
FROM rocknix-builder
USER root
RUN apt-get update && apt-get install -y wget xmlstarlet automake parted xxd python-is-python3 bc bison flex libssl-dev libelf-dev && rm -rf /var/lib/apt/lists/*
USER docker
DOCKER
}
stage_kernel() {
  # Mai deduir èxit només de l'existència d'Image: poden faltar mòduls/U-Boot.
  cp "$ROOT/patches/kernel/configure-empty-initramfs.sh" "$WORK/rocknix/configure-empty-initramfs.sh"
  docker run --rm -v "$WORK/rocknix:/work" \
    -e PROJECT=ROCKNIX -e DEVICE="$DEVICE" -e ARCH="$ARCH" -e KERNEL_NAME="$KERNEL_NAME" \
    -e CONCURRENCY_MAKE_LEVEL="$(nproc)" --user root -w /work cyberdeck-builder bash -euc '
      chown -R docker:docker /work
      su docker -s /bin/bash -c "set -euo pipefail; ./scripts/build linux; bash ./configure-empty-initramfs.sh; ./scripts/build u-boot; ./scripts/build kernel-firmware"
    '
  TARGET="$TARGET" PANEL="$PANEL" PROFILE="$PROFILE" RG_WORK="$WORK" "$ROOT/scripts/build-joypad-module.sh"
  local dtb="$KSRC/arch/arm64/boot/dts/allwinner/$DTB_NAME"
  [[ -f "$dtb" ]] || die "Falta DTB: $dtb"
  if [[ "$PATCH_REGULATORS" == 1 ]]; then python3 "$ROOT/scripts/patch-h700-dtb-regulators.py" "$dtb"; fi
  "$ROOT/scripts/validate-dtb.sh" "$dtb"
  printf '%s\n' "$BUILD_ID" > "$WORK/kernel.target"
}
stage_image() {
  if [[ "${RG_ROOT_BACKEND:-sudo}" == docker ]]; then
    "$ROOT/scripts/run-root-docker.sh" image
  else
    run_root "$ROOT/image/pack-image.sh"
  fi
}
stage_rootfs() {
  if [[ "$TARGET" == rg35xxsp ]]; then
    if [[ "${RG_ROOT_BACKEND:-sudo}" == docker ]]; then
      "$ROOT/scripts/run-root-docker.sh" rootfs
    else
      run_root "$ROOT/rootfs/build-rg35xxsp.sh"
    fi
  else
    [[ ! -e "$WORK/rootfs" ]] || die 'Ja existeix rootfs; conserveu-lo amb un altre RG_WORK abans de reconstruir.'
    for stage in 00-debootstrap 10-base-pkgs 20-xfce 30-handheld 40-network; do run_root "$ROOT/rootfs/stages/$stage.sh" "$WORK/rootfs"; done
    run_root "$ROOT/rootfs/stages/50-overlay.sh" "$WORK/rootfs" "$ROOT/overlay"
    run_root "$ROOT/rootfs/stages/99-cleanup.sh" "$WORK/rootfs"
    printf '%s\n' "$BUILD_ID" > "$WORK/rootfs.target"
  fi
}
case "$STAGE" in
  config) printf '%s\n' "TARGET=$TARGET" "PANEL=$PANEL" "PROFILE=$PROFILE" "DTB_NAME=$DTB_NAME" "WORK=$WORK" "KERNEL=$KERNEL_NAME" ;;
  deps) "$ROOT/scripts/preflight.sh" ;;
  fetch) stage_fetch ;;
  docker) "$ROOT/scripts/preflight.sh" docker; stage_fetch; stage_docker ;;
  kernel) "$ROOT/scripts/preflight.sh" kernel; stage_fetch; stage_docker; stage_kernel ;;
  rootfs) "$ROOT/scripts/preflight.sh" rootfs; stage_rootfs ;;
  image) "$ROOT/scripts/preflight.sh" image; stage_image ;;
  all) "$ROOT/scripts/preflight.sh"; stage_fetch; stage_docker; stage_kernel; stage_rootfs; stage_image ;;
  *) die 'Etapa: config|deps|fetch|docker|kernel|rootfs|image|all' ;;
esac
