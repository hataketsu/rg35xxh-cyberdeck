# Diagnòstic de panell després del progrés amb LPDDR3

El 2026-11-04, amb `lpddr3-led-gpio-0c6f35f`, l'usuari informa que el LED passa de vermell a verd i s'activa la pantalla, però mostra línies verticals que varien lleugerament de color. La fotografia mostra retroil·luminació, moltes línies a la zona esquerra i una zona gris extensa, amb LED verd.

El checkpoint verd acredita que la inicialització de DRAM ha retornat una mida no nul·la. És progrés respecte dels reinicis amb el perfil LPDDR4 corregit. No equival a una prova exhaustiva de RAM. La lectura posterior del journal confirma Linux i Debian fins a `multi-user.target` i el servei de login de consola; encara no s'ha validat una autenticació interactiva ni la llegibilitat de la pantalla.

## Arrencada confirmada pel journal de la SD

Inspecció autoritzada només de lectura el 2026-11-04: hashes BOOT correctes, ext4 net, muntat una vegada a `/`. El journal persistent confirma Linux 7.0.2, muntatge de rootfs i BOOT, framebuffer i `getty@tty1`. L'arrencada acaba als **9,583 s**. El firmware de panell carregat és `anbernic,rg35xx-plus-panel.panel`, amb totals 800×500. Això reforça la prova v2, però no demostra per si sol que sigui la solució.

La tapa es tanca als 52,57 s; el sistema registra el botó d'encesa als 54,58 s i executa una apagada ordenada. El temporitzador d'exportació de logs a BOOT, previst als 60 s, no arriba a disparar-se. El rellotge absolut no és fiable; s'utilitzen temps monotònics. Es detecta també una segona SD de 58,2 GiB; la prova següent ha de tenir TF2 buida.

Hi ha avisos DRM en establir la propietat d'orientació, `regulatory.db` absent, errors d'activació de `wpa_supplicant` i avisos ALSA. Són pendents de seguiment; no impedeixen arribar a multi-user i no s'han de confondre amb funcions verificades. Es manté la prova de panell acotada abans de modificar aquests subsistemes. Extracte sense dades personals: [evidència](evidence/sd-lpddr3-first-linux-boot.txt). Snapshot i journal complets privats a `work/panel-after-lpddr3/sd-read/`.

## Comparació de configuracions

El DTB estàtic llegit de la SD original declara `fog_fj035fhd05_v1`, 640×480, rellotge de píxel de 24 MHz i totals de 720×560. És una pista; no es disposa encara del DTB efectiu en execució del sistema original.

Els firmwares de panell integrats al kernel fixat contenen:

| Perfil | Actiu | Totals H×V | Rellotge |
|---|---|---|---|
| Standard `anbernic,rg35xx-plus-panel` | 640×480 | 800×500 | 24 MHz (també un mode de 48 MHz) |
| SP v2 `anbernic,rg35xx-sp-v2-panel` | 640×480 | 720×560 | 24 MHz |

La seqüència d'inicialització i les polaritats també difereixen. El driver `panel-mipi.c` interpreta aquests camps en big-endian; v2 està integrat a `CONFIG_EXTRA_FIRMWARE` i `CONFIG_DRM_PANEL_MIPI=y`.

La [guia oficial ROCKNIX](https://rocknix.org/configure/h700-installation/) enumera DTB separats per SP/ SP v2 i indica provar l'alternatiu si la pantalla mostra dades corruptes. La coincidència dels totals de v2 amb el DTB original reforça aquesta prova, sense identificar definitivament el panell físic.

## Candidat v2 preparat

`dist/rg35xxsp-cyberdeck-v2-minimal-lpddr3-led-gpio-1c60dbf.img`, 6 GiB.

- SHA256 imatge: `0f908b09dda6d6d8dba811c4461ce799368980abf8288e319b348dbbaf0f1a83`.
- SHA256 XZ: `898ba423b6436483bd81e5b6e747c329fe5923a1864a95c88d258b4d37497f1a`.
- Mateix bootloader LPDDR3 corregit i checkpoints; primers 16 MiB idèntics a `0c6f35f`.
- Mateixos kernel, scripts de boot, MBR, PARTUUID i rootfs. Es manté DCDC3 a 1200 mV als DT d'U-Boot/Linux.
- Només canvien `/spi/panel@0/compatible` i `/rocknix-dt-id`, els dos overrides del DTS SP v2 de ROCKNIX fixat. La comparació de DT descompilats, desfent aquests dos canvis, és idèntica.
- El fitxer carregat conserva l'àlies `sun50i-h700-anbernic-rg35xx-sp.dtb`; BUILD-INFO declara `PANEL=v2` i aquest nom. BOOT.SHA256 s'actualitza.

Empaquetat, fsck FAT, hashes BOOT, SPL, comparació de MBR/rootfs i integritat XZ correctes. Registres: `work/panel-after-lpddr3/v2-pack-correct-revision.log` i `v2-dtb-comparison.log`. Un primer empaquetat amb etiqueta de revisió incorrecta es va interrompre i conservar separat a `aborted-revision`; no s'ha gravat.

Els tres fitxers petits per a una eventual actualització només de BOOT són a `work/panel-after-lpddr3/candidate/`; originals de referència a `baseline/`, hashes a `panel-update-plan.json`. `update-panel.ps1` valida la SD i els fitxers actuals, prepara còpia de seguretat i substitueix només DTB, BOOT.SHA256 i BUILD-INFO.txt, amb flush, verificació i expulsió. El preflight sense escriptura ha passat amb la SD connectada. El bootloader i el rootfs amb les dades d'execució es conserven. L'usuari ha autoritzat l'actualització i s'ha aplicat el 2026-11-04 a les 12:44:54 +01:00: tres fitxers verificats, còpia dels originals comprovada i expulsió correcta. Resultat `UPDATED_AND_VERIFIED`, `ejected=true`; [evidència](evidence/sd-sp-v2-panel-update.txt). Prova física posterior confirmada per l'usuari el 2026-11-04: arrenca amb consola llegible i petició de contrasenya. La combinació LPDDR3 corregida + panell SP v2 queda validada per aquesta arrencada fins al prompt; autenticació, estabilitat prolongada i repeticions encara pendents.

Per reproduir la imatge: script d'empaquetat diagnòstic amb `RG_DIAG_DRAM=lpddr3 RG_DIAG_CHECKPOINTS=1 RG_DIAG_PANEL=v2` i revisió de fonts vàlida. No cal recompilar U-Boot ni el kernel.
