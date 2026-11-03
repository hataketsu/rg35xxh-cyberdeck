# Auditoria RG35XXSP

Data: 2026-11-03. Original: [hataketsu/rg35xxh-cyberdeck](https://github.com/hataketsu/rg35xxh-cyberdeck), commit `81cec5d7dfc23385cbd7c21daaef13f65817827a`. Branca local `rg35xxsp-port`. Inspeccionats README, VERSIONS, tots els scripts, rootfs/stages, overlays, pedaços, empaquetador, documents i workflow.

## Versions efectives

ROCKNIX està fixat a `8e4055f93f868f177ae3e4639c34238de1beb34a` (l'original només en donava deu caràcters). El paquet **específic del projecte** `projects/ROCKNIX/packages/linux/package.mk` selecciona **Linux 7.0.2** per H700. `packages/linux/package.mk` mostra 6.15.6, però queda substituït: no és el kernel efectiu. L'expressió del README «7.0.2 (mainline 6.15.6)» era ambigua. Es conserva 7.0.2.

GCC efectiu: **15.2.0**, de `projects/ROCKNIX/packages/lang/gcc/package.mk`; el genèric 15.1.0 també queda substituït. Firmware: paquet del projecte **20260309**, amb fitxers addicionals de panell. Joypad: `7647fdb0fc89cd69b284903bf7707e861df5dc7e`.

U-Boot: **v2025.07-rc3**, recepta de `projects/ROCKNIX/devices/H700/packages/u-boot/package.mk`, `anbernic_rg35xx_h700_defconfig`, ATF **2.12.0**, plataforma `sun50i_h616`. Configuració LPDDR4, rellotge DRAM 672, AXP717. DTS intern U-Boot: `sun50i-h700-anbernic-rg35xx-2024`; el DTS Linux seleccionat es carrega separadament des de FAT. ROCKNIX modifica bootdelay, EFI i LED; no s'afegeixen ajustos DRAM/PMIC locals.

Fonts fixades: [recepta Linux](https://github.com/ROCKNIX/distribution/blob/8e4055f93f868f177ae3e4639c34238de1beb34a/projects/ROCKNIX/packages/linux/package.mk), [recepta U-Boot](https://github.com/ROCKNIX/distribution/blob/8e4055f93f868f177ae3e4639c34238de1beb34a/projects/ROCKNIX/devices/H700/packages/u-boot/package.mk), [defconfig U-Boot](https://github.com/u-boot/u-boot/blob/v2025.07-rc3/configs/anbernic_rg35xx_h700_defconfig).

## Comportament original i canvis

| Àrea | Evidència original | Decisió del port |
|---|---|---|
| DTB | Nom H a VERSIONS i boot.cmd precompilat | Perfils explícits i boot.scr regenerat amb mkimage |
| Pantalla | RGB 640×480, panell MIPI DPI/SPI dels pedaços ROCKNIX | SP standard/v2 compilats del mateix arbre |
| PMIC | Patcher afegeix always-on a reguladors buits | Només es conserva per H; SP conserva DTS sense aquest retoc |
| Bateria | UPower `PercentageAction=0`, `CriticalPowerAction=Ignore`; documentació proposa chattr | SP 15/7/3%, PowerOff; no chattr ni lectura inventada |
| USB | Serveis gadget activats, scripts esperats absents de l'overlay | SP conserva OTG del DTS i no activa gadgets |
| LightDM | Autologin usuari `hataketsu` | SP autologin `cyberdeck` només al perfil desktop |
| Privilegis | Contrasenya coneguda, NOPASSWD sudo | SP hash obligatori escollit per l'usuari, sudo amb contrasenya, root bloquejat |
| Xarxa | SSH activat i Tailscale instal·lat | SP SSH/socket emmascarats, sense Tailscale |
| Controls | Joy2mouse basat en sticks analògics; creueta genera fletxes | Mapper SP usa la creueta per moure cursor; verifica nom/vendor/product |
| Mòduls | Recompila kernel però copia mòduls install_pkg anteriors | modules_install després de recompilar, depmod i comprovació vermagic |
| Rootfs | Comprovació `-d etc/debian_version` incorrecta i esborrat recursiu posterior | Rootfs existent rebutjat; cal un espai nou, no s'esborra |
| Resolució DNS | Enllaç a systemd-resolved no instal·lat explícitament | SP enllaç al resolv.conf de NetworkManager |
| Imatge | Comentari GPT però implementació MBR; root MMC fix | MBR explícit, PARTUUID únic i SPL a 8 KiB |
| Creixement SD | growpart sobre mmcblk0 automàtic, errors ignorats | SP sense redimensionament automàtic |
| Serveis | wifi-watchdog.service referencia nom sense `.sh`; logs sense unitat instal·lada | SP no hereta watchdog; timer de diagnòstic propi |
| Errors | `su ...` intern sense mode estricte | Bash estricte dins del contenidor |
| Dependències | mkimage, mkfs, rsync, depmod i altres no comprovats | Preflight ampliat i guia WSL2 |

La selecció H continua disponible amb els seus stages/overlay històrics. **Les correccions de seguretat del perfil SP no endureixen retrospectivament el rootfs H**. Les millores comunes de pipeline, boot.scr, mòduls, particions i aïllament sí afecten tots dos models i requereixen regressió física H.

## Límit de confiança

Les fonts del projecte i paquets de firmware es descarreguen de repositoris públics. S'ha fixat la revisió de ROCKNIX i comprovat el SHA256 del tar Linux. Debian usa repositoris signats, però no snapshots immutables; Meshtastic fixa el paquet principal i desa `pip freeze`, però no bloqueja amb hashes totes les dependències transitives. Aquesta primera versió **no garanteix reproductibilitat bit a bit**.

El workflow original publica releases en tags; no s'ha executat ni s'ha fet push. S'afegeix un workflow separat de comprovacions SP, sense publicació. No s'han executat scripts provinents de la documentació sobre discos físics.
