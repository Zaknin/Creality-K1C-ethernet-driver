# Creality K1C USB Ethernet Driver v1.0.1

This release has two separate workflows.

1. **Install the prebuilt driver**
   Use the runtime archive. It already contains the compiled `mii.ko`,
   `usbnet.ko`, and `cdc_ncm.ko` modules. You do not need an SDK, compiler,
   kernel source tree, or build tools. Start with
   [docs/INSTALL-PREBUILT.md](docs/INSTALL-PREBUILT.md).

2. **Compile the driver from source**
   Use the source archive. You need a compatible prepared K1C vendor kernel
   tree, generated headers, `Module.symvers`, and a compatible MIPS toolchain.
   Use the source archive and its `docs/BUILD-FROM-SOURCE.md` guide.

## Supported Hardware

This project has been physically tested only on a 2023-generation Creality K1C
running kernel `4.4.94` with module ABI/vermagic
`4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`.

The tested USB Ethernet adapter is ASIX USB ID `0b95:1790`.

The 2025 K1C revision has not been tested. Compatibility with the 2025 revision
is unknown and is not claimed.

See [docs/SUPPORTED-HARDWARE.md](docs/SUPPORTED-HARDWARE.md) before installing.

## Runtime Installation Requirements

- Root SSH access to the printer.
- Wi-Fi left enabled during installation and testing.
- The supported USB Ethernet adapter and Ethernet cable connected.
- The `v1.0.1-runtime` archive and matching `SHA256SUMS`.

Installing files does not automatically start Ethernet-primary mode. Start it
explicitly after installation, or reboot after enabling boot integration.

## Release State

`v1.0.1` is a local release candidate pending physical validation. It fixes the
installer path-resolution defect found in `v1.0.0` and separates prebuilt
runtime packaging from source/build packaging. The production module binaries
are intended to remain byte-identical to `v1.0.0`.

See [docs/RELEASE-HISTORY.md](docs/RELEASE-HISTORY.md) for upgrade guidance.
