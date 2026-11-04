#!/usr/bin/env python3
"""Recull credencials localment; crea un perfil NetworkManager privat."""
import getpass
import hashlib
import os
from pathlib import Path
import sys
import uuid


def keyfile_string(value):
    # Escapar també els espais evita pèrdua d'espais inicials/finals en GLib.
    return (value.replace("\\", "\\\\").replace(" ", "\\s")
            .replace("\t", "\\t").replace("\r", "\\r").replace("\n", "\\n"))


def main():
    if len(sys.argv) != 2 or not sys.stdin.isatty():
        raise SystemExit("Ús en un terminal: make-wifi-profile.py FITXER.nmconnection")
    os.umask(0o077)
    target = Path(sys.argv[1]).expanduser()
    if target.exists() or target.is_symlink():
        raise SystemExit("El fitxer ja existeix; no se sobreescriu.")
    ssid = input("Wi-Fi name / SSID (exact): ")
    ssid_bytes = ssid.encode("utf-8")
    if not 1 <= len(ssid_bytes) <= 32 or any(c in ssid for c in "\r\n\0"):
        raise SystemExit("SSID no vàlid: calen entre 1 i 32 bytes UTF-8, sense salts de línia.")
    security = input("Security: 1 = WPA2 or WPA2/WPA3 mixed; 2 = WPA3-only [1]: ").strip() or "1"
    if security not in ("1", "2"):
        raise SystemExit("Opció no vàlida.")
    hidden = input("Is the network hidden? y/N: ").strip().lower()
    if hidden not in ("", "n", "no", "y", "yes"):
        raise SystemExit("Resposta no vàlida.")
    password = getpass.getpass("Wi-Fi password (hidden): ")
    if password != getpass.getpass("Repeat Wi-Fi password: "):
        raise SystemExit("Les contrasenyes no coincideixen.")
    raw_psk = len(password) == 64 and all(c in "0123456789abcdefABCDEF" for c in password)
    if any(c in password for c in "\r\n\0"):
        raise SystemExit("La contrasenya conté caràcters no admesos.")
    if security == "1":
        if not raw_psk and not 8 <= len(password.encode("utf-8")) <= 63:
            raise SystemExit("WPA2 requereix 8–63 bytes o una PSK hexadecimal de 64 caràcters.")
        # La PSK derivada també és secreta; mai imprimir-la ni posar-la a Git.
        psk = password.lower() if raw_psk else hashlib.pbkdf2_hmac(
            "sha1", password.encode("utf-8"), ssid_bytes, 4096, 32).hex()
        key_mgmt, pmf = "wpa-psk", "2"
    else:
        if not 1 <= len(password.encode("utf-8")) <= 63:
            raise SystemExit("WPA3: aquest assistent admet contrasenyes d'1–63 bytes.")
        psk = keyfile_string(password)
        key_mgmt, pmf = "sae", "3"
    # La llista decimal conserva exactament SSID amb ;, espais i UTF-8.
    ssid_key = "".join(f"{byte};" for byte in ssid_bytes)
    profile = f"""[connection]
id=cyberdeck-home
uuid={uuid.uuid4()}
type=wifi
autoconnect=true
autoconnect-retries=0

[wifi]
mode=infrastructure
ssid={ssid_key}
hidden={'true' if hidden in ('y', 'yes') else 'false'}

[wifi-security]
key-mgmt={key_mgmt}
pmf={pmf}
psk-flags=0
psk={psk}

[ipv4]
method=auto

[ipv6]
method=auto
addr-gen-mode=stable-privacy
"""
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(profile)
        stream.flush()
        os.fsync(stream.fileno())
    print("Private Wi-Fi profile saved. Tell the assistant it is ready; do not share its contents.")


if __name__ == "__main__":
    main()
