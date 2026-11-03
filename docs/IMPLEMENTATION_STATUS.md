# Informe d'implementació — 2026-11-03

## 1. Resultat

Port de desenvolupament a `/home/frans/anbernic/rg35xxsp-cyberdeck`, branca **rg35xxsp-port**, sobre upstream `81cec5d7dfc23385cbd7c21daaef13f65817827a`. Canvis conservats en Git local; cap push ni publicació.

S'han implementat perfils explícits H/SP i variants de panell, espais de treball separats, kernel/mòduls coherents, boot.scr regenerat amb PARTUUID, empaquetat de fitxer imatge amb comprovacions i sumes, rootfs SP Debian 13 minimal/desktop, XFCE fosc amb autologin normal, controls de creueta, política de tapa conservadora, diagnòstic, venv Meshtastic i menú USB/BLE amb confirmació d'enviament. S'ha escrit tota la documentació demanada en català.

És una implementació **pendent de compilació integrada i validació física**, no un port anunciat com a funcional.

## 2. Fitxers

Inventari complet a [CHANGED_FILES.txt](evidence/CHANGED_FILES.txt). Grups principals:

- `VERSIONS`, `build.sh`, `config/targets/`: selecció de model/panell/perfil i revisió fixada.
- `patches/kernel/configure-empty-initramfs.sh`, `scripts/build-joypad-module.sh`: reconstrucció i instal·lació de mòduls.
- `rootfs/build-rg35xxsp.sh`, `overlay-rg35xxsp/`: Debian, XFCE, energia, controls, seguretat, logs i Meshtastic.
- `image/pack-image.sh`, `scripts/render-boot.sh`, `scripts/validate-{dtb.sh,image.py}`: boot i imatges.
- `scripts/{setup-wsl2,preflight,audit-dts,check-static,make-password-hash}.sh`, `tests/`: preparació i validació.
- `README-RG35XXSP.md`, `docs/`, workflow estàtic SP i ajust de cache H: documentació i comprovacions.

## 3. Estat de compilació

| Nivell | Resultat |
|---|---|
| Entorn | WSL2 confirmat; Docker accessible via grup docker; binfmt ARM64 amb flag F; espai suficient |
| Sintaxi, configuracions i tests | Completats; 8 proves passen |
| ShellCheck | Sense advertències en els scripts nous/modificats seleccionats |
| DTS/DTB | 4 variants compilades des de Linux 7.0.2 + 29 pedaços ROCKNIX; avisos heretats |
| Selecció de panell | Comprovada; el validador rebutja DTB standard quan es demana SP v2 |
| Scripts boot | SP standard/v2 generats i llegits amb mkimage |
| Meshtastic host | 2.7.11 instal·lat en venv x86_64, --help/--version i pip check correctes |
| Meshtastic ARM64 minimal | 2.7.11; --help, --version i pip check correctes sota QEMU, sense dispositius |
| Unitats systemd | verify amb systemd 257 ARM64 del rootfs mínim: codi 0 |
| Rootfs ARM64 minimal | Completat; verificació de contingut i dpkg --audit correctes |
| Kernel/U-Boot i rootfs desktop | Compilació en curs |
| Empaquetat sense dispositius | Prova FAT/ext4 real superada; permisos, propietaris i enllaços conservats |
| Imatge estructuralment validada | No; només hi ha proves del validador amb imatge sintètica |
| Arrencada al maquinari | **PENDENT** |
| Funcionalitats físiques | **TOTES PENDENTS** |

La primera execució es va aturar al preflight per Docker/sudo/binfmt. Després de preparar Docker i el grup de l'usuari, s'ha reprès la compilació amb `RG_ROOT_BACKEND=docker`. La sessió existent utilitza `sg docker -c 'ordre'`. No cal sudo al host per aquest backend. Els registres anteriors es conserven com a evidència històrica.

S'ha afegit un contenidor de rootfs amb el keyring oficial de Debian trixie i verificació obligatòria de la signatura de Release. Un primer bootstrap que havia omès la signatura s'ha descartat de la cadena de construcció i conservat com a `rootfs-unverified-bootstrap`; la construcció s'ha reiniciat amb verificació correcta. S'ha corregit també la restauració de proc/sys/pts després de debootstrap i la neteja del chroot.

L'empaquetat crea FAT/ext4 en fitxers regulars, els comprova i compara byte a byte les particions incorporades. No necessita loop devices, muntatges ni accés a discs físics. La prova independent és a [file-pack-smoke.txt](evidence/file-pack-smoke.txt). Les imatges SP passen una comprovació de contingut, arquitectura, permisos, usuari normal i serveis emmascarats abans d'empaquetar.

Les verificacions del rootfs mínim són a [rootfs-minimal-validation.txt](evidence/rootfs-minimal-validation.txt). La compilació ha trobat URLs retirades/inaccessibles de 7-Zip i configtools: s'han fixat miralls amb els mateixos SHA256, documentats a [RG35XXSP_BUILD.md](RG35XXSP_BUILD.md).

## 4. Imatge i SHA256

**Imatge `.img.xz`: no existeix. SHA256 d'imatge: no disponible.** No s'ha substituït per una imatge H ni per DTB precompilats.

Hi ha DTB parcials a `work/dts-audit/`; les seves sumes són a [DTB.SHA256](evidence/DTB.SHA256). No són sumes d'una imatge de sistema. El tar Linux utilitzat té SHA256 `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662`, comprovat contra la llista de kernel.org descarregada.

## 5. Errors i limitacions

- L'actualització global d'Ubuntu no s'ha executat des d'aquesta sessió perquè sudo continua requerint autenticació. Docker i binfmt ja permeten construir amb dependències dins dels contenidors.
- Hi ha 11 avisos dtc per variant. Alguns pedaços upstream s'apliquen amb offset/fuzz. Falta dt-schema i build complet.
- La recepta específica H700 selecciona Linux 7.0.2; la 6.15.6 genèrica no s'aplica. Es va resoldre aquesta ambigüitat abans de compilar els DTS.
- A XFCE 4.20, tapa «no fer res» és el valor **4**, no 0 (0 és DPMS). S'ha comprovat al [codi d'XFCE](https://github.com/xfce-mirror/xfce4-power-manager/blob/xfce4-power-manager-4.20.0/common/xfpm-enum-glib.h) i configurat abans de la primera sessió.
- Els rails de PMIC de la SP no s'han retocat. El problema de panell als ~30 s de la H podria requerir investigació a SP; no es pot donar per resolt.
- No hi ha detecció automàtica de panell, suspensió de tapa, redimensionament automàtic de SD ni garantia de càrrega simultània en host OTG.
- El menú Meshtastic i mapper estan provats lògicament, però falta executar-los amb evdev/USB/BLE reals.
- No hi ha reproductibilitat bit a bit: APT i dependències transitives pip varien. El rootfs H històric conserva credencials/serveis insegurs; les millores de seguretat descrites són del perfil SP.

## 6. Primer arrencament i properes accions

1. Docker, binfmt i el hash privat ja estan preparats; les instruccions per reproduir l'entorn són a [WSL2_SETUP.md](WSL2_SETUP.md). Cap canvi de Windows s'ha fet automàticament.
2. Completar la compilació `TARGET=rg35xxsp PANEL=standard PROFILE=minimal`, segons [RG35XXSP_BUILD.md](RG35XXSP_BUILD.md), i conservar també el perfil desktop separat.
3. Si la compilació i estructura passen, verificar SHA256 i gravar **manualment una microSD nova**, amb eina gràfica i confirmació del suport. Conservar intacta l'original.
4. Validar boot, panell, energia, teclat i apagada abans de passar al perfil desktop. Per un panell incompatible, provar una imatge v2 separada seguint la guia.
5. Validar USB OTG abans de connectar Heltec; consultar info/nodes sense enviar text. BLE és opcional.
6. Completar [TEST_CHECKLIST.md](TEST_CHECKLIST.md): arrencada, pantalla, retroil·luminació, XFCE, controls, teclat, Wi-Fi, Bluetooth, àudio, bateria, càrrega, tapa, USB, Heltec, Meshtastic i apagada continuen **PENDENTS**.

Guia detallada: [RG35XXSP_FIRST_BOOT.md](RG35XXSP_FIRST_BOOT.md). No s'ha escrit en cap targeta SD ni disc físic ni s'ha enviat cap missatge de ràdio.
