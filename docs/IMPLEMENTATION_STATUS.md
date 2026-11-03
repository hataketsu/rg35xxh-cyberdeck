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
| Entorn | WSL2 confirmat; espai suficient |
| Sintaxi, configuracions i tests | Completats; 7 proves passen |
| ShellCheck | Sense advertències en els scripts nous/modificats seleccionats |
| DTS/DTB | 4 variants compilades des de Linux 7.0.2 + 29 pedaços ROCKNIX; avisos heretats |
| Selecció de panell | Comprovada; el validador rebutja DTB standard quan es demana SP v2 |
| Scripts boot | SP standard/v2 generats i llegits amb mkimage |
| Meshtastic host | 2.7.11 instal·lat en venv x86_64, --help/--version i pip check correctes |
| Unitats systemd | INI validat; verify complet pendent: eina host no admet --root per verify |
| Kernel/U-Boot/rootfs ARM64 | No compilats completament |
| Imatge estructuralment validada | No; només hi ha proves del validador amb imatge sintètica |
| Arrencada al maquinari | **PENDENT** |
| Funcionalitats físiques | **TOTES PENDENTS** |

`TARGET=rg35xxsp ./build.sh all` es va aturar al preflight sense iniciar les etapes privilegiades. Una comprovació posterior `deps` confirma: Docker no disponible, sudo sense autenticació i binfmt qemu-aarch64 no habilitat amb flag F. Els registres es conserven a `dist/*-all.log` i `dist/*-deps.log`; còpia resumida a evidence.

## 4. Imatge i SHA256

**Imatge `.img.xz`: no existeix. SHA256 d'imatge: no disponible.** No s'ha substituït per una imatge H ni per DTB precompilats.

Hi ha DTB parcials a `work/dts-audit/`; les seves sumes són a [DTB.SHA256](evidence/DTB.SHA256). No són sumes d'una imatge de sistema. El tar Linux utilitzat té SHA256 `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662`, comprovat contra la llista de kernel.org descarregada.

## 5. Errors i limitacions

- No s'han pogut executar actualització Ubuntu ni preparació privilegiada per manca d'autenticació sudo. Docker absent/inaccessible i binfmt incomplet impedeixen compilar.
- Hi ha 11 avisos dtc per variant. Alguns pedaços upstream s'apliquen amb offset/fuzz. Falta dt-schema i build complet.
- La recepta específica H700 selecciona Linux 7.0.2; la 6.15.6 genèrica no s'aplica. Es va resoldre aquesta ambigüitat abans de compilar els DTS.
- A XFCE 4.20, tapa «no fer res» és el valor **4**, no 0 (0 és DPMS). S'ha comprovat al [codi d'XFCE](https://github.com/xfce-mirror/xfce4-power-manager/blob/xfce4-power-manager-4.20.0/common/xfpm-enum-glib.h) i configurat abans de la primera sessió.
- Els rails de PMIC de la SP no s'han retocat. El problema de panell als ~30 s de la H podria requerir investigació a SP; no es pot donar per resolt.
- No hi ha detecció automàtica de panell, suspensió de tapa, redimensionament automàtic de SD ni garantia de càrrega simultània en host OTG.
- El menú Meshtastic i mapper estan provats lògicament, però falta executar-los amb evdev/USB/BLE reals.
- No hi ha reproductibilitat bit a bit: APT i dependències transitives pip varien. El rootfs H històric conserva credencials/serveis insegurs; les millores de seguretat descrites són del perfil SP.

## 6. Primer arrencament i properes accions

1. Preparar WSL2 des del terminal amb `./scripts/setup-wsl2.sh`; escollir un únic Docker (preferència Desktop+integració WSL2) segons [WSL2_SETUP.md](WSL2_SETUP.md). Cap canvi de Windows s'ha fet automàticament.
2. Crear el hash privat de contrasenya i compilar `TARGET=rg35xxsp PANEL=standard PROFILE=minimal`, segons [RG35XXSP_BUILD.md](RG35XXSP_BUILD.md).
3. Si la compilació i estructura passen, verificar SHA256 i gravar **manualment una microSD nova**, amb eina gràfica i confirmació del suport. Conservar intacta l'original.
4. Validar boot, panell, energia, teclat i apagada abans de passar al perfil desktop. Per un panell incompatible, provar una imatge v2 separada seguint la guia.
5. Validar USB OTG abans de connectar Heltec; consultar info/nodes sense enviar text. BLE és opcional.
6. Completar [TEST_CHECKLIST.md](TEST_CHECKLIST.md): arrencada, pantalla, retroil·luminació, XFCE, controls, teclat, Wi-Fi, Bluetooth, àudio, bateria, càrrega, tapa, USB, Heltec, Meshtastic i apagada continuen **PENDENTS**.

Guia detallada: [RG35XXSP_FIRST_BOOT.md](RG35XXSP_FIRST_BOOT.md). No s'ha escrit en cap targeta SD ni disc físic ni s'ha enviat cap missatge de ràdio.
