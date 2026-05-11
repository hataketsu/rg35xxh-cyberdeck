#!/usr/bin/env bash
# rg35xxh-cyberdeck build orchestrator.
# Idempotent stages. Re-runs only what's missing in work/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${RG_WORK:-$ROOT/work}"
DIST="${RG_DIST:-$ROOT/dist}"
STAGE="${1:-all}"

# shellcheck disable=SC1091
set -a; . "$ROOT/VERSIONS"; set +a

mkdir -p "$WORK" "$DIST"

log()  { printf "\033[1;36m[build]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[fail]\033[0m %s\n" "$*" >&2; exit 1; }

check_deps() {
  for c in docker debootstrap kpartx parted xz bmaptool qemu-aarch64-static dtc; do
    command -v "$c" >/dev/null 2>&1 || die "missing dependency: $c (apt install docker.io debootstrap qemu-user-static kpartx parted xz-utils bmap-tools device-tree-compiler)"
  done
}

stage_fetch() {
  log "stage: fetch ROCKNIX @$ROCKNIX_COMMIT"
  if [ ! -d "$WORK/rocknix/.git" ]; then
    git clone "$ROCKNIX_REPO" "$WORK/rocknix"
  fi
  ( cd "$WORK/rocknix" && git fetch && git checkout "$ROCKNIX_COMMIT" )
}

stage_docker() {
  log "stage: build rocknix-builder docker image"
  docker image inspect rocknix-builder >/dev/null 2>&1 && return 0
  ( cd "$WORK/rocknix" && \
    docker build -t rocknix-builder -f tools/docker/jammy/Dockerfile tools/docker/jammy/ )
  # Install extra build deps and commit them into the image (otherwise --rm discards them)
  local cid
  cid="$(docker create --user root rocknix-builder \
    bash -c "apt-get update -qq && apt-get install -y -qq wget xmlstarlet automake parted xxd python-is-python3")"
  docker start -a "$cid"
  docker commit "$cid" rocknix-builder >/dev/null
  docker rm "$cid" >/dev/null
}

stage_kernel() {
  log "stage: build kernel + u-boot (this is the long one, ~30-45min)"
  local out="$WORK/rocknix/build.ROCKNIX-${DEVICE}.${ARCH}/build/${KERNEL_NAME}/arch/arm64/boot/Image"
  if [ -f "$out" ] && [ "${RG_FORCE_KERNEL:-0}" != "1" ]; then
    log "kernel Image present, skipping (RG_FORCE_KERNEL=1 to override)"
    return 0
  fi

  # Apply our kernel patches (disable INITRAMFS_SOURCE, etc.) via a wrapper
  cp "$ROOT/patches/kernel/configure-empty-initramfs.sh" "$WORK/rocknix/configure-empty-initramfs.sh"

  docker run --rm \
    -v "$WORK/rocknix:/work" \
    -e PROJECT=ROCKNIX -e DEVICE=$DEVICE -e ARCH=$ARCH \
    -e CONCURRENCY_MAKE_LEVEL=$(nproc) -e MAKEFLAGS="-j$(nproc)" \
    --user root -w /work rocknix-builder bash -c "
      chown -R docker:docker /work && su docker -c '
        export PROJECT=ROCKNIX DEVICE=$DEVICE ARCH=$ARCH
        export CONCURRENCY_MAKE_LEVEL=$(nproc) MAKEFLAGS=-j$(nproc)
        ./scripts/build linux 2>&1
        # disable embedded initramfs + flip MMC to builtin, then rebuild Image
        bash /work/configure-empty-initramfs.sh
        ./scripts/build u-boot 2>&1
      '
    "
}

stage_dtb_patch() {
  log "stage: patch DTB (AXP717 regulator-always-on)"
  local dtb="$WORK/rocknix/build.ROCKNIX-${DEVICE}.${ARCH}/build/${KERNEL_NAME}/arch/arm64/boot/dts/allwinner/${DTB_NAME}"
  [ -f "$dtb" ] || die "DTB not found: $dtb"
  python3 "$ROOT/scripts/patch-h700-dtb-regulators.py" "$dtb"
}

stage_rootfs() {
  log "stage: build Debian Trixie rootfs"
  local rootfs="$WORK/rootfs"
  if [ -d "$rootfs/etc/debian_version" ] && [ "${RG_FORCE_ROOTFS:-0}" != "1" ]; then
    log "rootfs present, skipping (RG_FORCE_ROOTFS=1 to override)"
    return 0
  fi
  sudo rm -rf "$rootfs"
  sudo "$ROOT/rootfs/stages/00-debootstrap.sh"  "$rootfs"
  sudo "$ROOT/rootfs/stages/10-base-pkgs.sh"    "$rootfs"
  sudo "$ROOT/rootfs/stages/20-xfce.sh"         "$rootfs"
  sudo "$ROOT/rootfs/stages/30-handheld.sh"     "$rootfs"
  sudo "$ROOT/rootfs/stages/40-network.sh"      "$rootfs"
  sudo "$ROOT/rootfs/stages/50-overlay.sh"      "$rootfs" "$ROOT/overlay"
  sudo "$ROOT/rootfs/stages/99-cleanup.sh"      "$rootfs"
}

stage_image() {
  log "stage: pack final image"
  sudo "$ROOT/image/pack-image.sh" "$WORK" "$DIST"
  log "→ done. artifacts in $DIST/"
  ls -lh "$DIST"
}

case "$STAGE" in
  deps)   check_deps ;;
  fetch)  check_deps; stage_fetch ;;
  docker) check_deps; stage_fetch; stage_docker ;;
  kernel) check_deps; stage_fetch; stage_docker; stage_kernel; stage_dtb_patch ;;
  rootfs) check_deps; stage_rootfs ;;
  image)  check_deps; stage_image ;;
  all)
    check_deps
    stage_fetch
    stage_docker
    stage_kernel
    stage_dtb_patch
    stage_rootfs
    stage_image
    ;;
  *) die "unknown stage: $STAGE (try: all|fetch|docker|kernel|rootfs|image)" ;;
esac
