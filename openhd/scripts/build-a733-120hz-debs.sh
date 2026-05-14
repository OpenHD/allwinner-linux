#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BSP_SOURCE="${BSP_SOURCE:-/opt/allwinner/allwinner-bsp}"
VERSION_SUFFIX="${VERSION_SUFFIX:-120hz1}"

cd "$ROOT"

if [ ! -d "$BSP_SOURCE" ]; then
  echo "BSP source not found: $BSP_SOURCE" >&2
  exit 1
fi

rm -rf bsp
cp -a "$BSP_SOURCE" bsp
rm -rf bsp/.git
patch -p1 -d bsp < openhd/patches/allwinner-bsp-hdmi-120hz.patch

cat > bsp/include/sunxi-autogen.h <<'HDR'
/* Generated for standalone kernel package build. */
#ifndef __SUNXI_AUTOGEN_H__
#define __SUNXI_AUTOGEN_H__
#define AW_BSP_VERSION "openhd-120hz"
#endif
HDR

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export BSP_TOP=bsp/
export KERNEL_SRC="$ROOT"
export KERNEL_SRC_DIR="$ROOT"
export LICHEE_KERN_DIR="$ROOT"
export KCFLAGS="-I$ROOT/bsp/drivers/gmac -I$ROOT/bsp/drivers/usb/host -I$ROOT/bsp/drivers/sound/platform -I$ROOT/bsp/drivers/ve/cedar-ve"

if [ ! -f .config ]; then
  if [ -f openhd/configs/a733-5.15.147-21.config ]; then
    cp openhd/configs/a733-5.15.147-21.config .config
  else
    cp /boot/config-5.15.147-21-a733 .config
  fi
fi

make olddefconfig
make prepare scripts
make -j"$(nproc)" \
  LOCALVERSION=-21-a733 \
  KDEB_PKGVERSION="5.15.147-21.${VERSION_SUFFIX}" \
  bindeb-pkg

mkdir -p ../repacked-xz
for deb in ../linux-*"5.15.147-21.${VERSION_SUFFIX}"*.deb; do
  [ -e "$deb" ] || continue
  name="$(basename "$deb" .deb)"
  work="$(mktemp -d)"
  dpkg-deb -R "$deb" "$work/pkg"
  dpkg-deb -Zxz -z6 -b "$work/pkg" "../repacked-xz/${name}_xz.deb"
  rm -rf "$work"
done
