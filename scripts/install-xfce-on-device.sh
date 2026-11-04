#!/usr/bin/env bash
# Conversió explícita d'una SP mínima en execució; no toca BOOT ni la xarxa.
set -euo pipefail
export LC_ALL=C

if [[ ${1:-} != --install || $# != 1 ]]; then
  echo 'Usage: sudo bash install-xfce-on-device.sh --install'
  echo 'Run on the RG35XXSP after verifying Wi-Fi and SSH.'
  exit 2
fi
[[ $EUID == 0 ]] || { echo 'Run with sudo on the console.'; exit 1; }
[[ $(uname -m) == aarch64 ]] || { echo 'Refusing: this is not the ARM64 console.'; exit 1; }
if [[ ! -r /proc/device-tree/compatible ]]; then
  echo 'Refusing: device tree identification is unavailable.'; exit 1
fi
if ! tr '\0' '\n' < /proc/device-tree/compatible | grep -Fxq 'anbernic,rg35xx-sp'; then
  echo 'Refusing: device tree does not identify an RG35XXSP.'; exit 1
fi
# shellcheck source=/dev/null
. /etc/os-release
[[ $ID == debian && $VERSION_ID == 13 ]] || { echo 'Requires Debian 13.'; exit 1; }
id cyberdeck >/dev/null
systemctl is-active --quiet ssh.service || { echo 'Verify SSH recovery access first.'; exit 1; }
if systemctl is-active --quiet lightdm.service; then
  echo 'LightDM is already running. Inspect it before repeating installation.'
  exit 1
fi
[[ ! -e /usr/sbin/policy-rc.d && ! -L /usr/sbin/policy-rc.d ]] || {
  echo 'An existing service-start policy needs review; leaving it unchanged.'; exit 1;
}
if [[ -f /etc/X11/default-display-manager ]] &&
   [[ $(cat /etc/X11/default-display-manager) != /usr/sbin/lightdm ]]; then
  echo 'Another display manager is configured; leaving it unchanged.'
  exit 1
fi
for file in /usr/local/bin/cyberdeck-desktop /etc/xdg/autostart/cyberdeck.desktop \
  /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml \
  /etc/systemd/logind.conf.d/50-cyberdeck.conf; do
  [[ -f $file ]] || { echo "Required SP configuration missing: $file"; exit 1; }
done
available_kib=$(df -Pk / | awk 'NR==2 {print $4}')
(( available_kib >= 2*1024*1024 )) || { echo 'At least 2 GiB free on / is required.'; exit 1; }
audit=$(dpkg --audit)
[[ -z $audit ]] || { printf '%s\n' "$audit"; echo 'Resolve package errors first.'; exit 1; }

umask 022
install -d -m700 /var/lib/cyberdeck/desktop-install
exec 9>/var/lib/cyberdeck/desktop-install/lock
flock -n 9 || { echo 'Another desktop installation is running.'; exit 1; }
backup=$(mktemp -d /var/lib/cyberdeck/desktop-install/before.XXXXXX)
systemctl get-default > "$backup/default-target"
for file in /etc/lightdm/lightdm.conf.d/50-cyberdeck.conf /etc/xdg/autostart/lxpolkit.desktop; do
  if [[ -f $file ]]; then cp --parents -a "$file" "$backup/"; fi
done
policy_created=0
cleanup() {
  rc=$?
  if (( policy_created )); then rm -f /usr/sbin/policy-rc.d; fi
  if (( rc != 0 )); then
    echo 'Installation did not finish. Keep SSH open and share the error output.'
    echo 'To return the screen to console mode:'
    echo '  sudo systemctl disable --now lightdm.service'
    echo '  sudo systemctl set-default multi-user.target'
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo 'Installing XFCE and LightDM; existing SSH stays available.'
export DEBIAN_FRONTEND=noninteractive
apt-get -o APT::Update::Error-Mode=any update
# Do not start the display manager halfway through installing the desktop.
(set -o noclobber; printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d)
policy_created=1
chmod 755 /usr/sbin/policy-rc.d
# Keep the SP power-manager configuration when dpkg encounters the package copy.
apt-get -o Dpkg::Options::=--force-confold install -y --no-remove --no-install-recommends \
  lxpolkit xfce4 xfce4-terminal xfce4-power-manager xfce4-power-manager-plugins \
  lightdm lightdm-gtk-greeter xserver-xorg xserver-xorg-input-libinput \
  dbus-x11 network-manager-gnome blueman thunar gvfs pavucontrol \
  greybird-gtk-theme adwaita-icon-theme fonts-dejavu-core x11-xserver-utils

sed -i '/^NotShowIn=/s/XFCE;//' /etc/xdg/autostart/lxpolkit.desktop
install -d -m755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-cyberdeck.conf <<'LIGHTDM'
[Seat:*]
autologin-user=cyberdeck
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
allow-guest=false
LIGHTDM
chmod 644 /etc/lightdm/lightdm.conf.d/50-cyberdeck.conf
[[ -f /usr/share/xsessions/xfce.desktop && -x /usr/bin/xfce4-session ]]
[[ -x /usr/bin/lxpolkit && -x /usr/bin/Xorg ]]
lightdm --show-config > "$backup/lightdm-effective.txt"
audit=$(dpkg --audit)
[[ -z $audit ]] || { printf '%s\n' "$audit"; exit 1; }
rm -f /usr/sbin/policy-rc.d
policy_created=0

echo 'Starting the desktop on the built-in display; no reboot needed.'
systemctl daemon-reload
systemctl start lightdm.service
systemctl is-active --quiet lightdm.service
systemctl enable lightdm.service
systemctl set-default graphical.target
systemctl is-active --quiet ssh.service
echo 'LightDM started. Check the console screen for XFCE.'
echo 'Keep this SSH session open while checking the display and controls.'
echo 'If the desktop is not usable: sudo systemctl disable --now lightdm.service'
echo 'Then: sudo systemctl set-default multi-user.target'
