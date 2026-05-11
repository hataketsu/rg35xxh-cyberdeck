# RG35XXH Cyberdeck

Turn an [Anbernic RG35XXH](https://anbernic.com/) (Allwinner H700) handheld into a portable Debian Trixie cyberdeck — full XFCE desktop, working WiFi/Bluetooth, joystick-as-mouse, USB-OTG MTP file share, Tailscale, audio, brightness keys, battery widget.

**Status:** alpha. Builds reproducibly via CI. PRs welcome.

![](docs/screenshot.jpg)

## What you get

- **Debian 13 Trixie** arm64 rootfs (apt, systemd 257, gcc 14)
- **ROCKNIX kernel 7.0.2** (mainline 6.15.6 + Allwinner patches) — rebuilt without embedded initramfs so it actually boots a normal Debian
- **DTB regulator fix** — adds `regulator-always-on` to 7 AXP717 rails so kernel doesn't auto-disable the panel at ~31s
- **XFCE 4.20** w/ LightDM autologin to non-root user
- **joy2mouse** — left analog stick → cursor, A/B/Y → click, D-pad → arrows, R-stick → scroll, Select → Alt+F4, Start → Super, X → Enter, L2 → Backspace, R2 → Tab
- **Audio** — speaker + volume keys via PulseAudio
- **Bluetooth keyboards** — HIDRAW/UHID built into kernel (BLE HOG works)
- **WiFi watchdog** — recovers from RTL8821CS "ghost connected" state
- **USB OTG** — port 1 = MTP (umtprd) + ECM ethernet to PC
- **mpv + play480** helper — auto-transcode 1080p → 480p (no working VPU on H700)

## Quick start (use prebuilt)

1. Grab the latest image from [Releases](../../releases) → `rg35xxh-cyberdeck-vX.Y.Z.img.xz` + `.img.bmap`
2. Flash to a 16 GB+ SD card (UHS-I or better):
   ```bash
   xz -d rg35xxh-cyberdeck-*.img.xz
   sudo bmaptool copy rg35xxh-cyberdeck-*.img /dev/sdX
   ```
3. Insert into the **TF1** slot of the RG35XXH, power on, wait ~2 min for first boot.
4. Default credentials: `hataketsu` / `kamikaze` (sudo passwordless). Change immediately.
5. Connect WiFi via panel applet, then optionally `sudo tailscale up` for remote SSH.

## Build it yourself (reproducible)

Requires Linux host with:
- Docker
- `debootstrap`, `qemu-user-static`, `kpartx`, `bmap-tools`, `parted`, `xz-utils`
- ~20 GB free disk
- ~2 hr (24-core box) — kernel build dominates

```bash
git clone https://github.com/hataketsu/rg35xxh-cyberdeck.git
cd rg35xxh-cyberdeck
./build.sh
# → dist/rg35xxh-cyberdeck-<commit>.img.xz
```

CI builds every push and attaches artifacts to a draft release on tags.

## Repository layout

```
build.sh              Top-level orchestrator (idempotent stages)
VERSIONS              Pinned ROCKNIX commit, Debian release, kernel
docker/Dockerfile     Builder image (jammy + extra build deps)
patches/
  kernel/             *.patch applied via `git am` before kernel build
  dtb/                Python patcher for AXP717 regulator-always-on
  uboot/              boot.cmd + boot.scr
rootfs/stages/        00-debootstrap → 99-cleanup, run inside chroot
overlay/              Copied verbatim into rootfs (scripts, systemd units, configs)
image/pack-image.sh   Composes final .img (GPT, u-boot SPL @ 8KB, FAT boot, ext4 rootfs)
scripts/              Standalone helpers (DTB patcher, USB gadget)
docs/                 Architecture, build internals, pitfalls, hardware
.github/workflows/    CI: build on PR, release on tag
```

## Documentation

- [docs/BUILD.md](docs/BUILD.md) — what each stage does + how to iterate fast
- [docs/PITFALLS.md](docs/PITFALLS.md) — every trap we hit (embedded initramfs, regulator auto-disable, MUSB endpoint exhaustion, etc.) and why
- [docs/HARDWARE.md](docs/HARDWARE.md) — H700 SoC notes, GPIO map, USB topology
- [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) — swap XFCE for KDE/i3, add packages, change user

## Hardware coverage

| Feature | Status | Notes |
|---|---|---|
| Display 640×480 | ✅ | sun50i-h700-anbernic-rg35xx-h.dtb (NOT rev6-panel) |
| WiFi (RTL8821CS) | ✅ | with watchdog + powersave off |
| Bluetooth | ✅ | BLE HOG keyboards work (UHID built-in) |
| Joystick → mouse | ✅ | left stick cursor + scroll on R stick |
| Audio out | ✅ | PulseAudio, vol keys bound |
| Brightness | ✅ | XF86 keys via xfpm |
| Battery widget | ✅ | xfce4-battery-plugin w/ false-low fix |
| USB OTG MTP | ✅ | umtprd on port 1 |
| USB Ethernet (ECM) | ⚠️ | enumerates but NO-CARRIER on MUSB; open issue |
| Video decode | ❌ | No VPU on mainline H700 — use `play480` helper |

## Hardware tested

- RG35XXH (rev unknown; standard panel — NOT rev6)

If you have a rev6 panel unit, see [docs/HARDWARE.md](docs/HARDWARE.md) for the alt DTB build.

## Credits

- [ROCKNIX](https://github.com/ROCKNIX/distribution) — kernel + u-boot + toolchain
- [tokyovigilante](https://git.sr.ht/~tokyovigilante/linux) — H700 mainline patches
- [umtprd](https://github.com/viveris/uMTP-Responder) — MTP responder
- Reddit `r/RG35XX_H` community

## License

GPL-2.0 — see [LICENSE](LICENSE). Kernel patches inherit kernel license; u-boot patches inherit u-boot license.
