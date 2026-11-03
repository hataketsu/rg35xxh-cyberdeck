#!/usr/bin/env bash
set -euo pipefail
out="${1:?fitxer de hash nou (fora de Git)}"
umask 077
(set -o noclobber; openssl passwd -6 > "$out")
