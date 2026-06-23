# Package The Local Build

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
