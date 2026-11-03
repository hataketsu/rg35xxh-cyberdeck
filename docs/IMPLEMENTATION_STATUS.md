# Informe d'implementació — 2026-11-04

## 1. Resultat

Port de desenvolupament a `/home/frans/anbernic/rg35xxsp-cyberdeck`, branca **rg35xxsp-port**, sobre upstream `81cec5d7dfc23385cbd7c21daaef13f65817827a`. Canvis conservats en Git local; cap push ni publicació.

S'han implementat perfils explícits H/SP i variants de panell, espais de treball separats, kernel/mòduls coherents, boot.scr regenerat amb PARTUUID, empaquetat de fitxer imatge amb comprovacions i sumes, rootfs SP Debian 13 minimal/desktop, XFCE fosc amb autologin normal, controls de creueta, política de tapa conservadora, diagnòstic, venv Meshtastic i menú USB/BLE amb confirmació d'enviament. S'ha escrit tota la documentació demanada en català.

Les dues imatges **SP standard minimal i desktop s'han compilat i validat estructuralment**. L'arrencada i totes les funcions físiques continuen **PENDENTS**; no és un port anunciat com a funcional al maquinari.

Actualització 2026-11-04: també s'ha generat `dist/rg35xxsp-cyberdeck-standard-minimal-compact-50f7932.img.xz`, amb una imatge descomprimida de 960 MiB i 234,5 MiB disponibles per a l'usuari. fsck FAT/ext4, comparació de particions, MBR/SPL, integritat xz i SHA256 han passat. SHA256 de l'XZ: `1135ba6988b8985996622d4d4146aa389614f9e8b9cdeb97ac8edcb0540e4ffe`; de la imatge descomprimida: `29aadcb88b1904e0a607ec04db3813e2a6e8549029ea7fddc88bfd4e1f18d484`. Registre: [empaquetat compacte](../dist/image-minimal-compact-live.log). **Gravació física, verificació per relectura i expulsió completades** el 2026-11-04 amb Raspberry Pi Imager 2.0.12, després de confirmació explícita de l'usuari. [Evidència de gravació](evidence/sd-minimal-compact-write.txt). La prova d'arrencada a la consola continua **PENDENT**.

## 2. Fitxers

Inventari complet a [CHANGED_FILES.txt](evidence/CHANGED_FILES.txt). Grups principals:

- `VERSIONS`, `build.sh`, `config/targets/`: selecció de model/panell/perfil i revisió fixada.
- `patches/kernel/configure-empty-initramfs.sh`, `scripts/build-joypad-module.sh`: reconstrucció i instal·lació de mòduls.
- `docker/rootfs.Dockerfile`, `scripts/run-root-docker.sh`, `scripts/verify-rootfs.py`, `patches/rocknix/`: backend Docker, validació i correccions de receptes/descàrregues.
- `rootfs/build-rg35xxsp.sh`, `overlay-rg35xxsp/`: Debian, XFCE, energia, controls, seguretat, logs i Meshtastic.
- `image/pack-image.sh`, `scripts/render-boot.sh`, `scripts/validate-{dtb.sh,image.py}`: boot i imatges.
- `scripts/{setup-wsl2,preflight,audit-dts,check-static,make-password-hash}.sh`, `tests/`: preparació i validació.
- `README-RG35XXSP.md`, `docs/`, workflow estàtic SP i ajust de cache H: documentació i comprovacions.

## 3. Estat de compilació

| Nivell | Resultat |
|---|---|
| Entorn | WSL2 confirmat; Docker accessible via grup docker; binfmt ARM64 amb flag F; espai suficient |
| Sintaxi, configuracions i tests | Completats; 9 proves passen (inclòs layout compacte) |
| ShellCheck | Sense advertències en els scripts nous/modificats seleccionats |
| DTS/DTB | 4 variants compilades des de Linux 7.0.2 + 29 pedaços ROCKNIX; avisos heretats |
| Selecció de panell | Comprovada; el validador rebutja DTB standard quan es demana SP v2 |
| Scripts boot | SP standard/v2 generats i llegits amb mkimage |
| Meshtastic host | 2.7.11 instal·lat en venv x86_64, --help/--version i pip check correctes |
| Meshtastic ARM64 minimal/desktop | 2.7.11; --help, --version i pip check correctes sota QEMU, sense dispositius |
| Unitats systemd | verify amb systemd 257 ARM64 dels dos rootfs: codi 0; LightDM també verificat al desktop |
| Rootfs ARM64 minimal/desktop | Completats i actualitzats; verificació de contingut i dpkg --audit correctes |
| Desktop | XFCE/LightDM i LXPolKit instal·lats; autologin normal i autoinici d'agent verificats estàticament |
| Kernel/U-Boot | Completats als dos perfils: Linux 7.0.2, U-Boot v2025.07-rc3, ATF 2.12.0, GCC 15.2.0 |
| Gamepad | Mòdul compilat contra cada kernel; vermagic verificat abans d'empaquetar |
| CPIO | 512 bytes, només `dev`, `dev/console`, `root`; cap programa init; prova negativa rebutjada |
| Empaquetat sense dispositius | Prova FAT/ext4 real superada; permisos, propietaris i enllaços conservats |
| Imatges estructuralment validades | Minimal i desktop: fsck FAT/ext4, particions comparades byte a byte, MBR/SPL, xz -t i SHA256 correctes |
| Contingut empaquetat | PARTUUID boot/fstab coherent, permisos/propietaris conservats, autologin i agent XFCE inspeccionats |
| Arrencada al maquinari | **PENDENT** |
| Funcionalitats físiques | **TOTES PENDENTS** |

La primera execució es va aturar al preflight per Docker/sudo/binfmt. Després de preparar Docker i el grup de l'usuari, s'ha reprès la compilació amb `RG_ROOT_BACKEND=docker`. La sessió existent utilitza `sg docker -c 'ordre'`. No cal sudo al host per aquest backend. Els registres anteriors es conserven com a evidència històrica.

S'ha afegit un contenidor de rootfs amb el keyring oficial de Debian trixie i verificació obligatòria de la signatura de Release. Un primer bootstrap que havia omès la signatura s'ha descartat de la cadena de construcció i conservat com a `rootfs-unverified-bootstrap`; la construcció s'ha reiniciat amb verificació correcta. S'ha corregit també la restauració de proc/sys/pts després de debootstrap i la neteja del chroot.

L'empaquetat crea FAT/ext4 en fitxers regulars, els comprova i compara byte a byte les particions incorporades. No necessita loop devices, muntatges ni accés a discs físics. La prova independent és a [file-pack-smoke.txt](evidence/file-pack-smoke.txt). Les imatges SP passen una comprovació de contingut, arquitectura, permisos, usuari normal i serveis emmascarats abans d'empaquetar.

Les verificacions són a [rootfs-minimal-validation.txt](evidence/rootfs-minimal-validation.txt) i [rootfs-desktop-validation.txt](evidence/rootfs-desktop-validation.txt). S'han corregit les descàrregues retirades/inaccessibles de 7-Zip, configtools, XMLStarlet i bdf2psf, sense canviar-ne les versions. La recepta del kernel omet l'initramfs ROCKNIX descartat, que depenia d'un commit de splash inexistent. Els detalls i sumes són a [RG35XXSP_BUILD.md](RG35XXSP_BUILD.md).

La instal·lació inicial del desktop va seleccionar UKUI com a agent Polkit. S'ha substituït per LXPolKit, habilitat per XFCE, i s'han retirat 80 dependències automàtiques sobrants (177 MB). També s'ha incorporat l'actualització de la base Debian al script i als dos rootfs: OpenSSL 3.5.7, certificats i biblioteques actualitzats, sense paquets pendents en aquella execució.

L'embolcall `build.sh` d'una execució desktop va acabar amb un error de sintaxi després que se n'edités el fitxer mentre continuava en marxa. L'etapa de rootfs ja havia finalitzat. El script actual passa `bash -n`; el rootfs s'ha refinat i verificat posteriorment en execucions independents amb codi 0. Es conserva el registre de l'error, no s'ha considerat aquell retorn com una compilació integrada reeixida.

## 4. Imatges i SHA256

Fonts de les dues imatges: commit local **`e807755`**. Les actualitzacions d'aquest informe són posteriors a la creació dels artefactes. Totes dues són per **RG35XXSP, panell standard**, amb mida descomprimida de **6 GiB**.

| Perfil | Imatge local | Mida comprimida | Sumes |
|---|---|---|---|
| Minimal, primera prova | [rg35xxsp-cyberdeck-standard-minimal-e807755.img.xz](../dist/rg35xxsp-cyberdeck-standard-minimal-e807755.img.xz) | 159.830.128 bytes (152,4 MiB) | [SHA256](../dist/rg35xxsp-cyberdeck-standard-minimal-e807755.img.SHA256) |
| Desktop XFCE | [rg35xxsp-cyberdeck-standard-desktop-e807755.img.xz](../dist/rg35xxsp-cyberdeck-standard-desktop-e807755.img.xz) | 286.882.580 bytes (273,6 MiB) | [SHA256](../dist/rg35xxsp-cyberdeck-standard-desktop-e807755.img.SHA256) |

```text
33bd7509e0214e532372c58850cff49a6b10a4bb91f1b6a436b9a2fe7bc5f273  minimal .img.xz
af14d8aa32fe8e238caf9f1dc6a7dd55d804a134fef5f040781298031c50c67e  desktop .img.xz
```

Cada imatge té també `.img.bmap`, `.img.build-info.txt`, `.img.deb-packages.txt` i `.img.python-packages.txt`. Els fitxers SHA256 inclouen la imatge comprimida i el bmap. `sha256sum -c` ha passat per als dos perfils.

Registres finals: [kernel minimal](../dist/kernel-retry5-live.log), [kernel desktop](../dist/kernel-desktop-live.log), [imatge minimal](../dist/image-minimal-live.log), [imatge desktop](../dist/image-desktop-live.log). Evidències de contingut: [minimal](evidence/image-minimal-content-validation.txt), [desktop](evidence/image-desktop-content-validation.txt), [CPIO sense init](evidence/empty-initramfs.txt). La memòria cau del kernel mínim s'ha copiat a l'espai desktop i s'ha tornat a executar l'etapa kernel, sense copiar marcadors d'èxit entre perfils.

Hi ha DTB parcials a `work/dts-audit/`; les seves sumes són a [DTB.SHA256](evidence/DTB.SHA256). No són sumes d'una imatge de sistema. El tar Linux utilitzat té SHA256 `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662`, comprovat contra la llista de kernel.org descarregada.

## 5. Errors i limitacions

- L'actualització global d'Ubuntu no s'ha executat des d'aquesta sessió perquè sudo continua requerint autenticació. Docker i binfmt ja permeten construir amb dependències dins dels contenidors.
- Hi ha 11 avisos dtc per variant a l'auditoria. Alguns pedaços upstream s'apliquen amb offset/fuzz. La compilació completa passa, però `dt-schema`/`dtbs_check` continua pendent.
- El compilador adverteix sobre el retorn de `regulator_enable` ignorat al controlador USB i prototips absents a adc-keys. Són avisos del codi heretat, conservats als registres; USB i energia requereixen proves físiques.
- Només s'han generat imatges completes SP standard. V2 i H tenen configuracions i DTB comprovats, però no imatges completes validades en aquesta sessió.
- La recepta específica H700 selecciona Linux 7.0.2; la 6.15.6 genèrica no s'aplica. Es va resoldre aquesta ambigüitat abans de compilar els DTS.
- A XFCE 4.20, tapa «no fer res» és el valor **4**, no 0 (0 és DPMS). S'ha comprovat al [codi d'XFCE](https://github.com/xfce-mirror/xfce4-power-manager/blob/xfce4-power-manager-4.20.0/common/xfpm-enum-glib.h) i configurat abans de la primera sessió.
- Els rails de PMIC de la SP no s'han retocat. El problema de panell als ~30 s de la H podria requerir investigació a SP; no es pot donar per resolt.
- No hi ha detecció automàtica de panell, suspensió de tapa, redimensionament automàtic de SD ni garantia de càrrega simultània en host OTG.
- El menú Meshtastic i mapper estan provats lògicament, però falta executar-los amb evdev/USB/BLE reals.
- No hi ha reproductibilitat bit a bit: APT i dependències transitives pip varien. El rootfs H històric conserva credencials/serveis insegurs; les millores de seguretat descrites són del perfil SP.

## 6. Primer arrencament i properes accions

1. Docker, binfmt i el hash privat ja estan preparats; les instruccions per reproduir l'entorn són a [WSL2_SETUP.md](WSL2_SETUP.md). Cap canvi de Windows s'ha fet automàticament.
2. Escollir la imatge `minimal` standard de la taula anterior per a la primera prova; conservar la desktop per a després. Per reproduir-les, seguir [RG35XXSP_BUILD.md](RG35XXSP_BUILD.md).
3. Verificar SHA256 i gravar **manualment una microSD nova**, amb eina gràfica i confirmació del suport. Conservar intacta l'original.
4. Validar boot, panell, energia, teclat i apagada abans de passar al perfil desktop. Per un panell incompatible, provar una imatge v2 separada seguint la guia.
5. Validar USB OTG abans de connectar Heltec; consultar info/nodes sense enviar text. BLE és opcional.
6. Completar [TEST_CHECKLIST.md](TEST_CHECKLIST.md): arrencada, pantalla, retroil·luminació, XFCE, controls, teclat, Wi-Fi, Bluetooth, àudio, bateria, càrrega, tapa, USB, Heltec, Meshtastic i apagada continuen **PENDENTS**.

Guia detallada: [RG35XXSP_FIRST_BOOT.md](RG35XXSP_FIRST_BOOT.md). No s'ha escrit en cap targeta SD ni disc físic ni s'ha enviat cap missatge de ràdio.
