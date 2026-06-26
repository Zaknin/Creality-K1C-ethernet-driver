# Build From Source

Use this guide with `k1c-usb-ethernet-v1.0.1-source.tar.gz`.

The source archive does not contain compiled `.ko` modules. The compiled
reference modules are in the runtime archive.

## Current Reproducibility Status

The source archive contains the released module source files and build helper
scripts, but it still depends on external materials that are not redistributed
by this project:

- a compatible prepared Creality/Ingenic X2000 Linux `4.4.94` kernel tree;
- generated kernel headers;
- top-level kernel `Module.symvers` only if the target kernel enables
  `CONFIG_MODVERSIONS`;
- a compatible MIPS32_R2 little-endian cross-toolchain.

Because those external inputs are not included and no public checksum for the
vendor archive is recorded here, this source bundle is a coherent build
workflow, not a guarantee of byte-for-byte reproduction of the published
modules.

## Source Files

The source archive includes:

```text
source/mii.c
source/usbnet.c
source/cdc_ncm.c
source/Makefile
source/Module.symvers.known-good
```

`source/Module.symvers.known-good` is a reference export list from the three
released module sources. It is not a complete kernel top-level `Module.symvers`
and the build scripts do not use it to force a build to pass. In the qualified
K1C config, `CONFIG_MODVERSIONS` is not set, so the external module build can
start without a top-level kernel `Module.symvers`; Kbuild generates a
module-local `Module.symvers` for the three built modules during `modpost`.

The runtime reference module hashes are in:

```text
build-records/reference-module-hashes.sha256
```

## Known External Source Package

Known package name:

```text
ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

Known Baidu Pan folder:

```text
https://pan.baidu.com/s/1PxHJhv7j_oXkFTjAVNInxA
```

Access code:

```text
6svw
```

This project does not redistribute that archive. No checksum is invented here.
If you acquire the archive, record its SHA-256 before use:

```sh
sha256sum ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

## Required Prepared Kernel Tree

The build expects a kernel tree with:

```text
Makefile
include/generated/utsrelease.h
include/generated/autoconf.h
```

If `CONFIG_MODVERSIONS=y`, the tree must also provide the matching top-level
kernel `Module.symvers`. If `# CONFIG_MODVERSIONS is not set`, as in the
qualified K1C config recorded in `build-records/config-gates.txt`, a missing
top-level kernel `Module.symvers` is acceptable and the module build will write
`output/modules/Module.symvers`.

The generated release must contain:

```text
4.4.94
```

The config must match the documented ABI:

```text
4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT
```

The recorded config gates are in `build-records/config-gates.txt`.

## Build Environment

Create a private env file outside the source tree:

```sh
cat > ../k1c-build.env <<'EOF'
ARCH=mips
KERNEL_RELEASE=4.4.94
KERNEL_DIR=/path/to/prepared/vendor/kernel
CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-
SOURCE_DIR=source
OUTPUT_DIR=output/modules
BUILD_LOG_DIR=output/logs
EOF
```

Check the environment:

```sh
scripts/check-environment.sh --env ../k1c-build.env
```

Build:

```sh
scripts/build-modules.sh --env ../k1c-build.env
```

Expected outputs:

```text
output/modules/mii.ko
output/modules/usbnet.ko
output/modules/cdc_ncm.ko
output/modules/Module.symvers
output/modules/SHA256SUMS
output/modules/build-metadata.txt
output/logs/build-modules.log
```

Verify:

```sh
scripts/verify-modules.sh --modules-dir output/modules --kernel-release 4.4.94
```

## Compare With Runtime Reference Modules

Compare your local hashes:

```sh
cat output/modules/SHA256SUMS
cat build-records/reference-module-hashes.sha256
```

Hash differences can be legitimate if build paths, timestamps, generated
headers, `Module.symvers`, compiler metadata, or toolchain versions differ.
Runtime compatibility still requires the expected architecture, kernel release,
vermagic, dependency order, and successful module loading on the target printer.

## Install Self-Built Modules

This release candidate does not include a separate self-built-module installer.
To test self-built modules, replace the three files in a copy of the runtime
package, regenerate `package/module-hashes.sha256` and `package/SHA256SUMS`, and
run the full static and physical validation matrix before relying on the result.
