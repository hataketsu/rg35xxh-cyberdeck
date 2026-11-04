# Diagnòstic de memòria — RG35XXSP de l'usuari

La minimal LPDDR4 `e807755` no arrenca en aquesta unitat, també en una SD nova de 32 GB; la SD original sí que arrenca. La relectura del suport confirma MBR/bootloader/BOOT correctes i cap muntatge registrat d'ext4. [Evidència](evidence/sd-minimal-32gb-boot-failure.txt).

El boot0 original desa LPDDR3 (tipus 7, 672 MHz) com a perfil per defecte, amb valors de training específics. També conté perfils alternatius i un DTB estàtic LPDDR4. Això justifica provar LPDDR3, però no demostra per si sol la memòria física ni la causa definitiva. [Paràmetres i fonts](evidence/stock-memory-diagnostic.txt).

## Candidat separat

- Imatge: `dist/rg35xxsp-cyberdeck-standard-minimal-lpddr3-diag-00ed466.img`, 6 GiB, amb XZ i SHA256 adjunts.
- U-Boot v2025.07-rc3 + ATF 2.12.0, compilat en un espai independent. Perfil LPDDR3 basat en [ROCKNIX fixat](https://github.com/ROCKNIX/distribution/blob/93c889bb853f2a11e51cecb0a9a75221219a2cce/projects/ROCKNIX/devices/H700/packages/u-boot-DDR3/sources/configs/anbernic_rg35xx_h700_lpddr3_defconfig); TPR11 prové del boot0 d'aquesta unitat.
- Correcció upstream del byte TPR6 usat pel PHY LPDDR3; LED d'estat inicialitzat al SPL abans de la inicialització de DRAM; bootdelay de 2 segons.
- DCDC3 de 1200 mV segons el perfil LPDDR3 upstream, coherent als DT de control U-Boot i Linux. Aquesta configuració **no és un nou valor per defecte per a tots els SP**.
- Mateixos kernel, boot.cmd, boot.scr, MBR, PARTUUID i rootfs. El DTB Linux només canvia els dos límits de tensió del regulador vdd-dram; BOOT.SHA256 i BUILD-INFO reflecteixen el candidat.

SHA256 de la imatge sense comprimir: `48f7c8ab252eb7e7b8a90d2834b2fd1444a29f02d2180c746ed196bc5a74c5e9`.
SHA256 U-Boot/SPL: `7b181729729ac94a3c62945fab073654f7a41efc0fe81b38de0ba022f5215825`.

## Comprovacions completades

Sintaxi i ShellCheck dels dos scripts; compilació real del bootloader; configuració LPDDR3, presència del codi LED al SPL, checksum eGON, límit de mida SPL i posició FIT. Empaquetat sense dispositius; comparació byte a byte de tot el rootfs i MBR; bootloader incorporat comparat; fsck FAT, hashes BOOT, MBR/SPL i integritat XZ correctes.

Registres: `work/boot-failure-32gb/lpddr3-build.log` i `lpddr3-pack.log`. No s'ha modificat la SD original ni els espais de compilació H/SP anteriors.

## Reproducció

`scripts/build-sp-lpddr3-diagnostic.sh` exigeix el build original i un espai `work/sp-lpddr3-diagnostic` nou; rebutja sobreescriure'l. Utilitza Docker i el toolchain ja construït, sense xarxa.

`scripts/pack-sp-lpddr3-diagnostic.sh` s'executa en el contenidor `cyberdeck-rootfs`, amb el repositori de lectura i `dist` d'escriptura. Exigeix `RG_DIAG_REVISION` i opcionalment `RG_DIAG_DIST`; comprova el SHA256 de la base i no sobreescriu sortides. Només opera sobre fitxers, mai sobre discos.

## Validació física pendent

Aquest candidat **no està validat al maquinari**. Cal provar-lo a la SD de proves, amb bateria carregada, TF1, TF2 buida i apagada completa abans del canvi. Observar si apareix un LED, pantalla o consola; el LED per si sol només acredita un canvi de comportament inicial, no l'arrencada de Debian. Conservar l'original com a recuperació.
