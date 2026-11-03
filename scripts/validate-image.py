#!/usr/bin/env python3
"""Valida MBR i signatura SPL d'un fitxer regular, sense muntar-lo."""
import pathlib
import stat
import struct
import sys


def validate(path):
    if not stat.S_ISREG(path.stat().st_mode) or path.is_symlink():
        raise ValueError('Cal un fitxer regular sense enllaços')
    with path.open('rb') as f:
        mbr = f.read(512)
        if mbr[510:] != b'\x55\xaa':
            raise ValueError('Signatura MBR absent')
        entries = [struct.unpack('<B3sB3sII', mbr[446+i*16:462+i*16]) for i in range(4)]
        a, b = entries[:2]
        if not (a[0] == 0x80 and a[2] in (0x0b, 0x0c) and b[2] == 0x83):
            raise ValueError('Tipus de particions incorrectes')
        if a[4] != 32768 or a[5] != 524288 or b[4] != a[4]+a[5]:
            raise ValueError('Límits de particions inesperats')
        if not b[5] or (b[4]+b[5])*512 > path.stat().st_size:
            raise ValueError('Partició fora del fitxer')
        if any(e[2] or e[4] or e[5] for e in entries[2:]):
            raise ValueError('Particions addicionals inesperades')
        if struct.unpack_from('<I', mbr, 440)[0] == 0:
            raise ValueError('Identificador MBR nul')
        f.seek(8196)
        if f.read(8) != b'eGON.BT0':
            raise ValueError('Signatura Allwinner SPL absent a 8 KiB')


if __name__ == '__main__':
    validate(pathlib.Path(sys.argv[1]))
    print('MBR i signatura SPL correctes. No valida arrencada ni funcionalitats.')
