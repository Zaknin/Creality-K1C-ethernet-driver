# Package The Local Build

> **Scope:** This document describes the legacy **v0.1.1 local build-tools**
> workflow in the `main` branch, **not** the prebuilt v1.0.3 release.
> Installation directories, startup scripts and runtime policies differ.
> For the current prebuilt release use the [current v1.0.3 runtime guide](LATEST-RUNTIME.md).
>
Run packaging on the Linux or WSL build machine after verification passes.

```sh
scripts/package-local-build.sh \
  --modules-dir output/modules \
  --out output/package
```

The script verifies the modules again, then creates:

```text
output/package/k1c-usb-ethernet-local.tar.gz
output/package/SHA256SUMS
```

## What The Package Contains

The archive contains:

- Your locally built `mii.ko`, `usbnet.ko`, and `cdc_ncm.ko`.
- The printer runtime scripts from `runtime/`.
- `config.conf.example`.
- `module-hashes.sha256`.
- `package-manifest.txt`.
- A short `README.txt`.

This package is generated locally. Do not commit `output/` or `package-work/` to Git.

## Check The Package Hash

From the repository root:

```sh
cat output/package/SHA256SUMS
sha256sum -c output/package/SHA256SUMS
```

The manifest uses the repository-relative path `output/package/k1c-usb-ethernet-local.tar.gz`, so run the check from the repository root.

Continue with [INSTALL.md](INSTALL.md).
