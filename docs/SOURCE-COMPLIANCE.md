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

The toolchain record is included as `package/toolchain.txt`.

The GPL license text from the Linux kernel tree is included as `COPYING`.

The shipped runtime modules are frozen by SHA-256 in
`package/module-hashes.sha256`. Diagnostic modules used during qualification
are not part of the runtime package.

This repository does not include private lab evidence, local hostnames,
controller usernames, printer passwords, SSIDs, or local build paths.
