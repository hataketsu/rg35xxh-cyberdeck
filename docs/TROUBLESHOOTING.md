# Resolució de problemes

| Símptoma | Comprovació | Acció |
|---|---|---|
| `docker` no existeix / info falla | Motor únic, context, integració WSL | Seguir WSL2_SETUP; no instal·lar dos motors |
| Sudo demana contrasenya | Terminal interactiu WSL2 | `sudo -v`; no enviar-la al xat |
| `Exec format error` al chroot | binfmt qemu-aarch64, enabled/flag F | Preparar qemu-user-static i binfmt; no usar binaris ARM64 directament sense emulació |
| Rootfs existent | Directori de treball del perfil | Conservar-lo i usar RG_WORK nou; no s'esborra automàticament |
| Artefacte kernel/mòdul absent | Registre d'etapa i commit fixat | Reconstruir kernel; no empaquetar parcialment |
| `vermagic` incompatible | Mòdul extern amb un altre kernel | Reconstruir el gamepad amb el toolchain de la mateixa compilació |
| Error en mke2fs/mcopy | Registre i espai del staging `work/.../pack.*` | Conservar els fitxers parcials i corregir l’error; no usar discos físics alternatius |
| Pantalla ratllada/blanca | Variant standard/v2, nom carregat a boot.cmd | Apagar i provar l'altra imatge compilada; no barrejar DTB de kernels |
| Pantalla s'apaga al cap de ~30 s | Errors de reguladors al journal | Desar logs; la correcció H always-on no s'aplica a SP sense evidència |
| Shell BusyBox o errors `/flash` | Initramfs ROCKNIX incrustat | Revisar registre de recompilació i configuració; no usar Image original |
| Arrel no es munta | PARTUUID a boot.cmd i fstab, MMC/ext4 incorporats | Revisar BUILD-INFO i recompilar coherentment |
| XFCE no apareix | PROFILE, `systemctl status lightdm` | `minimal` és consola; al desktop revisar Xorg i firmware del panell |
| Cursor no respon | `evtest`, `systemctl status sp-gamepad` | Verificar nom i identitat interna; no ampliar captura a tots els teclats |
| Tecles/clics incorrectes | Codi real evdev i etiqueta del botó | Adaptar el mapa després de registrar la unitat física |
| Wi-Fi connectat sense trànsit | `nmcli`, logs kernel/NetworkManager | Diagnosticar rtw88; watchdog agressiu H no està habilitat |
| Percentatge erroni | UPower contra sysfs i evolució real | No desactivar avisos ni escriure capacity fictícia; investigar driver |
| Tancar tapa no suspèn | Configuració deliberada del port | Usar apagada segura; no activar suspensió abans de verificar resume |
| Heltec no crea port | `lsusb`, cable dades, rol OTG, VBUS | Provar teclat/adapter, després node USB; BLE és alternativa pendent |
| BLE falla | `rfkill`, `bluetoothctl show`, escaneig manual | Tornar a USB i registrar error sense enviar text |

## Recuperació d'una arrencada fallida

Conserveu la SD original i proveu sempre amb una SD nova. Si hi ha consola o teclat funcional, feu `sudo systemctl poweroff`. Si està completament bloquejada, una pulsació llarga del botó d'engegada és un recurs final; pot deixar fitxers corruptes a la SD de proves. No retireu la SD en calent.

Amb la consola apagada, llegiu la partició BOOT des del PC. `BUILD-INFO.txt` identifica model, panell, kernel i revisions. `/boot/logs/boot-*.txt` desa avisos després de 60 segons si systemd ha arrencat. La manca de logs **no** demostra que U-Boot hagi fallat: també pot indicar un error anterior al timer.

No s'activa un shell root de recuperació ni SSH per defecte. Si no hi ha imatge usable, torneu a la SD original; no s'ha modificat l'emmagatzematge intern de la consola. Per repetir una prova, regraveu únicament la SD nova escollida a l'eina gràfica.

## Registres útils

```bash
uname -a
cat /proc/cmdline
cat /proc/device-tree/model
systemctl --failed
journalctl -b -k --no-pager
upower -d
cat /sys/class/power_supply/*/uevent
nmcli device
bluetoothctl show
sudo evtest
```

Trieu l'entrada del gamepad o de tapa explícitament a evtest. No incloeu dades de teclat personals. Els logs de xarxa poden identificar dispositius/SSID, i la informació Meshtastic pot contenir configuració privada; reviseu-la abans de compartir-la.

Els avisos dtc heretats queden a `docs/evidence/dtc-sp-warnings.txt`; l'aplicació dels pedaços queda a `kernel-patch-audit.txt`. No han estat corregits a cegues ni equivalen a un resultat de dt-schema.
