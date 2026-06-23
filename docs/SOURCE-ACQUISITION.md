# Source Acquisition

You need a kernel source tree that matches the printer closely enough to build loadable modules. Ordinary upstream Linux `4.4.94` may not match the K1C. Vendor patches, kernel configuration, exported symbols, compiler ABI, and endianness can all affect whether a module loads.

This repository cannot provide the SDK, vendor source, firmware, or a compiler. It also does not link to private or unofficial SDK downloads.

## What The Scripts Check

`scripts/check-environment.sh` expects a prepared tree with:

```text
Makefile
include/generated/utsrelease.h
include/generated/autoconf.h
Module.symvers
```

`scripts/inspect-kernel-tree.sh` looks for:

```text
Makefile
include/generated/utsrelease.h
drivers/net/mii.c
drivers/net/usb/usbnet.c
drivers/net/usb/cdc_ncm.c
```

The `utsrelease.h` file must contain `4.4.94` for the current scripts.

## About `prepare-kernel.sh`

`scripts/prepare-kernel.sh` does not prepare a kernel tree. It prints a guard message and exits. That is deliberate. The repository cannot safely guess how your vendor tree should be configured or prepared.

Prepare the kernel tree outside this repository, then run:

```sh
scripts/check-environment.sh --env ../k1c-build.env
```

If you are unsure whether a tree is compatible, stop at `UNCONFIRMED` or `INCOMPATIBLE` and inspect the source before building modules.
