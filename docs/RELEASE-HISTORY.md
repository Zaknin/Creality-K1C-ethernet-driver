# Release History

## v1.0.1

Status: local release candidate pending physical validation.

Changes:

- Fixes installer path resolution so `install.sh` finds `package/` beside
  itself, even when invoked by absolute or nested relative path.
- Separates the prebuilt runtime archive from the source/build archive.
- Removes maintainer-only qualification and build records from the runtime
  payload.
- Keeps the supported hardware scope unchanged.
- Intends to keep the three production module binaries byte-identical to
  v1.0.0.

Upgrade from v1.0.0:

1. Keep Wi-Fi SSH available.
2. Stop Ethernet-primary mode.
3. Uninstall v1.0.0.
4. Install v1.0.1.
5. Start Ethernet-primary mode explicitly or reboot if boot integration was
   enabled.

## v1.0.0

`v1.0.0` is immutable and remains published as-is. Its runtime modules were
qualified on the supported 2023-generation K1C target.

Known v1.0.0 issue:

- `install.sh` works from the extracted release root but fails when invoked by
  absolute path from a different current directory because it resolves
  `package/` relative to the caller's directory.

Do not modify the v1.0.0 tag, release notes, or release assets as part of the
v1.0.1 candidate preparation.
