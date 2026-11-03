# Compilació RG35XXSP

## Requisits i estat

Completeu [WSL2_SETUP.md](WSL2_SETUP.md). En la primera sessió el preflight de compilació es va aturar per Docker, sudo i binfmt ARM64. Aquest és el resultat de la primera sessió; vegeu IMPLEMENTATION_STATUS.md per al resultat actual. Els DTB i boot.scr de prova són artefactes parcials i no una imatge utilitzable.

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
3. Compila Linux sense construir ni incorporar l'initramfs ROCKNIX i reconstrueix amb MMC/ext4 incorporats, uinput i USB sèrie; instal·la els mòduls nous.
4. Compila U-Boot/ATF i gamepad fixats. Compila explícitament els DTS de panell addicionals i valida el DTB seleccionat.
5. Crea Debian amb debootstrap/QEMU i el perfil SP. Registra les versions Python instal·lades. Tot executable privilegiat i els mòduls s'instal·len amb propietat root.
6. Genera un fitxer regular nou de 6 GiB, MBR, BOOT FAT de 256 MiB a 16 MiB i rootfs ext4. Crea les particions en fitxers amb mtools/mke2fs i les incorpora a la imatge; SPL a 8 KiB. No utilitza loop devices ni munta la imatge.
7. Regenera boot.cmd/boot.scr per variant amb root PARTUUID; verifica vermagic, sistemes de fitxers, MBR/SPL, comprimeix i calcula SHA256.

Cap paràmetre accepta una targeta SD com a destí de l'empaquetador. Les sortides existents no se sobreescriuen. En cas d'error el staging i la imatge parcial es conserven per diagnosi i no s'ha de gravar.

Sortides esperades després d'una compilació reeixida:

```text
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.xz
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.bmap
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.SHA256
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.build-info.txt
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.python-packages.txt
dist/rg35xxsp-cyberdeck-standard-minimal-<commit>.img.deb-packages.txt
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

## Construcció amb Docker també per al rootfs

`RG_ROOT_BACKEND=docker` permet construir el rootfs i empaquetar sense sudo al host. Docker ha de ser accessible (`docker info`); la pertinença al grup docker dona accés privilegiat al daemon. Després d'afegir-hi l'usuari, inicieu una nova sessió o feu servir `sg docker -c 'ordre'` en la sessió existent.

```bash
export TARGET=rg35xxsp PANEL=standard PROFILE=minimal
export RG_ROOT_BACKEND=docker
export RG_PASSWORD_HASH_FILE="$HOME/.config/rg35xxsp/cyberdeck.password.hash"
./build.sh kernel
./build.sh rootfs
./build.sh image
```

El contenidor de rootfs rep SYS_ADMIN per als bind mounts del chroot, amb AppArmor desactivat només per a aquest contenidor. No utilitza `--privileged` ni rep discos del host. El repositori està en lectura; només WORK i DIST són escrivibles i el hash és un bind mount de lectura. L'empaquetat s'executa sense SYS_ADMIN ni dispositius, escrivint fitxers regulars. Els permisos/propietaris del rootfs es conserven amb `mke2fs -d`; les particions incorporades es comparen byte a byte amb les verificades.

Les comprovacions es fan per etapa: kernel requereix Docker, però no sudo ni binfmt; rootfs requereix binfmt ARM64 i el backend escollit; image requereix les eines d'empaquetat o el contenidor. `deps` comprova el pipeline complet. El backend sudo continua disponible per defecte.

## Fonts retirades o temporalment inaccessibles

`build.sh fetch` aplica els pedaços de `patches/rocknix/` després de verificar el commit fixat. Els pedaços de descàrrega conserven les versions; els tres primers també conserven els SHA256 exigits per ROCKNIX:

- 7-Zip 25.00: la URL original retorna 404. S'utilitza l'[arxiu oficial de la mateixa versió](https://github.com/ip7z/7zip/releases/tag/25.00), SHA256 `bff9e69b6ca73a5b8715d7623870a39dc90ad6ce1f4d1070685843987af1af9b`.
- GNU configtools `28ea239c53a2d5d8800c472bc2452eaa16e37af2`: la descàrrega de Savannah falla o expira. S'utilitza el [mirall de fonts de LibreELEC](https://sources.libreelec.tv/mirror/configtools/configtools-28ea239c53a2d5d8800c472bc2452eaa16e37af2.tar.gz), SHA256 `6e4ebaa2a60114cf8b72d478b30e559f0c8e025d290ae3303773095104bf7bcc`.
- XMLStarlet 1.6.1: el domini del mirall netcologne ja no resol. S'utilitza el [distribuïdor de descàrregues de SourceForge](https://downloads.sourceforge.net/project/xmlstar/xmlstarlet/1.6.1/xmlstarlet-1.6.1.tar.gz), SHA256 `15d838c4f3375332fd95554619179b69e4ec91418a3a5296e7c631b7ed19e7ca`.
- bdf2psf 1.236: retirat del pool corrent de Debian, recuperat de [Debian Snapshot](https://snapshot.debian.org/archive/debian/20250401T143957Z/pool/main/c/console-setup/bdf2psf_1.236_all.deb). La recepta no tenia SHA256: s'hi fixa `6f8cc48290f1be5963ffd12e29d8133b3d57e9b07ee2793f5b559450c04253eb`. El SHA1 coincideix amb el registre del snapshot (`c313b2ccb9e3ad64e5ba29ad52a56dc7481af35a`). Aquest paquet només era necessari per a l'initramfs descartat.

Les còpies s'han descarregat i comparat amb el hash de la recepta. No són actualitzacions de dependències. Els registres dels intents fallits es conserven a `dist`; una nova execució de `kernel` reutilitza la memòria cau de construcció.

El commit `9d295bcb74be2282e32c6b614efbea6036974ba8` de `rocknix-splash` retorna 404. El pedaç `linux-no-initramfs.patch` omet les dependències, la instal·lació i la inclusió de l'initramfs ROCKNIX des de la primera compilació del kernel. Aquest initramfs ja s'eliminava al cyberdeck original: Debian ha de muntar directament el seu rootfs. No se substitueix el splash per una versió arbitrària. La reconstrucció posterior i la comprovació de configuració/mòduls es mantenen tant per H com per SP.

El rootfs SP actualitza també la base de debootstrap amb els repositoris trixie-updates/security. El perfil desktop selecciona explícitament LXPolKit i n'habilita l'autoinici a XFCE; evita la selecció automàtica d'UKUI i les seves dependències. L'agent continua requerint la contrasenya de l'usuari per a les operacions que ho necessitin.
