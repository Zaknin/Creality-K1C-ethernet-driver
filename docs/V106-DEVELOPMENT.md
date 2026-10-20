# K1C v1.0.6 — DEVELOPMENT / NOT RELEASED

This branch modifies only userspace boot installation and logging. The qualified
2023 K1C / kernel 4.4.94 / ASIX 0b95:1790 scope remains unchanged.
The MIPS kernel modules are byte-identical to v1.0.5.

## Volatile logging

The shell scripts default to logs in `/run/k1c-usb-ethernet/`:

- `usb-ethernet.log`: module loading/unloading and link operations
- `primary-ethernet.log`: startup, DHCP, route transitions and monitor
- `primary-ethernet-boot.log`: BusyBox init boot hook

Logs no longer default to the package directory on persistent `/usr/data`.
Per-file best-effort truncation occurs after 256 KiB, rather than unbounded
retention. This is **not** a hard cap under concurrent appenders; a later
maintenance change may implement a strict size bound. Logging failure is
fail-closed; there is no silent persistent-flash fallback.

For persistent debugging only, explicitly specify both variables in the
launch environment: `K1C_ALLOW_PERSISTENT_LOGS=1 LOG_FILE=/path/to/log`.
Run the corresponding boot script with its own environment if necessary.
Note: DHCP lease/monitor state remains at the existing package `state/` path
on `/usr/data`; this change specifically moves logs, not all runtime state.

## Boot hook mode

- `--enable-boot`: retains the tested copy-based installation.
- `--enable-boot --boot-hook symlink`: stages an **absolute** symlink in the
  init directory pointing to the package-owned hook in `/usr/data`. The mode
  is experimental and must not be considered qualified until physical cold
  boots verify that `/usr/data` is available before init enumerates/hooks.

Even a symlink needs filesystem inode/directory metadata. A completely full
`/overlay` **can still cause ENOSPC**. The installer stages the hook before
changing `/usr/data`, refuses pre-existing hooks/installed directories, and
removes only resources it created if a subsequent stage fails. The uninstall
script refuses to delete unknown/modified or mismatched symlinks/hooks.

## Safety gates before first public v1.0.6 release

1. Independent static, host-simulated, and routing/CDC-NCM CI tests.
2. Validate package TAR/ZIP/source checksum reproducibility and privacy.
3. On a supported printer: backup, use Wi-Fi recovery SSH, verify tmpfs
   mount of `/run`, controlled manual startup, cold reboot of symlink mode,
   USB DHCP, fallback/failback and restart. Test disabling/uninstalling the
   package without touching unrelated init hooks.
4. Confirm boot ordering on firmware where `/overlay` is already full, and
   that no unwanted flash log writes remain. Do not delete firmware files.

If physical testing is not possible, keep the symlink mode experimental and
avoid marketing the release as solving full-overlay boot autostart.
