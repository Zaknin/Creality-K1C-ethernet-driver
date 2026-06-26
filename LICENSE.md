# License and Provenance

This release is not a single-license codebase.

`COPYING` contains the Linux kernel GPLv2 license text and must remain with the
runtime and source packages.

The copied module sources under `source/` keep their original upstream license
headers:

- `source/mii.c` is GPL-covered kernel code.
- `source/usbnet.c` is GPL-covered kernel code.
- `source/cdc_ncm.c` is dual BSD/GPL as stated in its file header.

The compiled runtime modules under `package/modules/` are built from those
kernel-derived sources. They are not MIT-licensed by this project.

The v1.0.1 source-build helper scripts under `scripts/` were adapted from the
project's v0.1.1 build-tools history, where the project-authored scripts and
documentation were released under the MIT License by the maintainer. That
license grant applies to those project-authored helper scripts and docs only;
it does not relicense kernel source, compiled kernel modules, vendor source,
firmware, SDKs, or toolchains.

External vendor kernel source, SDKs, toolchains, sysroots, and firmware are not
included in this repository or release assets. Users must obtain those materials
separately under their own applicable terms.
