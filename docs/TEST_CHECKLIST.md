# Pla de validació

Data inicial: 2026-11-03. Cap consola ni Heltec connectat a aquesta sessió. Empleneu data, revisió de placa/panell, hash d'imatge, resultat i evidència a cada prova física.

## Comprovacions de desenvolupament

| Comprovació | Estat | Evidència / límit |
|---|---|---|
| WSL2, espai >40 GiB | COMPLETAT | Ubuntu 22.04, 844 GiB disponibles inicialment |
| Actualització Ubuntu / instal·lació global | PENDENT | Sudo requereix autenticació de terminal |
| Docker i binfmt ARM64 | COMPLETAT | Docker accessible amb grup docker; qemu-aarch64 habilitat amb flag F |
| bash -n, Python AST, INI/desktop | COMPLETAT | scripts/check-static.sh |
| ShellCheck advertències dels scripts nous/modificats | COMPLETAT | Sense advertències amb ShellCheck 0.8.0 |
| Proves automatitzades | COMPLETAT | 8 proves: perfils, MBR, cancel·lació de ràdio, cursor, preflight kernel sense sudo |
| Pedaços de kernel aplicables | COMPLETAT amb avisos | 29 fitxers, alguns offset/fuzz; vegeu evidence |
| DTS → DTB | COMPLETAT amb avisos | SP standard/v2, H standard/rev6; 11 avisos per variant |
| DTB compatible, tapa, OTG | COMPLETAT estàtic | fdtget; no funcional |
| dt-schema / dtbs_check | PENDENT | No executat |
| boot.scr SP standard/v2 | COMPLETAT | Generat i llegit per mkimage |
| Meshtastic venv host i --help | COMPLETAT | x86_64; no és prova ARM64 ni connexió |
| Kernel, U-Boot, rootfs ARM64 complets | EN CURS | Construcció real amb Docker |
| Empaquetat FAT/ext4 sobre fitxers | COMPLETAT | fsck, propietaris, permisos i symlinks; evidence/file-pack-smoke.txt |
| Imatge final i SHA256 | PENDENT | No hi ha `.img.xz` |
| Validació estructural d'imatge final | PENDENT | MBR sintètic provat; cap imatge final real |

## Proves físiques

| Prova | Procediment / criteri | Estat |
|---|---|---|
| Arrencada mínima | TF1, TF2 buida, login console; repetir 3 arrencades fredes | **PENDENT** |
| Identitat | model SP i variant correcta, uname i BUILD-INFO coherents | **PENDENT** |
| Pantalla | 640×480, colors, text estable >10 min i després de 30 s | **PENDENT** |
| Panell v2 | Provar només si correspon; registrar revisió | **PENDENT** |
| Retroil·luminació | brightnessctl, rang llegible i recuperació després DPMS | **PENDENT** |
| XFCE | LightDM inicia cyberdeck, terminal/Thunar/tema/escala | **PENDENT** |
| Controls | evtest i mapa cursor/clics, mantenir/soltar i combinacions | **PENDENT** |
| Teclat extern | USB, layout, hotplug, sense captura pel mapper | **PENDENT** |
| Wi-Fi | Escaneig, credencials, DNS, trànsit i estabilitat 30 min | **PENDENT** |
| Bluetooth | Adaptador, aparellament teclat, reconnectar | **PENDENT** |
| Àudio | Altaveu/auriculars/volum i absència de soroll anormal | **PENDENT** |
| Bateria | Comparar sysfs i UPower durant ús, sense salt persistent a 0% | **PENDENT** |
| Càrrega | Estat carregant/desconnectat, evolució i temperatura normal | **PENDENT** |
| Protecció de bateria | Verificar política/driver sense forçar una descàrrega profunda | **PENDENT** |
| Tapa | SW_LID canvia en obrir/tancar; no suspèn | **PENDENT** |
| Suspensió/resume | Desactivada; només investigar en una fase posterior controlada | **PENDENT** |
| USB OTG host | Rol, VBUS, teclat i reconnectar sense perdre estabilitat | **PENDENT** |
| Hub i alimentació | Teclat+Heltec; no realimentació ni caigudes | **PENDENT** |
| Heltec V4 | lsusb i identificador persistent; versió real de firmware | **PENDENT** |
| Meshtastic USB | info/nodes sense enviar text | **PENDENT** |
| Meshtastic BLE | Escaneig i info voluntaris; USB continua disponible | **PENDENT** |
| Missatge de ràdio | Només manual, destí/text confirmats, receptor voluntari | **PENDENT** |
| Apagada | Escriptori i botó, esperar aturada, reiniciar sense fsck inesperat | **PENDENT** |
| Seguretat | Root bloquejat, sudo amb contrasenya, cap port SSH escoltant | **PENDENT** |
| Consum | Repòs, ús i tapa; tensió/càrrega sense alterar | **PENDENT** |
| Regressió H | Arrencada, mòduls i escriptori del perfil original | **PENDENT** |

Una compilació completada, una imatge estructuralment correcta, una arrencada real i una funcionalitat física són quatre resultats diferents. No marqueu una fila física com completada basant-vos en dtc o en una prova unitària.
