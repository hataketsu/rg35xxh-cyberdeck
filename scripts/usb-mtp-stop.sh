#!/bin/bash
# usb-mtp-stop — Tear down MTP/composite gadget cleanly. Run as root.
# Order matters: kill umtprd FIRST so FFS releases, otherwise umount fails.
G=/sys/kernel/config/usb_gadget/rg35xxh
FFS=/dev/ffs-mtp

pkill -TERM umtprd 2>/dev/null
sleep 1
pkill -KILL umtprd 2>/dev/null
sleep 1

[ -d "$G" ] && echo "" > "$G/UDC" 2>/dev/null
[ -d "$G" ] && find "$G/configs/" -mindepth 2 -maxdepth 2 -type l -delete 2>/dev/null
[ -d "$G" ] && rm -f "$G/os_desc/c.1" 2>/dev/null

if mountpoint -q "$FFS"; then
    umount "$FFS" 2>/dev/null || umount -l "$FFS" 2>/dev/null
fi

if [ -d "$G" ]; then
    find "$G/" -depth -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null
    rmdir "$G" 2>/dev/null
fi

ip link set usb0 down 2>/dev/null
echo "[mtp] stopped"
exit 0
