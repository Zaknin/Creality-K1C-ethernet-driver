# Third-Party Notices

This default `main` branch is the **v0.1.1 scripts-only build-tools** lineage; it does not vendor third-party kernel source, SDKs, toolchains, sysroots, firmware, or binary kernel modules. The independently versioned [v1.0.3 runtime release](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3) distributes **prebuilt kernel modules and corresponding module source** under their applicable licenses, but still does not distribute a vendor SDK, full kernel source, toolchain or firmware.

## Project code

Original build-tools branch scripts, tools, tests, and documentation are released under the [MIT License](LICENSE). Refer separately to the kernel/source licenses supplied with the v1.0.3 release.

## Linux kernel and modules

Linux kernel source and kernel-derived modules are governed by their applicable Linux kernel and source-file licenses, not by this repository's MIT license.

## Ingenic source package

The known Ingenic source package is:

```text
ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2
```

It is not included in the repository, not included in release assets, and not relicensed by this project. Users must review its own notices and license terms before using or redistributing it.

## Creality firmware

No Creality firmware is included or relicensed by this project.

## Toolchains and SDKs

User-provided SDKs and cross-toolchains remain under their original terms. This repository does not include or relicense them.
