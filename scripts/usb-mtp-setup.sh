#!/bin/bash
# usb-mtp-setup — Setup MTP gadget (uMTP-Responder + FunctionFS) on H700 OTG
# Optional: also link ECM for ethernet (currently NO-CARRIER, see references/usb-gadget-composite.md)
#
# Run as root. Idempotent (tears down old gadget first).
set -e

G=/sys/kernel/config/usb_gadget/rg35xxh
FFS=/dev/ffs-mtp
WITH_ETH="${WITH_ETH:-0}"   # set WITH_ETH=1 to also include ECM

# --- teardown previous ---
if [ -d "$G" ]; then
    echo "" > "$G/UDC" 2>/dev/null || true
    find "$G/configs/" -mindepth 2 -maxdepth 2 -type l -delete 2>/dev/null || true
    rm -f "$G/os_desc/c.1" 2>/dev/null || true
    find "$G/" -depth -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null || true
    rmdir "$G" 2>/dev/null || true
fi
mountpoint -q "$FFS" && umount "$FFS"
pkill -9 umtprd 2>/dev/null || true
sleep 1

# --- gadget skeleton ---
mkdir -p "$G"
echo 0x1d6b > "$G/idVendor"
echo 0x0104 > "$G/idProduct"
echo 0x0100 > "$G/bcdDevice"
echo 0x0200 > "$G/bcdUSB"
[ "$WITH_ETH" = "1" ] && {
    echo 0xEF > "$G/bDeviceClass"
    echo 0x02 > "$G/bDeviceSubClass"
    echo 0x01 > "$G/bDeviceProtocol"
}

mkdir -p "$G/strings/0x409"
echo "rg35xxh-mtp" > "$G/strings/0x409/serialnumber"
echo "Anbernic"    > "$G/strings/0x409/manufacturer"
echo "RG35XXH"     > "$G/strings/0x409/product"

mkdir -p "$G/configs/c.1/strings/0x409"
echo "MTP" > "$G/configs/c.1/strings/0x409/configuration"
echo 250   > "$G/configs/c.1/MaxPower"

# --- functions ---
mkdir -p "$G/functions/ffs.mtp"
[ "$WITH_ETH" = "1" ] && mkdir -p "$G/functions/ecm.usb0"

# --- mount FFS, start umtprd, wait for endpoints ---
mkdir -p "$FFS"
mount -t functionfs mtp "$FFS"
nohup /usr/local/bin/umtprd -conf /etc/umtprd/umtprd.conf > /var/log/umtprd.log 2>&1 &
echo $! > /run/umtprd.pid
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -e "$FFS/ep1" ] && break
    sleep 0.5
done

# --- link functions, bind UDC ---
[ "$WITH_ETH" = "1" ] && ln -sf "$G/functions/ecm.usb0" "$G/configs/c.1/ecm.usb0"
ln -sf "$G/functions/ffs.mtp" "$G/configs/c.1/ffs.mtp"
UDC=$(ls /sys/class/udc/ | head -1)
echo "$UDC" > "$G/UDC"

# --- bring up usb0 with static IP if ethernet enabled ---
if [ "$WITH_ETH" = "1" ]; then
    sleep 1
    ip addr flush dev usb0 2>/dev/null || true
    ip addr add 10.42.0.1/24 dev usb0
    ip link set usb0 up
fi

echo "[mtp] gadget bound to $UDC, ep1=$([ -e $FFS/ep1 ] && echo ready || echo MISSING)"
