# K1C USB Ethernet v1.0.0

Validated USB Ethernet support for the explicitly supported 2023-generation
Creality K1C firmware/kernel ABI using the ASIX `0b95:1790` adapter in CDC-NCM
mode.

Current release verdict:

`GO -- automated and physical qualification complete.`

## Compatibility

This release is intentionally strict:

- Tested printer generation: 2023-generation Creality K1C
- SoC/board family: Ingenic X2000 K1C platform
- Kernel: `4.4.94`
- Kernel ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Adapter tested: ASIX `0b95:1790`

Tested only on a 2023-generation Creality K1C running kernel 4.4.94 with the documented module ABI. The 2025 K1C revision has not been tested; compatibility is unknown and is not claimed.

Do not use this package on unrelated printers, firmware builds, kernels, or
USB Ethernet adapters.

## Install

Copy the release tree to the printer, then run:

```sh
sh install.sh
```

Install and enable automatic Ethernet-primary startup:

```sh
sh install.sh --enable-boot
```

Disable boot integration later:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

## Runtime Package

The runtime package is in `package/`. It contains only the frozen production
modules:

```text
mii.ko     a66d280aa643319a848260e8ade6373415a61e1e07c73e16dacd33f75ac497d8
usbnet.ko  8a582cb3f480f86126dacc2b7255b45efcb4fb58d591007e6ba653bee08da85d
cdc_ncm.ko 6ff51a9ec99089245d0cad267ac83d312193bb6818f8cec6519c1983cbe8f2bc
```

The diagnostic `usbnet.ko` used during qualification is not included in the
runtime package or install archive.

## Qualification

See `RELEASE-QUALIFICATION.md`.

The corrected v1.0.0 package keeps USB Ethernet primary with route metric `50`
and keeps Wi-Fi as fallback with route metric `300` while USB is healthy. It
also reconciles same-subnet connected routes after Wi-Fi reconnects so route
lookups from the USB address continue to select `usb0`.

## Source and License

This repository includes the GPL-covered module sources used for the release
under `source/`, the final kernel config under `package/final.config`, the
toolchain record under `package/toolchain.txt`, and the Linux kernel GPL text
in `COPYING`.

## Publication Status

The release assets are prepared as a draft. Do not publish them until the
maintainer explicitly approves the completed draft and assets.
