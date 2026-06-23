# Package

Run:

```sh
scripts/package-local-build.sh --modules-dir output/modules --out output/package
```

The generated package contains:

- locally built `mii.ko`, `usbnet.ko`, `cdc_ncm.ko`
- runtime scripts
- generated metadata and hashes
- an install script for the printer-side package

The packaging script refuses missing modules, extra modules, private path fragments, non-module files in the module directory, and unsupported archive contents.

This locally generated package is not distributed by the project.

