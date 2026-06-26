# Source and GPL Compliance

This release includes GPL-covered Linux kernel modules. The corresponding
module sources used for the shipped binaries are included in `source/`:

- `source/mii.c`
- `source/usbnet.c`
- `source/cdc_ncm.c`
- `source/Makefile`
- `source/Module.symvers.known-good`

The final kernel configuration used for compatibility records is included as
`package/final.config`.

Compatibility records apply only to the tested hardware and ABI:

Tested only on a 2023-generation Creality K1C running kernel 4.4.94 with the documented module ABI. The 2025 K1C revision has not been tested; compatibility is unknown and is not claimed.

The toolchain record is included as `package/toolchain.txt`.

The GPL license text from the Linux kernel tree is included as `COPYING`.

The shipped runtime modules are frozen by SHA-256 in
`package/module-hashes.sha256`. Diagnostic modules used during qualification
are not part of the runtime package.

This repository does not include private lab evidence, local hostnames,
controller usernames, printer passwords, SSIDs, or local build paths.
