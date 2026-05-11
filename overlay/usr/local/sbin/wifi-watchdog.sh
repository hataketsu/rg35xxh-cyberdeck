#!/bin/bash
# wifi-watchdog — ping gateway every 30s, reconnect WiFi after 3 fails
set -u

GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$GATEWAY" ] && GATEWAY=8.8.8.8

fail=0
while true; do
    if ping -c 1 -W 3 "$GATEWAY" >/dev/null 2>&1; then
        fail=0
    else
        fail=$((fail+1))
        logger -t wifi-watchdog "ping $GATEWAY fail #$fail"
        if [ "$fail" -ge 3 ]; then
            logger -t wifi-watchdog "reconnecting $IFACE"
            CONN=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v d="$IFACE" '$2==d{print $1; exit}')
            if [ -n "$CONN" ]; then
                nmcli con down "$CONN" >/dev/null 2>&1 || true
                sleep 2
                nmcli con up "$CONN" >/dev/null 2>&1 || true
            else
                nmcli dev disconnect "$IFACE" >/dev/null 2>&1 || true
                sleep 2
                nmcli dev connect "$IFACE" >/dev/null 2>&1 || true
            fi
            fail=0
            sleep 15
        fi
    fi
    sleep 30
done
