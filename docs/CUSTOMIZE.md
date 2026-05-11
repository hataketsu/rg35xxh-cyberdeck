# Customizing the build

## Different desktop (KDE / LXQt / i3)

Edit `rootfs/stages/20-xfce.sh`:

```bash
# Replace `xfce4 xfce4-goodies …` with e.g.
apt-get install -y --no-install-recommends \
  kde-plasma-desktop sddm
```

Also change the LightDM stanza or replace with SDDM (`systemctl enable sddm`).

## Add packages

Drop them into `rootfs/stages/10-base-pkgs.sh` (`apt-get install` line). Re-run with `RG_FORCE_ROOTFS=1 ./build.sh rootfs image`.

## Pre-install your dotfiles

Put them under `overlay/home/<user>/...` and `chown` in `rootfs/stages/50-overlay.sh`.

## Change default user / password

Edit `VERSIONS` (`TARGET_USER`) and `rootfs/stages/20-xfce.sh` (`chpasswd` line). Don't ship a default password publicly — encourage first-boot change.

## Rev6 panel variant

If your retail unit has the rev6 panel (1 horizontal sosck-strip on stock DTB), edit `VERSIONS`:

```
DTB_NAME=sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb
```

and rebuild. Not yet automated for both panels in one image.

## Different ROCKNIX commit

Bump `ROCKNIX_COMMIT` in `VERSIONS`. CI will rebuild from scratch (no cache hit).
