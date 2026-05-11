#!/bin/bash
# Dump boot diagnostics to /boot/logs/ so SD card can be read on PC after
# failed boot. Install at /usr/local/sbin/dump-boot-logs.sh and pair with
# templates/dump-boot-logs.service.
#
# /boot/logs/ rotates: keeps last 10 of each (boot/dmesg/journal).
set +e
LOGDIR=/boot/logs
mkdir -p "$LOGDIR"
TS=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown")
{
  echo "=== boot @ $TS ==="
  echo "=== uname -a ==="; uname -a
  echo "=== uptime ==="; uptime
  echo "=== /proc/cmdline ==="; cat /proc/cmdline
  echo "=== systemd-analyze ==="; systemd-analyze 2>&1
  echo "=== systemd-analyze blame (top 30) ==="; systemd-analyze blame 2>&1 | head -30
  echo "=== systemd-analyze critical-chain ==="; systemd-analyze critical-chain 2>&1
  echo "=== failed units ==="; systemctl --failed --no-pager 2>&1
  echo "=== ip addr ==="; ip addr 2>&1
  echo "=== lsmod ==="; lsmod 2>&1
} > "$LOGDIR/boot-$TS.txt" 2>&1

dmesg > "$LOGDIR/dmesg-$TS.txt" 2>&1
journalctl -b --no-pager > "$LOGDIR/journal-$TS.txt" 2>&1

# Rotate to last 10
for prefix in boot dmesg journal; do
  ls -1t "$LOGDIR"/${prefix}-*.txt 2>/dev/null | tail -n +11 | xargs -r rm -f
done
sync
