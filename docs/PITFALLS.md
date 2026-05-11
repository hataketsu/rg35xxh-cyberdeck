# Pitfalls (verified May 2026)

Everything we tripped on. Read this before "why doesn't it boot."

## 1. ROCKNIX kernel ships with embedded initramfs

`Image` from upstream ROCKNIX contains a cpio archive (`CONFIG_INITRAMFS_SOURCE`) that intercepts boot, looks for `/flash`/`/storage`/`/sysroot`, and drops to busybox when it can't find them — **even if your real Debian rootfs is mounted right under it**. Symptom: `/ #` prompt, `/sbin/init: No such file or directory`, `ls /` shows ROCKNIX dirs.

Detection: `grep -aob "TRAILER!!!" Image` (cpio marker) or `strings Image | grep rocknix`.

Fix (this repo): `patches/kernel/configure-empty-initramfs.sh` empties `INITRAMFS_SOURCE` and rebuilds `Image`. Also flips `MMC*=y` so the empty-initramfs kernel can mount root by itself.

## 2. AXP717 regulator-always-on missing

H700 mainline DTS leaves 7 PMIC regulators (`aldo1/2/3`, `bldo1/3/4`, `cldo2`) as empty stubs with only a phandle. Kernel sees them as unused, auto-disables at `regulator_late_cleanup` (~31-34s uptime), kills panel/peripherals. Symptom in `dmesg`: `aldo3: disabling, vcc-pg: disabling, cldo1: disabling`.

Fix (this repo): `scripts/patch-h700-dtb-regulators.py` decompiles DTB, injects `regulator-always-on` into the 7 empty nodes, recompiles. Run automatically by `build.sh`.

## 3. console= ordering (no UART available)

Linux uses the **last** `console=` arg as `/dev/console` for init. If you put `console=ttyS0` last but the UART pads aren't soldered, `init=/bin/bash` reads from a disconnected pin — looks like a hang. Always: `console=ttyS0,115200 console=tty1` (tty1 last = screen wins).

## 4. DTB rev6-panel is wrong for retail RG35XXH

`sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb` produces 1 faint white horizontal line on retail units. Stock DTB is `sun50i-h700-anbernic-rg35xx-h.dtb`. We hard-code that name in `image/pack-image.sh`.

## 5. xfce4-battery-plugin overwrites its rc on quit

Plugin saves defaults over `~/.config/xfce4/panel/battery-NN.rc` whenever it quits → "battery critical" popup spam returns. The H700 sysfs misses `charge_full`, so plugin computes 0% energy and triggers low warning at full battery.

Fix: edit `action_on_low=0` `action_on_critical=0`, then `chattr +i` the file so plugin writes silently fail. Documented in our overlay; user can chattr -i to edit.

## 6. MUSB endpoint exhaustion

H700 has **one** OTG controller (port 1 MUSB; port 2 is host-only silicon). Trying to compose RNDIS+ECM+MTP fails with `udc musb-hdrc.5.auto: failed to start: -524 ENOTSUPP`. We use **ECM + ffs.mtp** only.

## 7. ECM gadget enumerates as NO-CARRIER

Even with just ECM, the gadget side rarely asserts carrier on MUSB. PC sees `cdc_ether` device but `nmcli` says "no carrier." Workaround pending; consider switching to NCM. Open issue.

## 8. No working VPU on H616/H700 mainline

`drivers/staging/media/sunxi/cedrus/` compiles but H616 DTSI has no `video-engine` node → module never probes. Mali bifrost renders but doesn't decode. Cortex-A53 quad @ 1.5 GHz software-decodes 480p H.264 OK, drops frames on 720p+. Use `play480` helper (auto-transcode + cache).

## 9. Debian Bookworm gcc-12 can't build kernel modules built by gcc-15.2

Native build fails: `gcc: error: unrecognized command-line option '-fmin-function-alignment=4'`. We use Trixie (gcc 14.2) as base, OR cross-build modules via `scripts/build-joypad-module.sh` in the same `rocknix-builder` container.

## 10. `mkfs.*` blocked in some agent environments

Hermes agent hardline-blocks `mkfs.ext4` even with sudo. CI runs as plain bash so this is non-issue for the build pipeline, only relevant when invoking `build.sh` interactively from a sandboxed agent.

## 11. Hermes terminal rejects `&` in `2>&1` redirects

Cosmetic for users; only relevant if you adapt this repo's scripts to be driven by Hermes agent.
