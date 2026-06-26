# Source and License Compliance

This project redistributes compiled Linux kernel modules in the runtime
archive and corresponding module source in the source archive.

## Redistributed Runtime Files

The runtime archive includes these compiled modules:

- `package/modules/mii.ko`
- `package/modules/usbnet.ko`
- `package/modules/cdc_ncm.ko`

The modules are built for kernel `4.4.94` and the documented K1C ABI only.

## Corresponding Source

The source archive includes:

- `source/mii.c`
- `source/usbnet.c`
- `source/cdc_ncm.c`
- `source/Makefile`
- `source/Module.symvers.known-good`
- build records under `build-records/`

The build records document the final kernel configuration, config gates,
toolchain record, source provenance, and reference module hashes.

`source/Module.symvers.known-good` is a reference export list for the three
released module sources. It is not a complete kernel top-level
`Module.symvers`, and it is not used as a substitute for a prepared kernel
tree. For the qualified K1C configuration, `CONFIG_MODVERSIONS` is not set; in
that configuration Kbuild generates the module-local `Module.symvers` during
the external module build.

## Licenses

`COPYING` contains the Linux kernel GPLv2 text.

The copied module sources retain their original file headers:

- `mii.c` is GPL-covered kernel code.
- `usbnet.c` is GPL-covered kernel code.
- `cdc_ncm.c` is dual BSD/GPL as stated in the file.

The compiled `.ko` files are not MIT-licensed by this project.

`LICENSE.md` describes the mixed-license structure and the limited provenance
of project-authored helper scripts.

## External Materials Not Included

This project does not include a vendor SDK, complete vendor kernel source tree,
toolchain, sysroot, firmware, Creality files, printer credentials, private lab
evidence, or local build paths.

Users who build from source must separately obtain a legally usable compatible
vendor kernel tree and MIPS toolchain. If their target kernel enables
`CONFIG_MODVERSIONS`, they must also provide the matching top-level kernel
`Module.symvers`. The known external source package is documented in the source
archive's `docs/BUILD-FROM-SOURCE.md`, but this project does not redistribute
that archive or invent a checksum for it.
