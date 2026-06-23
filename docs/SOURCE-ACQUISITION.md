# Getting the kernel source

You need a kernel source tree that matches the printer closely enough to build loadable modules. Ordinary upstream Linux `4.4.94` may not match the K1C. Vendor patches, kernel configuration, exported symbols, compiler ABI, and endianness can all affect whether a module loads.

This repository does not include a kernel source archive, SDK, compiler, sysroot, firmware, or prebuilt `.ko` files.

## Known Ingenic X2000 package

The known package name is:

```text
ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

This is an Ingenic X2000 Linux 4.4.94 source package. It is not included in this repository, and it is not uploaded to the project release.

This package is not confirmed to be the exact source used for every Creality K1C firmware. Users must still validate the source tree, module metadata, and runtime behavior before relying on built modules.

## Downloading from Baidu Pan

- **Baidu Pan folder:** <https://pan.baidu.com/s/1PxHJhv7j_oXkFTjAVNInxA>
- **Access code:** `6svw`
- **File to download:** `ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2`

The folder may contain several SDK revisions and supporting documents. Open the known Ingenic Halley5/X2000 Baidu share and select the exact filename above.

The Baidu folder is documented as a known Ingenic Halley5/X2000 share. The link alone does not prove exact K1C compatibility. Do not use third-party mirrors unless you can independently verify their source and integrity.

## Verifying the archive

Run these checks after downloading the exact file:

```sh
file ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

```sh
sha256sum \
  ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

```sh
tar -tjf \
  ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2 |
  head -50
```

This page does not publish a SHA-256 value because the archive was not downloaded and verified from the documented share during this release-preparation run.

## Extracting the archive

Create a work directory:

```sh
mkdir -p ~/k1c-kernel-source
```

Extract the archive:

```sh
tar -xjf \
  ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2 \
  -C ~/k1c-kernel-source
```

The archive may contain nested directories. Do not guess the extracted top-level path.

## Finding the kernel tree

Locate the USB networking source files:

```sh
find ~/k1c-kernel-source \
  -type f \
  -path '*/drivers/net/usb/cdc_ncm.c' \
  -print
```

```sh
find ~/k1c-kernel-source \
  -type f \
  -path '*/drivers/net/usb/usbnet.c' \
  -print
```

The correct `KERNEL_DIR` is the kernel root containing:

```text
Makefile
drivers/net/mii.c
drivers/net/usb/usbnet.c
drivers/net/usb/cdc_ncm.c
```

Use that directory in your private build configuration:

```sh
KERNEL_DIR=/path/to/extracted/kernel/tree
```

## Preparing the kernel tree

Source files normally include the top-level `Makefile` and driver sources such as:

```text
drivers/net/mii.c
drivers/net/usb/usbnet.c
drivers/net/usb/cdc_ncm.c
```

The current scripts also expect or check for generated build markers:

```text
include/generated/utsrelease.h
include/generated/autoconf.h
Module.symvers
```

These generated files are normally produced while configuring, preparing, or building the kernel. They must match the target printer ABI closely enough for loadable modules. Merely extracting the source archive may not produce a ready-to-build tree.

`scripts/prepare-kernel.sh` does not download or prepare a kernel tree. It prints a guard message and exits because this repository cannot safely recreate unknown Creality or Ingenic build state.

After preparing the tree outside this repository, run:

```sh
scripts/check-environment.sh --env ../k1c-build.env
```

If you are unsure whether a tree is compatible, stop at `UNCONFIRMED` or `INCOMPATIBLE` and inspect the source before building modules.

## Cross-compiler requirement

Use:

```sh
ARCH=mips
KERNEL_RELEASE=4.4.94
CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-
```

`CROSS_COMPILE` must point to a compatible MIPS compiler prefix. The compiler is not supplied by this repository. A random MIPS compiler is not guaranteed to match the printer ABI.

Do not add a toolchain download unless you can verify its source and suitability for the target printer.

## Compatibility warning

Compiling successfully does not guarantee runtime compatibility. Before installation, verify module metadata with [VERIFY.md](VERIFY.md). Keep Wi-Fi access available during first tests, and only enable boot-time Ethernet after manual runtime testing succeeds.
