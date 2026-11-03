#!/usr/bin/env bash
# Executar manualment en un terminal WSL2; no modifica Windows ni discos.
set -euo pipefail
[[ $(uname -r) == *WSL2* ]] || { echo 'Aquest assistent requereix WSL2'; exit 1; }
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl wget ca-certificates build-essential make gcc python3 python3-venv python3-pip debootstrap qemu-user-static binfmt-support kpartx bmap-tools parted xz-utils device-tree-compiler rsync dosfstools e2fsprogs u-boot-tools bc bison flex libssl-dev libelf-dev kmod udev file shellcheck desktop-file-utils
sudo update-binfmts --enable qemu-aarch64
printf '%s\n' "Docker: vegeu docs/WSL2_SETUP.md; no s'instal·la cap motor automàticament."
