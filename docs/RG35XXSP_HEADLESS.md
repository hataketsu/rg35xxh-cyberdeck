# Accés Wi-Fi i SSH sense teclat a la consola

L'usuari ha demanat explícitament aquest accés després de validar una consola llegible amb LPDDR3 i panell SP v2 el 2026-11-04. És una personalització de la seva SD; les imatges genèriques continuen amb SSH desactivat.

## Credencials locals

Des del terminal WSL, executeu `python3 scripts/make-wifi-profile.py work/headless-wifi-ssh/private/home.nmconnection`. L'assistent demana SSID, tipus WPA2/mixt o WPA3, xarxa oculta i contrasenya amb entrada no visible i confirmació. Crea un perfil NetworkManager amb mode 0600 dins d'un directori privat, sense sobreescriure un fitxer existent. No compartiu el contingut ni el poseu a Git. La PSK derivada WPA2 també és una credencial secreta.

El perfil permet autoconnectar sense agent gràfic ni sessió iniciada, amb DHCP i IPv6 automàtic. La contrasenya Wi-Fi és diferent de la contrasenya de l'usuari `cyberdeck` utilitzada per SSH.

## Preparació fora de línia

Es copia en lectura la SD de proves de 31927042048 bytes, després de validar identitat i particions. Es conserven el prefix amb MBR/bootloader/BOOT i el rootfs actuals com a còpia privada. Es modifica una còpia separada del rootfs mitjançant loop/chroot en contenidor; no s'instal·len paquets a Windows ni es modifica la SD durant aquesta preparació.

Paquets afegits: `wpasupplicant`, `wireless-regdb`, `iw`, `openssh-server` i `avahi-daemon`, amb les dependències necessàries. L'absència dels dos primers explica els errors de supplicant i base regulatòria del journal anterior. El constructor SP i el validador s'han corregit perquè els futurs rootfs incloguin aquests paquets Wi-Fi.

SSH usa `ssh.service`, amb autenticació de contrasenya per a `cyberdeck`, root prohibit, contrasenyes buides prohibides i autenticació interactiva de teclat desactivada. Les claus d'amfitrió es generen per a aquesta SD i es registra l'empremta pública ED25519. S'habiliten NetworkManager i Avahi per a `rg35xxsp.local`. La configuració de tapa i el panell que ja arrenquen es conserven.

Abans de gravar: validar el perfil amb el `nmcli --offline` instal·lat, `sshd -t`, opcions efectives SSH, unitats habilitades, propietat/permisos, paquets ARM64, neteja del chroot, fsck, mida de particions, igualtat del prefix BOOT i SHA256. La imatge personalitzada conté credencials i claus privades: es conserva només al directori privat de treball, no com a artefacte públic a `dist`.

Preparació i validació completades; [evidència i empremta pública SSH](evidence/headless-wifi-ssh-preparation.txt). La imatge privada de 6 GiB conserva íntegrament MBR, bootloader i BOOT de la SD que funciona. Gravació autoritzada i completada el 2026-11-04 a les 13:12 +01:00, amb verificació completa i expulsió correcta; [registre](evidence/headless-wifi-ssh-write.txt). L'usuari confirma la primera connexió SSH reeixida el mateix dia («I'm in!»): connectivitat Wi-Fi i autenticació remota verificades en aquesta prova.

## Connexió després d'arrencar

Amb l'ordinador a la mateixa xarxa, proveu des de PowerShell o WSL:

```sh
ssh cyberdeck@rg35xxsp.local
```

Si el nom `.local` no es resol, utilitzeu la IP mostrada al router per `rg35xxsp`: `ssh cyberdeck@ADREÇA_IP`. La primera connexió mostra l'empremta del servidor; compareu-la amb la registrada durant la preparació. Introduïu la contrasenya que vau escollir per a `cyberdeck`. No es mostren caràcters mentre s'escriu.

No cal modificar el router ni obrir ports cap a Internet. La primera connexió Wi-Fi i autenticació SSH estan confirmades per l'usuari. Queden pendents la verificació detallada de DHCP/DNS, resolució `.local`, reconexió després de reiniciar i estabilitat prolongada.

Referències: [format NetworkManager keyfile](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nm-settings-keyfile.html) i [sshd_config de Debian 13](https://manpages.debian.org/trixie/openssh-server/sshd_config.5.en.html).

Comprovació posterior per SSH: kernel 7.0.2 aarch64, 976 MiB de RAM utilitzable, 810 MiB disponibles i cap unitat systemd fallida en aquell instant. [Sortida aportada per l'usuari](evidence/headless-runtime-checks.txt).
