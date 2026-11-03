# Meshtastic amb Heltec V4

S'ha preparat el client oficial `meshtastic[cli]==2.7.11`, Python 3 i un venv a `/opt/meshtastic/venv`. `pyserial` i `bleak` arriben com a dependències del client; BlueZ i les eines de diagnosi s'instal·len al rootfs. La versió principal està fixada; les dependències transitives es registren a `/opt/meshtastic/installed.txt`, però encara no tenen un lock amb hashes.

En aquesta sessió s'ha instal·lat el client en un venv **x86_64 de proves**, i s'ha executat `--help`. No s'ha comprovat la instal·lació al rootfs ARM64 ni cap connexió física. No s'han enviat missatges de ràdio.

Fonts: [instal·lació oficial](https://meshtastic.org/docs/software/python/cli/installation/), [CLI](https://meshtastic.org/docs/software/python/cli/), [Heltec LoRa32 V4 i V4-R8](https://meshtastic.org/docs/hardware/devices/heltec-automation/lora32/). V4 i V4-R8 requereixen firmware diferent: aquest projecte **no flasheja ni actualitza** el node. Partim d'un Heltec amb firmware Meshtastic instal·lat.

## Primera prova USB sèrie

1. Connecteu un adaptador OTG de dades a la SP i el Heltec amb un cable de dades. Comproveu primer el teclat amb el mateix adaptador. Si cal hub per teclat i ràdio, utilitzeu-ne un que no realimenti el port; l'alimentació simultània de la SP en host queda pendent.
2. Executeu `mesh-console diagnose`. Aquesta ordre enumera ports, permisos, USB i estat local Bluetooth; no obre ports ni consulta el node.
3. Preferiu `/dev/serial/by-id/...`. Si no existeix, useu el port exacte que apareix a `/dev/ttyACM*` o `/dev/ttyUSB*`; pot canviar després de reconnectar. No s'assumeix `/dev/ttyUSB0`.
4. L'usuari `cyberdeck` pertany a `dialout`. No executeu el client amb sudo ni canvieu permisos globals a 666. Si el port està ocupat, tanqueu altres clients/monitors sèrie.
5. Feu una consulta explícita:

```bash
mesh-console --port /dev/serial/by-id/IDENTIFICADOR_REAL info
mesh-console --port /dev/serial/by-id/IDENTIFICADOR_REAL nodes
```

El path anterior és un marcador: substituïu-lo pel valor real. `info` i `nodes` consulten dades del dispositiu; no invoca `--sendtext`. El firmware del node pot emetre telemetria pel seu compte: el port no modifica aquest comportament.

El llançador **Meshtastic USB / BLE** de XFCE obre un menú de terminal, permet escollir el port i consultar el node. No connecta fins que l'usuari escull una acció.

Per enviar voluntàriament un text:

```bash
mesh-console --port /dev/serial/by-id/IDENTIFICADOR_REAL send
```

Introduïu el destí `!xxxxxxxx` o `^all`, el text i finalment **ENVIAR**. Una resposta diferent cancel·la. La configuració regional/canal i l'antena han de ser adequades al node; no es configuren ni es proven transmissions automàticament. Les consultes `--info` poden mostrar claus/configuració: no compartiu la sortida completa sense revisar-la.

## BLE opcional

```bash
mesh-console diagnose
bluetoothctl show
rfkill list
/opt/meshtastic/venv/bin/meshtastic --ble-scan
mesh-console --ble NOM_O_ADRECA_REAL info
```

L'escaneig és una acció manual separada. Cal adaptador Bluetooth detectat, ràdio no bloquejada i el node anunciat; la necessitat d'aparellament depèn del firmware i de BlueZ. No hi ha un servei que intenti connectar-se per BLE automàticament. Si falla, conserveu USB com a primera via de diagnosi. No s'ha validat BLE a ARM64 ni al RTL8821CS.

## Diagnosi

```bash
lsusb
ls -l /dev/serial/by-id/
id
journalctl -b -k --no-pager | tail -100
/opt/meshtastic/venv/bin/pip check
/opt/meshtastic/venv/bin/meshtastic --help
```

`mesh-console diagnose` no activa el Bluetooth, no canvia firmware, no reinicia el node i no envia text. El timeout del wrapper és 90 segons per consulta. Un node que s'enumera però no respon requereix revisar cable, alimentació, firmware i port, no provar tots els ports indiscriminadament.
