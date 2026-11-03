# RG35XXSP Debian Cyberdeck

Port experimental de `hataketsu/rg35xxh-cyberdeck` per a **RG35XXSP**. Debian 13 ARM64, perfil mínim per provar l'arrencada i perfil XFCE/LightDM amb Meshtastic USB/BLE.

**Estat a 3 de novembre de 2026:** imatges SP **standard minimal i desktop** compilades i validades estructuralment, amb SHA256 verificats. Debian 13 ARM64, Linux 7.0.2 i Meshtastic 2.7.11; desktop amb XFCE/LightDM. **Arrencada i totes les funcions físiques PENDENTS.** És un port experimental.

Les dues imatges són a `dist/rg35xxsp-cyberdeck-standard-{minimal,desktop}-e807755.img.xz`. Vegeu [rutes, sumes i resultats](docs/IMPLEMENTATION_STATUS.md#4-imatges-i-sha256). Comenceu la prova física amb el perfil mínim en una microSD nova.

| Objectiu | Pantalla | Selecció |
|---|---|---|
| RG35XXSP | Estàndard | `TARGET=rg35xxsp PANEL=standard` |
| RG35XXSP | V2 | `TARGET=rg35xxsp PANEL=v2` |
| RG35XX H original | Estàndard / rev6 | `TARGET=rg35xxh PANEL=standard` / `rev6` |

`TARGET` continua sent `rg35xxh` si no s'especifica. Els directoris de treball i els noms d'imatge incorporen model, pantalla i perfil. El sistema SP no hereta les contrasenyes, SSH, Tailscale, gadgets USB ni els ajustos de bateria de la H. El perfil H conserva el sistema original, incloses les seves limitacions de seguretat: consulteu l'auditoria.

Comenceu amb [preparació WSL2](docs/WSL2_SETUP.md), [compilació](docs/RG35XXSP_BUILD.md) i [primer arrencament](docs/RG35XXSP_FIRST_BOOT.md). Primer proveu `PROFILE=minimal`; després `PROFILE=desktop` en un espai de treball separat. No es grava cap suport físic amb els scripts del projecte.

```bash
./scripts/check-static.sh
TARGET=rg35xxsp PANEL=standard PROFILE=minimal ./build.sh config
TARGET=rg35xxsp PANEL=standard PROFILE=minimal ./build.sh deps
# Després de preparar dependències i contrasenya segons la guia:
TARGET=rg35xxsp PANEL=standard PROFILE=minimal ./build.sh all
```

La compilació de rootfs requereix `RG_PASSWORD_HASH_FILE`, no una contrasenya predefinida. El perfil d'escriptori inicia automàticament la sessió local `cyberdeck`; sudo exigeix la contrasenya escollida. Root està bloquejat i SSH emmascarat. La sessió automàtica dona accés local a les dades a qui tingui la consola.

La tapa es detecta al DTS, però les accions de tapa i la suspensió estan desactivades. No s'han alterat voltatges, corrents de càrrega ni reguladors per a la SP. UPower manté avisos i apagada crítica; la correcció de la lectura física encara s'ha de comprovar.

Documentació:

- [Auditoria del projecte original](docs/RG35XXSP_AUDIT.md)
- [Maquinari, pantalla i fonts](docs/RG35XXSP_HARDWARE.md)
- [Meshtastic i Heltec V4](docs/MESHTASTIC_SETUP.md)
- [Resolució de problemes](docs/TROUBLESHOOTING.md)
- [Llista de proves](docs/TEST_CHECKLIST.md)
- [Informe d'aquesta sessió](docs/IMPLEMENTATION_STATUS.md)
