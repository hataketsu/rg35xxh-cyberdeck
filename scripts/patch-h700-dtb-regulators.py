#!/usr/bin/env python3
"""
Patch H700 (RG35XXH/RG40XX/RGcubeXX) DTB to add regulator-always-on to
all empty AXP717 PMIC regulator nodes. Prevents the late-init "aldo3:
disabling" hang at ~31s into boot.

Usage:
  python3 patch-h700-dtb-regulators.py /path/to/sun50i-h700-anbernic-rg35xx-h.dtb

Backs up original to <name>.dtb.orig. Requires `dtc` (apt install
device-tree-compiler).

See references/h700-regulator-disable-fix.md for full context.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile


def main(dtb_path: str) -> int:
    if not os.path.exists(dtb_path):
        print(f"[err] not found: {dtb_path}", file=sys.stderr)
        return 1

    backup = dtb_path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(dtb_path, backup)
        print(f"[ok] backup: {backup}")

    with tempfile.TemporaryDirectory() as td:
        dts_path = os.path.join(td, "in.dts")
        out_dtb = os.path.join(td, "out.dtb")

        # Decompile
        r = subprocess.run(
            ["dtc", "-I", "dtb", "-O", "dts", "-o", dts_path, dtb_path],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            print(f"[err] dtc decompile failed: {r.stderr}", file=sys.stderr)
            return 2

        src = open(dts_path).read()

        # Match empty regulator nodes (aldo1..N, bldoN, cldoN, dcdcN) where
        # body is JUST a phandle = <0x..> line. Insert regulator-always-on.
        pattern = re.compile(
            r'(\t{5}(?:aldo\d|bldo\d|cldo\d|dcdc\d) \{\n)'
            r'\t{6}phandle = (<0x[0-9a-fA-F]+>);\n'
            r'\t{5}\}',
            re.MULTILINE,
        )

        matches = pattern.findall(src)
        if not matches:
            print("[info] no empty regulator nodes to patch — already done?")
            return 0

        names = [m[0].strip().split()[0] for m in matches]
        print(f"[ok] patching {len(matches)} empty regulators: {', '.join(names)}")

        def repl(m):
            return (
                f"{m.group(1)}"
                f"\t\t\t\t\t\tregulator-always-on;\n"
                f"\t\t\t\t\t\tphandle = {m.group(2)};\n"
                f"\t\t\t\t\t}}"
            )

        new_src = pattern.sub(repl, src)
        with open(dts_path, "w") as f:
            f.write(new_src)

        # Recompile
        r = subprocess.run(
            ["dtc", "-I", "dts", "-O", "dtb", "-o", out_dtb, dts_path],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            print(f"[err] dtc recompile failed: {r.stderr}", file=sys.stderr)
            return 3

        shutil.copy2(out_dtb, dtb_path)
        size = os.path.getsize(dtb_path)
        print(f"[ok] wrote patched DTB ({size} bytes) → {dtb_path}")

    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
