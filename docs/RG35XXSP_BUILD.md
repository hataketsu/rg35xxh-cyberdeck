# Compilació RG35XXSP

## Requisits i estat

Completeu [WSL2_SETUP.md](WSL2_SETUP.md). En aquesta sessió el preflight de compilació s'ha aturat per Docker, sudo i binfmt ARM64. No hi ha kernel complet, rootfs ni imatge generats. Els DTB i boot.scr de prova són artefactes parcials i no una imatge utilitzable.

El perfil mínim permet provar boot, consola i dispositius abans de personalitzar XFCE. El perfil desktop és Debian 13 ARM64 amb XFCE/LightDM. Cadascun té un directori propi; un rootfs existent es rebutja per conservar-lo i evitar barrejar instal·lacions.

## Contrasenya local

```bash
mkdir -p "$HOME/.config/rg35xxsp"
./scripts/make-password-hash.sh "$HOME/.config/rg35xxsp/cyberdeck.password.hash"
export RG_PASSWORD_HASH_FILE="$HOME/.config/rg35xxsp/cyberdeck.password.hash"
```

Introduïu la contrasenya interactivament al terminal. El fitxer ha de ser nou, regular i mode 600; conté només un hash SHA512-crypt. No l'afegiu a Git ni el compartiu. El port no porta cap contrasenya coneguda ni sudo sense contrasenya. `RG_PASSWORD_HASH_FILE` s'usa al rootfs, no s'inclou al registre de compilació; el hash queda a `/etc/shadow`, com en qualsevol sistema Linux.

## Compilar per etapes

```bash
export TARGET=rg35xxsp PANEL=standard PROFILE=minimal
./scripts/check-static.sh
./build.sh config
sudo -v
./build.sh deps
./build.sh fetch
./build.sh docker
./build.sh kernel
./build.sh rootfs
./build.sh image
```

O bé `./build.sh all`. Executeu el controlador com a usuari normal: eleva només rootfs i empaquetat. Pot demanar autenticació sudo al terminal. No executeu scripts a mà amb entorns inconsistents. La branca és `rg35xxsp-port`; no s'ha fet push.

Després de validar el perfil mínim a la consola:

```bash
export TARGET=rg35xxsp PANEL=standard PROFILE=desktop
./build.sh all
```

Per la variant v2, canvieu `PANEL=v2`. Per continuar desenvolupant sense tocar un rootfs existent, especifiqueu un **directori de treball nou** amb `RG_WORK=/ruta/linux/nova`. Cal reconstruir les etapes; no reutilitzeu marcadors d'una altra compilació. `RG_DIST` permet una carpeta de sortida alternativa. Canvis al codi d'un rootfs exigeixen reconstrucció en un espai nou.

## Què fa el pipeline

1. Descarrega el commit complet fixat de ROCKNIX.
2. Construeix el contenidor de compilació i les dependències addicionals.
3. Compila Linux, elimina l'initramfs ROCKNIX i recompila amb MMC/ext4 incorporats, uinput i USB sèrie; instal·la els mòduls nous.
4. Compila U-Boot/ATF i gamepad fixats. Compila explícitament els DTS de panell addicionals i valida el DTB seleccionat.
5. Crea Debian amb debootstrap/QEMU i el perfil SP. Registra les versions Python instal·lades. Tot executable privilegiat i els mòduls s'instal·len amb propietat root.
6. Genera un fitxer regular nou de 6 GiB, MBR, BOOT FAT de 256 MiB a 16 MiB i rootfs ext4. Escriu SPL a 8 KiB exclusivament dins del loop device del fitxer acabat de crear.
7. Regenera boot.cmd/boot.scr per variant amb root PARTUUID; verifica vermagic, sistemes de fitxers, MBR/SPL, comprimeix i calcula SHA256.

Cap paràmetre accepta una targeta SD com a destí de l'empaquetador. Les sortides existents no se sobreescriuen. En cas d'error es desmunten recursos, però la imatge parcial es conserva per diagnosi i no s'ha de gravar.

Sortides esperades després d'una compilació reeixida:

```text
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.xz
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.bmap
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.SHA256
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.build-info.txt
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.python-packages.txt
dist/rg35xxsp-standard-minimal-<data>-<etapa>.log
```

L'arbre brut incorpora sufix `-dirty`; feu un commit abans d'una compilació destinada a compartir. Les sumes es verifiquen des de `dist` amb `sha256sum -c <fitxer>.SHA256` i `xz -t <imatge>.img.xz`.

## Validar només DTS sense root

```bash
# Calen gcc, patch, rsync, dtc i fdtget.
./scripts/audit-dts.sh work/linux-7.0.2.tar.xz work/research-rocknix work/dts-nova-validacio
```

L'script exigeix el tar correcte i el commit fixat. No descarrega DTB precompilats. En aquesta sessió `dtc`, `fdtget` i `mkimage` provenen de paquets Ubuntu extrets a `work/host-tools/root`; per repetir aquella validació sense instal·lació global:

```bash
export PATH="$PWD/work/host-tools/root/usr/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/work/host-tools/root/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
```

Aquesta validació no compila el kernel, no executa dt-schema i no prova el maquinari. No hi ha garantia de reproducció bit a bit: APT i dependències transitives Python no estan fixats a snapshots/hashes.
