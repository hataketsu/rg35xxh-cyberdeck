#!/usr/bin/env python3
"""Comprovacions de contingut d'un rootfs SP; no executa ni mostra credencials."""
import os
from pathlib import Path
import sys


def verify(root, profile):
    os_release = (root/'etc/os-release').read_text()
    if 'VERSION_ID="13"' not in os_release:
        raise ValueError('El rootfs no declara Debian 13')
    users = {line.split(':')[0]: line.split(':') for line in (root/'etc/passwd').read_text().splitlines()}
    shadow = {line.split(':')[0]: line.split(':')[1] for line in (root/'etc/shadow').read_text().splitlines()}
    if users.get('cyberdeck', ['', '', '0'])[2] == '0':
        raise ValueError('Falta usuari normal cyberdeck')
    if not shadow.get('root', '').startswith(('!', '*')):
        raise ValueError('Root no està bloquejat')
    if not shadow.get('cyberdeck', '').startswith('$6$'):
        raise ValueError('L’usuari no té el hash requerit')
    if (root/'etc/shadow').stat().st_mode & 0o007:
        raise ValueError('Shadow accessible per altres usuaris')
    for unit in ['ssh.service', 'ssh.socket', 'suspend.target', 'hibernate.target',
                 'hybrid-sleep.target', 'suspend-then-hibernate.target']:
        if os.readlink(root/'etc/systemd/system'/unit) != '/dev/null':
            raise ValueError('Unitat no emmascarada: '+unit)
    for directory in ['usr/local', 'etc/systemd', 'etc/UPower']:
        for path in (root/directory).rglob('*'):
            if path.is_symlink():
                continue
            info = path.stat()
            if info.st_uid != 0 or info.st_mode & 0o022:
                raise ValueError('Propietat o permisos insegurs: '+str(path.relative_to(root)))
    for paragraph in (root/'var/lib/dpkg/status').read_text().split('\n\n'):
        fields = dict(line.split(': ', 1) for line in paragraph.splitlines() if ': ' in line and not line.startswith(' '))
        if fields.get('Status') == 'install ok installed' and fields.get('Architecture') not in ('arm64', 'all'):
            raise ValueError('Paquet amb arquitectura incorrecta: '+fields.get('Package', '?'))
    if (root/'usr/bin/qemu-aarch64-static').exists():
        raise ValueError('QEMU de construcció encara és al rootfs')
    if (root/'etc/machine-id').read_text().strip():
        raise ValueError('La imatge no ha de compartir un machine-id de construcció')
    if os.readlink(root/'etc/resolv.conf') != '/run/NetworkManager/resolv.conf':
        raise ValueError('DNS no apunta a NetworkManager')
    target = os.readlink(root/'etc/systemd/system/default.target')
    expected = 'graphical.target' if profile == 'desktop' else 'multi-user.target'
    if not target.endswith('/'+expected):
        raise ValueError('Target systemd no correspon al perfil')
    if profile == 'desktop':
        login = (root/'etc/lightdm/lightdm.conf.d/50-cyberdeck.conf').read_text()
        if 'autologin-user=cyberdeck\n' not in login:
            raise ValueError('Autologin incorrecte')
        agent = (root/'etc/xdg/autostart/lxpolkit.desktop').read_text()
        if 'Exec=lxpolkit\n' not in agent or any(
                line.startswith('NotShowIn=') and 'XFCE' in line for line in agent.splitlines()):
            raise ValueError('Agent Polkit no configurat per XFCE')
        if not (root/'usr/bin/lxpolkit').is_file():
            raise ValueError('Falta l’agent Polkit')
    print('Rootfs: Debian 13 ARM64, usuari normal, permisos i polítiques verificats; maquinari pendent.')


if __name__ == '__main__':
    verify(Path(sys.argv[1]), sys.argv[2])
