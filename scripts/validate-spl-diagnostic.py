#!/usr/bin/env python3
"""Reject the known pre-DRAM generic-LED dependency in a diagnostic SPL.

Consumes objdump's symbol table produced by U-Boot (spl/u-boot-spl.sym).
This is a targeted regression check, not a complete audit of pre-DRAM code.
"""

import sys
from pathlib import Path


def validate(path):
    symbols = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 5:
            symbols[fields[-1]] = line.strip()
    unsafe = {"status_led_init", "status_led_init_done"} & symbols.keys()
    if unsafe:
        raise ValueError("Unsafe generic LED dependency in SPL: " +
                         "; ".join(symbols[name] for name in sorted(unsafe)))
    for name in ("sunxi_board_init", "gpio_direction_output"):
        if name not in symbols:
            raise ValueError(f"Missing expected diagnostic SPL symbol: {name}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: validate-spl-diagnostic.py spl/u-boot-spl.sym")
    try:
        validate(sys.argv[1])
    except (OSError, ValueError) as exc:
        sys.exit(str(exc))
    print("Diagnostic SPL uses direct GPIO; generic LED function/BSS flag absent")
