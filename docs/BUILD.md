# Build

Copy `config/build.env.example` to a private location outside Git or export equivalent variables:

```sh
export KERNEL_DIR=/path/to/vendor/kernel
export CROSS_COMPILE=/path/to/mips-linux-gnu-
export ARCH=mips
```

Then run:

```sh
scripts/check-environment.sh --env /path/to/build.env
scripts/inspect-kernel-tree.sh --kernel-dir "$KERNEL_DIR"
scripts/build-modules.sh --env /path/to/build.env
```

The build script only requests these module targets:

- `drivers/net/mii.ko`
- `drivers/net/usb/usbnet.ko`
- `drivers/net/usb/cdc_ncm.ko`

Outputs are copied to `output/modules/` and are ignored by Git.

