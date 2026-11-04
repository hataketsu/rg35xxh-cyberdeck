# Diagnòstic de panell després del progrés amb LPDDR3

El 2026-11-04, amb `lpddr3-led-gpio-0c6f35f`, l'usuari informa que el LED passa de vermell a verd i s'activa la pantalla, però mostra línies verticals que varien lleugerament de color. La fotografia mostra retroil·luminació, moltes línies a la zona esquerra i una zona gris extensa, amb LED verd.

El checkpoint verd acredita que la inicialització de DRAM ha retornat una mida no nul·la. És progrés respecte dels reinicis amb el perfil LPDDR4 corregit. No equival a una prova exhaustiva de RAM ni confirma encara una sessió Debian. U-Boot té `CONFIG_VIDEO` desactivat; l'activació de la pantalla suggereix progrés al kernel, pendent de confirmar amb logs i estat del rootfs.

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

Els tres fitxers petits per a una eventual actualització només de BOOT són a `work/panel-after-lpddr3/candidate/`; originals de referència a `baseline/`, hashes a `panel-update-plan.json`. Encara no s'ha escrit la prova v2 a cap SD. Pendent de reconnectar la SD de proves per llegir logs/estat d'arrencada i, després, autoritzar l'actualització de panell.

Per reproduir la imatge: script d'empaquetat diagnòstic amb `RG_DIAG_DRAM=lpddr3 RG_DIAG_CHECKPOINTS=1 RG_DIAG_PANEL=v2` i revisió de fonts vàlida. No cal recompilar U-Boot ni el kernel.
