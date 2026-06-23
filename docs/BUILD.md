# Build Guide

This guide covers the build-machine side. Run these commands on Linux or WSL, not on the printer.

## 1. What This Step Does

The build step asks your compatible K1C kernel tree to build exactly three modules:

```text
mii.ko
usbnet.ko
cdc_ncm.ko
```

The scripts copy the finished files into `output/modules/` and save the build log in `output/logs/build-modules.log`.

## 2. Required Files And Tools

You need:

- A prepared compatible K1C kernel tree.
- A MIPS cross-compiler.
- `sh`, `make`, `find`, `sed`, `awk`, `grep`, `sort`, `sha256sum`, and `file`.
- Optional tools for later checks: `modinfo` and `readelf`.

The scripts do not download source, prepare the kernel tree, install an SDK, or install a compiler. Downloading and extracting the kernel source are explicit user actions. See [SOURCE-ACQUISITION.md](SOURCE-ACQUISITION.md).

## 3. Create `../k1c-build.env`

Run from the repository root:

```sh
cp config/build.env.example ../k1c-build.env
nano ../k1c-build.env
```

Use private paths in `../k1c-build.env`. Do not commit that file.

Example:

```sh
ARCH=mips
KERNEL_RELEASE=4.4.94
KERNEL_DIR=/path/to/extracted/kernel/tree
CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-
OUTPUT_DIR=output/modules
BUILD_LOG_DIR=output/logs
```

## 4. Build Variables

`ARCH`
: Must be `mips`.

`KERNEL_RELEASE`
: Must be `4.4.94`. The checker looks for this value in `include/generated/utsrelease.h`.

`KERNEL_DIR`
: Path to the prepared kernel tree containing `Makefile`, `drivers/net/mii.c`, `drivers/net/usb/usbnet.c`, and `drivers/net/usb/cdc_ncm.c`.

`CROSS_COMPILE`
: Compiler prefix. The script runs `${CROSS_COMPILE}gcc -dumpmachine` and expects the result to mention MIPS. The compiler is not supplied by this repository.

`OUTPUT_DIR`
: Where the finished modules are copied. Default in the example is `output/modules`.

`BUILD_LOG_DIR`
: Where the build log is written. Default in the example is `output/logs`.

## 5. Check The Environment

Run:

```sh
scripts/check-environment.sh --env ../k1c-build.env
```

This checks required host tools, `ARCH`, `KERNEL_RELEASE`, the compiler target, and prepared-kernel markers.

Common messages:

- `ARCH must be mips`: edit `ARCH=mips`.
- `KERNEL_RELEASE must be 4.4.94`: edit `KERNEL_RELEASE=4.4.94`.
- `KERNEL_DIR does not exist`: fix the kernel path.
- `cross compiler target is not visibly MIPS`: fix `CROSS_COMPILE`.
- `prepared kernel marker missing`: the kernel tree is not prepared.
- `Module.symvers missing`: prepare the tree with the vendor build process before using this repository.

## 6. Inspect The Kernel Tree

Load the build settings and inspect the tree:

```sh
. ../k1c-build.env
scripts/inspect-kernel-tree.sh --kernel-dir "$KERNEL_DIR"
```

The script checks for:

```text
Makefile
drivers/net/mii.c
drivers/net/usb/usbnet.c
drivers/net/usb/cdc_ncm.c
include/generated/utsrelease.h containing 4.4.94
```

## 7. Understand The Result

`LIKELY`
: The expected files and version marker were found. Continue only if you trust the source and toolchain.

`UNCONFIRMED`
: Some expected markers are missing. Stop and inspect the source tree before relying on it.

`INCOMPATIBLE`
: Too many markers are missing. Do not continue with that tree.

## 8. Build Modules

Run:

```sh
scripts/build-modules.sh --env ../k1c-build.env
```

The script runs `make` in `KERNEL_DIR` for:

```text
drivers/net/mii.ko
drivers/net/usb/usbnet.ko
drivers/net/usb/cdc_ncm.ko
```

If a module is not produced, the script stops with `expected built module missing`.

## 9. Expected Output

After a successful build:

```text
output/modules/mii.ko
output/modules/usbnet.ko
output/modules/cdc_ncm.ko
output/modules/build-metadata.txt
output/modules/SHA256SUMS
```

## 10. Read The Build Log

The full `make` output is saved here:

```text
output/logs/build-modules.log
```

To see the last part of the log:

```sh
tail -n 100 output/logs/build-modules.log
```

## 11. Common Build Failures

`cross compiler not executable or not on PATH`
: `CROSS_COMPILE` should be a prefix, not just a directory. For example: `/path/to/toolchain/bin/mips-linux-gnu-`.

`prepared kernel marker missing`
: Prepare the kernel tree outside this repository using the process for your source tree. Merely extracting a source archive may not create generated headers or `Module.symvers`.

`Module.symvers missing`
: The tree is not ready for module builds, or symbol versioning data has not been generated.

`expected built module missing`
: `make` ran, but the expected `.ko` file was not created. Check `output/logs/build-modules.log`.

After the build succeeds, continue with [VERIFY.md](VERIFY.md).
