#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Exclou arbres externs, artefactes i entorns virtuals.
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find scripts rootfs image patches config -name '*.sh' -print0)
bash -n build.sh
for file in config/targets/*.conf; do bash -n "$file"; done
for file in overlay-rg35xxsp/usr/local/bin/cyberdeck-desktop overlay-rg35xxsp/usr/local/sbin/*; do bash -n "$file"; done
python3 -m unittest discover -s tests -v
python3 - <<'PY'
import ast, configparser
import xml.etree.ElementTree as ET
from pathlib import Path
for name in ['mesh-console','sp-gamepad']:
    ast.parse((Path('overlay-rg35xxsp/usr/local/bin')/name).read_text())
for p in Path('overlay-rg35xxsp').rglob('*'):
    if p.suffix == '.xml': ET.parse(p)
    if p.suffix in ('.desktop','.service','.timer','.conf') and p.is_file():
        c=configparser.ConfigParser(interpolation=None, strict=False)
        c.optionxform=str
        c.read_string(p.read_text())
        if p.suffix=='.desktop':
            assert c['Desktop Entry']['Type']=='Application', p
            assert c['Desktop Entry']['Exec'], p
print('Sintaxi Python, XML, INI, unitats i llançadors: OK')
PY
if command -v desktop-file-validate >/dev/null; then
  find overlay-rg35xxsp -name '*.desktop' -exec desktop-file-validate {} +
fi
git diff --check
