#!/usr/bin/env bash
# Rootfs SP aïllat; no hereta credencials ni serveis de la H.
set -euo pipefail
. "$(dirname "$0")/../scripts/load-config.sh"
[[ $EUID == 0 && "$TARGET" == rg35xxsp ]] || exit 1
ROOTFS="$WORK/rootfs"
[[ ! -e "$ROOTFS" ]] || { echo 'Rootfs existent: conserveu-lo i seleccioneu un RG_WORK nou'; exit 1; }
secret="${RG_PASSWORD_HASH_FILE:?Cal RG_PASSWORD_HASH_FILE (vegeu docs/RG35XXSP_BUILD.md)}"
[[ -f "$secret" && ! -L "$secret" ]] || { echo 'Cal un fitxer regular de hash'; exit 1; }
python3 - "$secret" <<'PY'
import pathlib, re, sys
p=pathlib.Path(sys.argv[1])
if p.stat().st_mode & 0o077:
    sys.exit('El hash ha de tenir permisos 600')
if not re.fullmatch(r'\$6\$[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}\n?', p.read_text()):
    sys.exit('Cal un hash SHA512-crypt generat amb openssl passwd -6')
PY
mkdir -p "$ROOTFS"
mounts=()
cleanup() {
  local rc=$?
  for ((i=${#mounts[@]}-1; i>=0; i--)); do
    if mountpoint -q "${mounts[i]}"; then umount "${mounts[i]}" || rc=1; fi
  done
  rm -f "$ROOTFS/tmp/password.hash"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

debootstrap --force-check-gpg --arch=arm64 --foreign --variant=minbase --include=ca-certificates,systemd,systemd-sysv,dbus,sudo,locales trixie "$ROOTFS" https://deb.debian.org/debian
install -m755 "$(command -v qemu-aarch64-static)" "$ROOTFS/usr/bin/qemu-aarch64-static"
# Impedir que apt iniciï serveis dins del chroot.
printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"
chmod 755 "$ROOTFS/usr/sbin/policy-rc.d"
for m in proc sys dev dev/pts; do
  mkdir -p "$ROOTFS/$m"
  mount --bind "/$m" "$ROOTFS/$m"
  mounts+=("$ROOTFS/$m")
done
cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
chroot "$ROOTFS" /debootstrap/debootstrap --second-stage
# debootstrap desmunta proc/sys/pts en sortir; apt necessita el chroot complet.
for m in proc sys dev dev/pts; do
  mountpoint -q "$ROOTFS/$m" || mount --bind "/$m" "$ROOTFS/$m"
done
cat > "$ROOTFS/etc/apt/sources.list" <<'APT'
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
APT
install -m600 "$secret" "$ROOTFS/tmp/password.hash"
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive PROFILE="$PROFILE" bash -euo pipefail <<'CHROOT'
apt-get update
apt-get upgrade -y
apt-get install -y --no-install-recommends locales sudo dbus dbus-user-session libpam-systemd kmod udev systemd-timesyncd \
  e2fsprogs dosfstools parted iproute2 iputils-ping curl less nano bash-completion \
  network-manager wpasupplicant wireless-regdb bluez rfkill firmware-realtek firmware-misc-nonfree \
  python3 python3-venv python3-pip python3-evdev python3-serial usbutils evtest \
  upower brightnessctl alsa-utils pulseaudio pulseaudio-utils rsync
for group in sudo video audio plugdev dialout netdev bluetooth; do groupadd -f "$group"; done
useradd -m -s /bin/bash -G sudo,video,audio,plugdev,dialout,netdev,bluetooth cyberdeck
printf 'cyberdeck:%s\n' "$(cat /tmp/password.hash)" | chpasswd -e
rm /tmp/password.hash
passwd -l root
printf 'ca_ES.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\n' > /etc/locale.gen
locale-gen
printf 'LANG=ca_ES.UTF-8\n' > /etc/default/locale
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
if [[ "$PROFILE" == desktop ]]; then
  apt-get install -y --no-install-recommends lxpolkit xfce4 xfce4-terminal xfce4-power-manager xfce4-power-manager-plugins \
    lightdm lightdm-gtk-greeter xserver-xorg xserver-xorg-input-libinput \
    dbus-x11 network-manager-gnome blueman thunar gvfs pavucontrol \
    greybird-gtk-theme adwaita-icon-theme fonts-dejavu-core x11-xserver-utils
  # Selecció explícita: evita UKUI/OpenCV/GDAL com a proveïdor de polkit-1-auth-agent.
  # Debian exclou XFCE de l'autoinici de lxpolkit perquè altres instal·lacions ja tenen un agent.
  sed -i '/^NotShowIn=/s/XFCE;//' /etc/xdg/autostart/lxpolkit.desktop
  mkdir -p /etc/lightdm/lightdm.conf.d
  printf '[Seat:*]\nautologin-user=cyberdeck\nautologin-user-timeout=0\nuser-session=xfce\n' > /etc/lightdm/lightdm.conf.d/50-cyberdeck.conf
  systemctl enable lightdm
  systemctl set-default graphical.target
else
  systemctl set-default multi-user.target
fi
systemctl enable NetworkManager bluetooth systemd-timesyncd
systemctl mask ssh.service ssh.socket suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
# No cap servei de ràdio, gadget USB, Tailscale ni redimensionament automàtic.
CHROOT
rsync -a --chown=0:0 "$ROOT/overlay-rg35xxsp/" "$ROOTFS/"
install -D -m644 "$ROOT/config/meshtastic-requirements.txt" "$ROOTFS/opt/meshtastic/requirements.txt"
chroot "$ROOTFS" bash -euo pipefail <<'CHROOT'
python3 -m venv /opt/meshtastic/venv
/opt/meshtastic/venv/bin/pip install --disable-pip-version-check -r /opt/meshtastic/requirements.txt
/opt/meshtastic/venv/bin/pip freeze > /opt/meshtastic/installed.txt
/opt/meshtastic/venv/bin/meshtastic --help >/dev/null
systemctl enable sp-gamepad.service cyberdeck-boot-logs.timer cyberdeck-power.service
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT
printf '%s\n' rg35xxsp > "$ROOTFS/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 rg35xxsp\n::1 localhost ip6-localhost ip6-loopback\n' > "$ROOTFS/etc/hosts"
cat > "$ROOTFS/etc/fstab" <<'FSTAB'
LABEL=rootfs / ext4 defaults,noatime,errors=remount-ro 0 1
LABEL=BOOT /boot vfat defaults,noatime,umask=0077 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev,size=128M 0 0
FSTAB
install -d -m2755 "$ROOTFS/var/log/journal"
rm -f "$ROOTFS/etc/machine-id" "$ROOTFS/var/lib/dbus/machine-id"
touch "$ROOTFS/etc/machine-id"
ln -s /etc/machine-id "$ROOTFS/var/lib/dbus/machine-id"
rm -f "$ROOTFS/etc/resolv.conf"
ln -s /run/NetworkManager/resolv.conf "$ROOTFS/etc/resolv.conf"
rm -f "$ROOTFS/usr/sbin/policy-rc.d" "$ROOTFS/usr/bin/qemu-aarch64-static"
python3 "$ROOT/scripts/verify-rootfs.py" "$ROOTFS" "$PROFILE"
# El marcador només es crea quan la neteja també ha acabat correctament.
for ((i=${#mounts[@]}-1; i>=0; i--)); do
  if mountpoint -q "${mounts[i]}"; then umount "${mounts[i]}"; fi
done
mounts=()
printf '%s\n' "$BUILD_ID" > "$WORK/rootfs.target"
