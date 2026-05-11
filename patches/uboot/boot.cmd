# boot.cmd for RG35XXH (Allwinner H700)
# Compile: mkimage -A arm64 -O linux -T script -C none -n "rg35xxh-cyberdeck" -d boot.cmd boot.scr
#
# Verbose log on tty1 (no UART on RG35XXH retail) + systemd debug to console.
# console=ttyS0 FIRST, console=tty1 LAST → /dev/console = screen.

setenv bootargs "root=/dev/mmcblk0p2 rw rootwait \
  console=ttyS0,115200 console=tty1 \
  loglevel=8 ignore_loglevel \
  systemd.log_target=kmsg systemd.log_level=debug \
  systemd.journald.forward_to_console=1 printk.devkmsg=on"

fatload mmc 0:1 0x44000000 Image
fatload mmc 0:1 0x4FA00000 sun50i-h700-anbernic-rg35xx-h.dtb
booti 0x44000000 - 0x4FA00000
