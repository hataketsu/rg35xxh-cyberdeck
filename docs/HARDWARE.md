# Hardware notes

## SoC: Allwinner H700

- 4× Cortex-A53 @ 1.5 GHz
- Mali-G31 (Bifrost) — renders only, no video decode
- AXP717 PMIC (USB-PD capable)
- 1 GB DDR4

## Storage

- TF1 (microSD) = `/dev/mmcblk0` — primary boot
- TF2 = `/dev/mmcblk1` — games/aux

## USB topology (CRITICAL)

| Port | Controller | Role | Notes |
|---|---|---|---|
| USB-C #1 (left) | MUSB | OTG | Used for charge + gadget mode (MTP/ECM) |
| USB-C #2 (right) | EHCI | host-only | Silicon limit, cannot be device |

## Display

- 640×480 panel, ribbon-mounted, **NOT** the rev6 variant (which has bad timings in mainline DTB)
- Backlight: `/sys/class/backlight/backlight/brightness` (max 2499)
- DTB: `sun50i-h700-anbernic-rg35xx-h.dtb`

## Audio

- Single DAC + speaker amp on GPIO PI5 (enable line, active-high)
- Headphone jack detected via gpio-keys-volume input device
- Volume buttons on the side wired to evdev (`KEY_VOLUMEUP/DOWN`)

## Joypad

- Allwinner ADC-based — driver: `rocknix-singleadc-joypad.ko` (H700 variant, single ADC mux)
- Device name: `H700 Gamepad`
- Capabilities: ABS_X/Y/RX/RY, BTN_SOUTH/EAST/NORTH/WEST, BTN_TL/TL2/TR/TR2, BTN_DPAD_*, BTN_SELECT/START, FF (rumble)

## WiFi / BT

- RTL8821CS combo (SDIO)
- WiFi firmware: included via `firmware-realtek` / `firmware-misc-nonfree`
- Aggressive default power-save → must disable (we ship `wifi-powersave-off.conf` + `wifi-watchdog.service`)

## Battery / charging

- AXP717 measures via `/sys/class/power_supply/battery/`
- Missing `charge_full` → UPower computes 0 energy. We patch xfce4-battery-plugin via chattr to silence false-low warnings (see PITFALLS).
