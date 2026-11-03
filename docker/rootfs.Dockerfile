FROM debian:trixie-slim AS archive-keyring
FROM ubuntu:jammy
COPY --from=archive-keyring /usr/share/keyrings/debian-archive-keyring.gpg /usr/share/keyrings/debian-archive-keyring.gpg
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates gpgv debootstrap qemu-user-static python3 git rsync \
    e2fsprogs dosfstools mtools parted bmap-tools xz-utils \
    device-tree-compiler u-boot-tools kmod util-linux udev \
    && rm -rf /var/lib/apt/lists/*
