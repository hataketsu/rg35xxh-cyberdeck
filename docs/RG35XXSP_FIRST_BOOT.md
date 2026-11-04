# Primer arrencament

Actualització 2026-11-04: s'han validat arrencada mínima, consola llegible i login SSH amb el bootloader LPDDR3 corregit i el panell SP v2; [diagnòstic de panell](RG35XXSP_PANEL_DIAGNOSTIC.md) i [accés remot](RG35XXSP_HEADLESS.md). El sistema real mostra Linux 7.0.2 ARM64, 976 MiB de RAM i cap unitat fallida. XFCE i la resta de funcionalitats continuen pendents de prova física. Les imatges inicials standard de l'[informe de compilació](IMPLEMENTATION_STATUS.md#4-imatges-i-sha256) no incorporen totes aquestes correccions.

1. Conserveu la microSD original i les seves dades. Prepareu una microSD nova d'almenys 8 GB (16 GB dona marge), sense informació que calgui conservar. Per a una prova mínima en una targeta petita, la variant explícita `minimal-compact` ocupa 960 MiB i exigeix almenys 1.006.632.960 bytes reals; vegeu [compilació compacta](RG35XXSP_BUILD.md#minimal-compacta-per-a-una-sd-petita).
2. Verifiqueu SHA256 i integritat xz. Useu una eina gràfica de gravació que permeti seleccionar una imatge pròpia i validar l'escriptura. Comproveu visualment marca/capacitat del suport de destí: gravar-lo n'esborra el contingut. L'empaquetador no escriu a discos físics. La gravació des de Windows requereix una eina externa i la identificació explícita de la targeta. Si Imager no pot llegir una ruta compartida de WSL, copieu la imatge a una carpeta local de Windows i torneu-ne a comprovar el SHA256 abans de gravar.
3. Graveu primer la imatge `minimal` del panell escollit. Expulseu la SD de manera segura, amb la consola apagada, i inseriu-la a TF1. Per la primera prova deixeu TF2 buida, sense tocar les dades de la seva targeta.
4. Arrenqueu amb bateria carregada. No connecteu encara el Heltec. Observeu pantalla i temperatura; deixeu passar almenys un minut per comprovar el possible tall de panell de l'original.
5. El perfil mínim mostra login de consola: usuari `cyberdeck` i contrasenya escollida. Necessita un teclat USB/OTG; proveu l'enumeració. No hi ha autologin root.
6. Comproveu `uname -r`, `cat /proc/device-tree/model`, `systemctl --failed`, `lsblk`, `ip link`, `upower -d` i `/sys/class/power_supply/*/uevent`. Registreu els resultats a la checklist.
7. A la consola amb mínim i SSH validats, seguiu la [instal·lació de XFCE per SSH](RG35XXSP_HEADLESS.md#pas-següent-xfce-per-ssh). Això conserva la configuració d'arrencada que ja funciona. Per apagar, executeu `sudo systemctl poweroff`.

## Escriptori

- Terminal al menú d'aplicacions o `Ctrl+Alt+T`; gestor de fitxers Thunar.
- Xarxa: applet NetworkManager o `nmtui`; si nmtui no està disponible en la instal·lació, useu `nmcli --ask device wifi connect 'SSID'`. No poseu contrasenyes Wi-Fi a l'historial d'ordres.
- Bluetooth: Blueman; valideu primer l'adaptador amb `bluetoothctl show`.
- Teclat: Configuració XFCE → Teclat → Disposició. La configuració de consola es pot adaptar amb les eines Debian després d'instal·lar `keyboard-configuration` si cal.
- Pantalla: usa el mode natiu anunciat, 640×480; no s'aplica una modeline forçada. Tema Greybird fosc, lletra 9, terminal i indicador del gestor d'energia.
- Creueta mou el cursor; codis BTN_EAST/BTN_SOUTH actuen com clic esquerre/dret, BTN_NORTH Enter, BTN_WEST Backspace, Start Super, Select Esc, L/R roda, L2 Espai i R2 Tab. La correspondència entre les etiquetes A/B/X/Y i els codis requereix `evtest` físic.
- El teclat extern conserva els seus esdeveniments. El mapper només captura el gamepad intern amb identitat 484b:14df.
- Apagada: menú de sessió o llançador «Apagar amb seguretat». Espereu l'aturada abans de retirar la SD.

La tapa no suspèn ni apaga la pantalla deliberadament: la gestió fiable resta pendent. El tancament **no estalvia bateria per si mateix**. Apagueu abans de desar la consola. CPU schedutil si disponible; pantalla inactiva a 5 minuts i DPMS a 10, pendents de validació física. No hi ha ventilador ni servei de ventilació.

No hi ha SSH accessible per defecte. Si més endavant el necessiteu, instal·leu-lo i configureu autenticació i xarxa explícitament; no depengueu d'SSH per recuperar la primera arrencada.

Un cop validada l'arrencada, podeu preparar explícitament [accés Wi-Fi i SSH sense teclat](RG35XXSP_HEADLESS.md) amb les vostres credencials locals.

Els errors posteriors a l'arrencada de systemd es desen a `/boot/logs` després de 60 segons. Un bloqueig anterior pot no deixar cap fitxer. [Recuperació i diagnosi](TROUBLESHOOTING.md).
