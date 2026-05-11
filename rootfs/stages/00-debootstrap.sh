#!/usr/bin/env bash
# Stage 00: minimal Debian Trixie arm64 rootfs via debootstrap (foreign mode).
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

[ "$(id -u)" = 0 ] || { echo "must be root"; exit 1; }

mkdir -p "$ROOTFS"
debootstrap --arch=arm64 --foreign \
  --variant=minbase \
  --include=systemd,systemd-sysv,dbus,sudo,locales,ca-certificates,gnupg,iproute2,iputils-ping,curl,less,nano,bash-completion \
  "$DEBIAN_RELEASE" "$ROOTFS" "$DEBIAN_MIRROR"

# Install qemu so we can chroot
cp "$(command -v qemu-aarch64-static)" "$ROOTFS/usr/bin/" 2>/dev/null \
  || cp /usr/bin/qemu-aarch64 "$ROOTFS/usr/bin/qemu-aarch64-static"

# Second stage inside chroot
chroot "$ROOTFS" /debootstrap/debootstrap --second-stage

# Sources list
cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $DEBIAN_RELEASE main contrib non-free non-free-firmware
deb $DEBIAN_MIRROR $DEBIAN_RELEASE-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DEBIAN_RELEASE-security main contrib non-free non-free-firmware
EOF

# Hostname + hosts
echo "rg35xxh" > "$ROOTFS/etc/hostname"
cat > "$ROOTFS/etc/hosts" <<EOF
127.0.0.1   localhost rg35xxh
::1         localhost ip6-localhost ip6-loopback
EOF

# Locale + timezone
echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"
echo 'LANG="en_US.UTF-8"' > "$ROOTFS/etc/default/locale"
ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"
