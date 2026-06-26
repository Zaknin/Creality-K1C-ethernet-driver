# Creality K1C USB Ethernet Driver

Unofficial USB Ethernet support for the Creality K1C printer.

## Latest Release

The latest release is:

**[K1C USB Ethernet v1.0.1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.1)**

The release provides two separate workflows.

### Install the prebuilt driver

Download one of these ready-to-install runtime packages from the v1.0.1 release:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`

These packages already contain the compiled kernel modules:

- `mii.ko`
- `usbnet.ko`
- `cdc_ncm.ko`

You do not need a compiler, SDK, or kernel source tree to install the prebuilt runtime.

Follow the installation instructions included in the runtime archive.

### Compile the driver from source

Download:

- `k1c-usb-ethernet-v1.0.1-source.tar.gz`

The source package contains the driver source, build scripts, build records, and compilation documentation.

Compilation requires an external compatible K1C kernel tree and an Ingenic-compatible MIPS cross-compiler. These external dependencies are not included in the repository or release assets.

## Supported Hardware

The prebuilt v1.0.1 runtime has been physically tested with:

- 2023-generation Creality K1C
- Linux kernel `4.4.94`
- Module vermagic:
  `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- ASIX USB Ethernet adapter ID:
  `0b95:1790`

The 2025 K1C revision has not been tested. Compatibility with that revision is unknown and is not claimed.

Keep Wi-Fi enabled during installation and initial testing so it remains available as a recovery path.

## About This Branch

The default `main` branch contains the separately published **v0.1.1 build tools**.

These tools are intended for users who want to prepare a compatible kernel source tree, compile the modules themselves, package a local build, and deploy it to the printer.

The current ready-to-install runtime is distributed through the immutable `v1.0.1` release and its annotated Git tag.

The build-tools and runtime histories are intentionally separate and have not been merged.

## Release Assets

The v1.0.1 release contains exactly four custom assets:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`
- `k1c-usb-ethernet-v1.0.1-source.tar.gz`
- `SHA256SUMS`

Verify downloaded files using `SHA256SUMS` before installation or compilation.

## Disclaimer

This is an unofficial community project and is not affiliated with, endorsed by, or supported by Creality.

Kernel-derived source and compiled kernel modules remain subject to their applicable licenses. Project-authored scripts, documentation, and tools are covered by the licensing information included with the relevant release or branch.
