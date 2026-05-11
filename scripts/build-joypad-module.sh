#!/usr/bin/env bash
# Cross-build rocknix-singleadc-joypad.ko in the rocknix-builder container,
# matching the kernel built by stage_kernel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/VERSIONS"
WORK="${RG_WORK:-$ROOT/work}"

OUT="$WORK/rocknix-joypad-build"
mkdir -p "$OUT"

if [ ! -d "$OUT/.git" ]; then
  git clone --depth=1 https://github.com/ROCKNIX/rocknix-joypad.git "$OUT"
fi
( cd "$OUT" && git fetch --depth=1 origin 7647fdb0fc89cd69b284903bf7707e861df5dc7e && git checkout 7647fdb0fc89cd69b284903bf7707e861df5dc7e )

docker run --rm \
  -v "$WORK/rocknix:/work" -v "$OUT:/joypad" \
  --user root -w /joypad rocknix-builder bash -c "
    chown -R docker:docker /joypad /work
    su docker -c '
      export PATH=/work/build.ROCKNIX-H700.aarch64/toolchain/bin:\$PATH
      export ARCH=arm64 CROSS_COMPILE=aarch64-rocknix-linux-gnu-
      DEVICE=H700 make -C /work/build.ROCKNIX-H700.aarch64/build/${KERNEL_NAME} M=/joypad modules
    '
  "
ls -lh "$OUT"/*.ko
