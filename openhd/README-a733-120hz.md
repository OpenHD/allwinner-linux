# Radxa A733 HDMI 120 Hz kernel build

This branch tracks Radxa `allwinner-aiot-linux-5.15` and carries OpenHD build helpers for enabling HDMI 120 Hz modes on the A733 BSP display stack.

The actual display driver changes are in `openhd/patches/allwinner-bsp-hdmi-120hz.patch` and apply to Radxa's `allwinner-bsp` tree.

## Build

On the build host with `/opt/allwinner/allwinner-bsp` present:

```bash
cd /opt/allwinner/kernel-a733-120hz
./openhd/scripts/build-a733-120hz-debs.sh
```

The script:

- copies `/opt/allwinner/allwinner-bsp` into `./bsp`
- applies the HDMI 120 Hz BSP patch
- generates the minimal standalone BSP header expected by the vendor build
- exports the BSP variables needed by direct `bindeb-pkg` builds
- builds a separate `5.15.147-21-a733-120hz` kernel ABI so the stock kernel is not overwritten
- replaces the packaged `/boot/vmlinuz-*` with the raw ARM64 `Image` expected by the A733 U-Boot setup
- injects the stock `sun60i-a733-cubie-a7*.dtb` files required by the Cubie A7 boards
- repacks generated Debian packages with `xz` compression for Debian Bullseye `dpkg`

Install the resulting image package from `../repacked-xz/` on the A733 device with `dpkg -i`, verify `/boot/extlinux/extlinux.conf` contains both the stock and `-120hz` entries, then reboot.
