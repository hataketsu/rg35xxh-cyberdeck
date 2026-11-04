# Diagnòstic de memòria — RG35XXSP de l'usuari

**Correcció del diagnòstic (2026-11-04):** les variants `lpddr3-diag-00ed466`, `lpddr3-led-ed24995` i `lpddr4-led-3ac38e1` contenen un error introduït en activar el LED inicial: `status_led_init()` escriu un flag a DRAM abans d'inicialitzar-la. Els resultats de vermell fix d'aquestes variants són **inconclusius per al tipus de RAM i el PMIC**. Els registres històrics es conserven; aquestes variants queden substituïdes pel candidat amb GPIO directe. [Evidència del defecte i correcció](evidence/early-led-bss-regression.txt).

## Comparació LPDDR3 corregida gravada

`dist/rg35xxsp-cyberdeck-standard-minimal-lpddr3-led-gpio-0c6f35f.img`, 6 GiB. SHA256: `18b085fdbf27866ea9fd5ea7dd13e13a1242f5a82247603ef6cdd95da3b940c1`; XZ: `1e09fc90155dfdea00c82f172c1e186b15ff3a9f71dd5e3e96a90c1c1b91bd8b`. Bootloader: `2363bc8b435e1552ecddb50829e80865216c102e911179e87aa492dc0ba64bba`.

Utilitza els timings LPDDR3 anteriors extrets del perfil per defecte de boot0, 672 MHz, correcció PHY LPDDR3 i DCDC3 1200 mV coherent als DT d'U-Boot/Linux. La configuració de memòria/potència coincideix amb el candidat LPDDR3 anterior, però el codi LED ara és GPIO directe. El fitxer `board/sunxi/board.c` amb els checkpoints PMIC/DRAM/U-Boot és idèntic al de la comparació LPDDR4 corregida.

Compilació, regressió del LED/BSS, checksum SPL, FIT, empaquetat, fsck FAT, hashes BOOT, integritat XZ i comparació byte a byte de MBR/rootfs superats. Registres: `work/boot-failure-lpddr4-gpio/lpddr3-gpio-{build,pack}.log`. Gravada a la SD de proves de 32 GB amb autorització explícita, SHA256 verificat per relectura, codi 0 i expulsió correcta el 2026-11-04; [evidència](evidence/sd-lpddr3-gpio-write.txt). Prova d'arrencada física pendent. Reproducció: els scripts habituals amb `RG_DIAG_DRAM=lpddr3 RG_DIAG_CHECKPOINTS=1`; workspace `work/sp-lpddr3-checkpoints-gpio`.

## Comparació LPDDR4 corregida provada

`dist/rg35xxsp-cyberdeck-standard-minimal-lpddr4-led-gpio-b261dd6.img`, 6 GiB. Conserva els paràmetres LPDDR4/PMIC originals i els checkpoints de la comparació anterior, però usa GPIO directe abans d'inicialitzar DRAM. SHA256: `b4f009fe974ee20913b00a597750e6e5ae0998d065eca76f67fc8d919aad0ae3`; XZ: `09372180f1920523e836b2bafa2c951c6515c88b53905e4e46337f6348cfdc88`.

Compilació i empaquetat completats amb codi 0. El validador rebutja els tres SPL defectuosos i accepta el corregit. S'han inspeccionat els símbols i el desassemblatge del camí LED; el flag i la funció genèrics ja no apareixen al SPL. Checksum SPL, FIT, fsck FAT, hashes BOOT, integritat XZ i comparació byte a byte de MBR/rootfs correctes. Registres a `work/early-led-bss-audit/`.

Aquest candidat s'ha gravat a la SD de proves de 32 GB amb autorització explícita el 2026-11-04: SHA256 verificat per relectura, codi 0 i expulsió correcta. [Evidència](evidence/sd-lpddr4-gpio-write.txt). La prova física mostra un flaix vermell feble, dos de més intensos, aproximadament 2 segons fix i repetició amb el botó alliberat; pantalla negra. És coherent amb els checkpoints del PMIC seguits d'un reinici durant DRAM. El timeout d'1 segon de DRAM pot cridar `panic()` i reiniciar, però aquesta causa concreta requereix confirmació; [observacions i límits](evidence/sd-lpddr4-gpio-loop.txt). No s'ha confirmat arrencada de Debian. Els apartats següents conserven l'historial dels candidats anteriors.

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

Els scripts actuals afegeixen `-gpio` als workspaces i noms de variant, apliquen la correcció d'accés prematur a BSS i validen el SPL abans de construir/empaquetar. Els noms anteriors d'aquest document identifiquen els artefactes històrics.

## Prova física i diagnosi pendent

El 2026-11-04 s'ha gravat aquest candidat a la SD de proves de 32 GB amb autorització explícita. Raspberry Pi Imager ha verificat el SHA256 per relectura i ha expulsat la targeta correctament; codi de sortida 0. [Evidència de gravació](evidence/sd-lpddr3-diagnostic-write.txt).

Aquest candidat **no està validat al maquinari**. Cal provar-lo a la SD de proves, amb bateria carregada, TF1, TF2 buida i apagada completa abans del canvi. Observar si apareix un LED, pantalla o consola; el LED per si sol només acredita un canvi de comportament inicial, no l'arrencada de Debian. Conservar l'original com a recuperació.

Primera resposta de l'usuari: pantalla negra i LED vermell fix, també sense carregador. El LED inicial del candidat és PI11 (vermell), activat abans de configurar el PMIC i inicialitzar DRAM; el verd normal és PI12. La relectura confirma el bootloader i els hashes BOOT; ext4 no registra muntatges. Aquesta observació no prova que el canvi a LPDDR3 hagi resolt la inicialització de memòria ni que Linux hagi començat. [Evidència](evidence/sd-lpddr3-red-led.txt).

## Checkpoints addicionals

`RG_DIAG_CHECKPOINTS=1` als dos scripts genera una variant separada `lpddr3-led` a partir del mateix perfil de memòria. El workspace és `work/sp-lpddr3-checkpoints`; no modifica el candidat anterior.

- Vermell: entrada inicial al SPL, abans del PMIC i la DRAM.
- Verd durant almenys un segon: la inicialització DRAM ha retornat una mida no nul·la.
- Tots dos LEDs durant almenys un segon: s'ha arribat a `board_init()` d'U-Boot principal.

Són checkpoints de control, no tests exhaustius de RAM ni proves d'arrencada de Linux. Cal observar tota la seqüència, perquè el codi posterior pot canviar els LEDs. No es canvien timings, freqüència ni voltatges respecte del candidat anterior.

Imatge preparada i comprovada: `dist/rg35xxsp-cyberdeck-standard-minimal-lpddr3-led-ed24995.img` (6 GiB). SHA256: `443c1d93ef979e1aac94197f3a289d097e9059e46f815f717c79ed0edd22e9aa`. XZ: `a3faebf9a2eb85a1f6019c26e0ae2b0702e5466d8456a716decea07140649256`. Bootloader: `91bab359903b495e5e0026d5123fe9f0c58d49f959e55e6d89b57348a7ffad4f`.

Compilació, checksum SPL, FIT, hashes BOOT, fsck FAT, integritat XZ i comparació byte a byte de MBR/rootfs superats. Registres: `work/boot-failure-lpddr3/checkpoints-{build,pack}.log`. Variant gravada a la SD de proves de 32 GB amb autorització explícita el 2026-11-04: SHA256 de relectura coincident, codi 0 i expulsió correcta. [Evidència](evidence/sd-lpddr3-checkpoints-write.txt). L'usuari informa de vermell fix sense altres transicions: no s'ha observat el checkpoint posterior a DRAM. PMIC i inicialització DRAM continuen sent possibles punts d'aturada.

## Comparació LPDDR4 amb checkpoints de potència

La imatge LPDDR4 inicial no activava el LED en SPL. Per tant, l'absència de LED d'aquella prova no serveix per comparar l'etapa assolida amb els candidats LPDDR3. El tipus físic de RAM continua sense confirmar-se.

`RG_DIAG_DRAM=lpddr4 RG_DIAG_CHECKPOINTS=1` als mateixos scripts crea una variant aïllada a `work/sp-lpddr4-checkpoints`, amb el perfil LPDDR4 original: 672 MHz, DCDC3 1100 mV i els mateixos timings de la minimal `e807755`. El DTB Linux conserva els valors originals de 1100000 µV. No s'hi aplica el pedaç del PHY LPDDR3.

La variant manté els checkpoints verd (DRAM ha retornat una mida no nul·la) i tots dos LEDs (U-Boot principal). Afegeix dos parpelleigs vermells breus si les crides de configuració del PMIC retornen sense error. Si retornen error, s'atura abans de DRAM amb parpelleig vermell repetit; aquest és un comportament de diagnòstic, no una correcció del PMIC. Retorn sense error no equival a mesura física dels rails.

Imatge preparada: `dist/rg35xxsp-cyberdeck-standard-minimal-lpddr4-led-3ac38e1.img`, 6 GiB. SHA256: `229fae619f18237019c96b36fae88d3c4c9ea409bf0471eea1cbac6ec1396033`; XZ: `3d9210c6608a4a4c4164142e0baab7fbc5910397a4070982b70bdd2e74d019e3`. Bootloader: `6f58e803b8f1644f22eb87c3dc924fa6ad9d4bac773aaa9ae050b09de0646ed4`.

Compilació real i empaquetat completats amb codi 0; sintaxi i ShellCheck correctes. Configuració de RAM, PMIC i I²C comparada amb la compilació original: idèntica. Kernel, DTB Linux i scripts de boot conserven els hashes de la minimal original; MBR i rootfs comparats byte a byte. fsck FAT, checksum SPL, posició FIT i integritat XZ correctes. Registres: `work/boot-failure-lpddr3-checkpoints/lpddr4-{build,pack,comparison}.log`.

Aquesta variant s'ha gravat a la SD de proves de 32 GB amb autorització explícita el 2026-11-04: SHA256 de relectura coincident, codi 0 i expulsió correcta. [Evidència](evidence/sd-lpddr4-checkpoints-write.txt). L'usuari ha informat de vermell fix; l'auditoria posterior ha trobat el defecte del LED inicial descrit al principi. Aquest resultat no permet comparar els tipus de RAM.
