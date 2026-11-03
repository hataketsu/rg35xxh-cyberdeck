# Primer arrencament

**No existeix encara una imatge produïda en aquesta sessió.** Apliqueu aquest procediment només després d'una compilació acabada i comprovacions estructurals correctes. Totes les proves físiques són PENDENTS.

1. Conserveu la microSD original i les seves dades. Prepareu una microSD nova d'almenys 8 GB (16 GB dona marge), sense informació que calgui conservar.
2. Verifiqueu SHA256 i integritat xz. Useu una eina gràfica de gravació que permeti seleccionar una imatge pròpia i validar l'escriptura. Comproveu visualment marca/capacitat del suport de destí: gravar-lo n'esborra el contingut. No hi ha cap ordre automàtica de gravació en aquest projecte.
3. Graveu primer la imatge `minimal` del panell escollit. Expulseu la SD de manera segura, amb la consola apagada, i inseriu-la a TF1. Per la primera prova deixeu TF2 buida, sense tocar les dades de la seva targeta.
4. Arrenqueu amb bateria carregada. No connecteu encara el Heltec. Observeu pantalla i temperatura; deixeu passar almenys un minut per comprovar el possible tall de panell de l'original.
5. El perfil mínim mostra login de consola: usuari `cyberdeck` i contrasenya escollida. Necessita un teclat USB/OTG; proveu l'enumeració. No hi ha autologin root.
6. Comproveu `uname -r`, `cat /proc/device-tree/model`, `systemctl --failed`, `lsblk`, `ip link`, `upower -d` i `/sys/class/power_supply/*/uevent`. Registreu els resultats a la checklist.
7. Apagueu amb `sudo systemctl poweroff`. Després de validar el mínim, compileu i graveu separadament `desktop`. Aquest inicia LightDM directament a XFCE amb l'usuari normal; root continua bloquejat.

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

Els errors posteriors a l'arrencada de systemd es desen a `/boot/logs` després de 60 segons. Un bloqueig anterior pot no deixar cap fitxer. [Recuperació i diagnosi](TROUBLESHOOTING.md).
