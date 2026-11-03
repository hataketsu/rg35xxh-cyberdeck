# Preparació de WSL2

Comprovació d'aquesta sessió: Ubuntu 22.04.3 LTS, x86_64, kernel `6.18.54.1-microsoft-standard-WSL2`, 30 GiB de RAM i 844 GiB disponibles al sistema Linux. Directori de treball: `/home/frans/anbernic/rg35xxsp-cyberdeck`, fora de `/mnt/c`. `wsl.exe --status` confirma Ubuntu i versió predeterminada 2; la comprovació des de l'aïllament fallava, però va funcionar fora de l'aïllament.

`sudo -n true` demana contrasenya. No s'han executat `apt update`, `apt upgrade` ni instal·lacions globals amb èxit en aquesta sessió. Les eines de validació descarregades s'han extret a `work/host-tools/`, sense modificar el sistema.

En un terminal **Ubuntu WSL2** executeu:

```bash
uname -a
cat /etc/os-release
df -h .
free -h
wsl.exe --status
./scripts/setup-wsl2.sh
```

L'assistent executa `sudo apt update`, `sudo apt upgrade -y` i instal·la les dependències declarades, inclosos QEMU estàtic, binfmt, debootstrap, eines de particions virtuals, DTB, U-Boot i verificació. La contrasenya de sudo s'introdueix al terminal, mai al xat. Requereix 40 GiB lliures abans de compilar; el pipeline és més exigent que el mínim original de 20 GB.

## Un únic motor Docker

No hi ha `docker` al PATH de la sessió; tampoc s'ha trobat Docker Desktop a la ruta estàndard de Windows. Això no exclou una instal·lació en una altra ruta.

Per Windows 11, l'opció preferida és **Docker Desktop amb backend WSL2** i integració amb Ubuntu, perquè evita mantenir un daemon addicional dins d'Ubuntu. La seva instal·lació/configuració és una acció de Windows: no s'ha executat. A Docker Desktop: Settings → General → WSL 2 engine; Settings → Resources → WSL Integration → Ubuntu. No instal·leu també `docker.io` dins d'Ubuntu. [Documentació de Docker](https://docs.docker.com/desktop/features/wsl/).

Alternativa si es vol treballar íntegrament dins d'Ubuntu: Docker Engine amb systemd, seguint la [guia oficial d'Ubuntu](https://docs.docker.com/engine/install/ubuntu/). Trieu una sola opció. El pipeline requereix accés a `docker info` amb el mateix usuari que executa `build.sh`.

```bash
docker info
sudo -v
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
TARGET=rg35xxsp ./build.sh deps
```

L'entrada binfmt ha de mostrar `enabled` i flag `F`; si cal, executeu `sudo update-binfmts --enable qemu-aarch64`. No s'instal·la un contenidor privilegiat per registrar binfmt automàticament.

Si una actualització o canvi de WSL requereix reinici: deseu la feina, tanqueu tasques actives i executeu **manualment a PowerShell** `wsl --shutdown`, després torneu a obrir Ubuntu. No s'ha executat aquest reinici. Consulteu la [guia de Microsoft](https://learn.microsoft.com/windows/wsl/basic-commands).

El rootfs i l'empaquetat necessiten sudo local per a chroot, bind mounts i loop devices de **fitxers imatge nous**. El codi no rep un disc físic com a destí. Si WSL no disposa de device-mapper/loop o no pot crear els mapatges, utilitzeu un host Linux adequat; no connecteu discos físics per esquivar-ho.
