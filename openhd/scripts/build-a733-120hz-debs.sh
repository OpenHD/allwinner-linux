#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BSP_SOURCE="${BSP_SOURCE:-/opt/allwinner/allwinner-bsp}"
VERSION_SUFFIX="${VERSION_SUFFIX:-120hz1}"
KERNEL_LOCALVERSION="${KERNEL_LOCALVERSION:--21-a733-120hz}"

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

make LOCALVERSION="$KERNEL_LOCALVERSION" olddefconfig
make LOCALVERSION="$KERNEL_LOCALVERSION" prepare scripts
make -j"$(nproc)" \
  LOCALVERSION="$KERNEL_LOCALVERSION" \
  KDEB_PKGVERSION="5.15.147-21.${VERSION_SUFFIX}" \
  bindeb-pkg

kernel_release="$(make -s LOCALVERSION="$KERNEL_LOCALVERSION" kernelrelease)"

mkdir -p ../repacked-xz
for deb in ../linux-*"5.15.147-21.${VERSION_SUFFIX}"*.deb; do
  [ -e "$deb" ] || continue
  name="$(basename "$deb" .deb)"
  work="$(mktemp -d)"
  dpkg-deb -R "$deb" "$work/pkg"

  if [ -f "$work/pkg/boot/vmlinuz-$kernel_release" ]; then
    install -m 0644 arch/arm64/boot/Image "$work/pkg/boot/vmlinuz-$kernel_release"

    dtb_dest="$work/pkg/usr/lib/linux-image-$kernel_release/allwinner"
    mkdir -p "$dtb_dest"
    install -m 0755 openhd/dtbs/allwinner/sun60i-a733-cubie-a7a.dtb "$dtb_dest/"
    install -m 0755 openhd/dtbs/allwinner/sun60i-a733-cubie-a7s.dtb "$dtb_dest/"
    install -m 0755 openhd/dtbs/allwinner/sun60i-a733-cubie-a7z.dtb "$dtb_dest/"
  fi

  (
    cd "$work/pkg"
    find . -type f ! -path './DEBIAN/*' -printf '%P\0' | sort -z | xargs -0 md5sum > DEBIAN/md5sums
  )

  dpkg-deb -Zxz -z6 -b "$work/pkg" "../repacked-xz/${name}_xz.deb"
  rm -rf "$work"
done
