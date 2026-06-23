# Creality K1C Ethernet Driver

Version: 0.1.0

Creality K1C Ethernet Driver is a scripts-only community toolkit for users who want to build, verify, package, deploy, manage, diagnose, roll back, and uninstall USB Ethernet support for a Creality K1C-class printer from their own compatible kernel source tree and cross-toolchain.

This repository does not include prebuilt kernel modules, a vendor SDK,
vendor kernel source, firmware, or a cross-toolchain.

This is an unofficial community project and is not affiliated with,
endorsed by, or supported by Creality.

Creality and K1C names are used only to identify compatibility. This independent project does not imply endorsement, official support, or vendor approval.

Users must obtain compatible third-party source and build tools independently through authorized channels. Generic upstream Linux 4.4.94 is not guaranteed compatible, and this project does not provide private or unofficial SDK links.

Resulting modules are compiled locally by the user. Default deployment leaves automatic boot startup disabled until Ethernet and Wi-Fi fallback testing passes.

## Scope

- Validate build-environment prerequisites without silently preparing a source tree.
- Inspect a candidate kernel tree using compatibility heuristics.
- Build only `mii.ko`, `usbnet.ko`, and `cdc_ncm.ko` into `output/modules/`.
- Verify local module metadata, dependency order, architecture, vermagic, aliases, hashes, and package layout.
- Create a local install package containing the user's generated modules, runtime scripts, and generated metadata.
- Deploy to a user-supplied printer SSH target with boot activation disabled by default.
- Provide Ethernet runtime management, Wi-Fi fallback handling, rollback, diagnostics, and uninstall support.

## Non-goals

- No prebuilt modules are included.
- No unofficial SDK download link is provided.
- No legal approval is claimed.
- No claim is made that generic upstream Linux 4.4.94 source is sufficient for a K1C printer.
- No ready-made binary driver is included.

The internal archive and package identity remains `K1C USB Ethernet Build Tools` for version `0.1.0`.

Start with [docs/SOURCE-ACQUISITION.md](docs/SOURCE-ACQUISITION.md), then follow [docs/BUILD.md](docs/BUILD.md), [docs/VERIFY.md](docs/VERIFY.md), and [docs/INSTALL.md](docs/INSTALL.md).
