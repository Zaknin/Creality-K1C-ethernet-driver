# Release History

## v1.0.3

Adds two independently switchable CDC-NCM RX policies: 0x8899 filtering ON by default, and opt-in strict IPv4-oriented allowlist OFF by default. The boot/DHCP/Wi-Fi scripts remain unchanged from v1.0.2. The new CDC-NCM module was validated by repeated hardware A/B/C tests and watchdog rollback; a complete package upgrade/reboot regression has not been separately qualified.

**Known limitation:** the independent AX88179B repeating connection/speed notification issue (#1) is not fixed by this release. Read [FILTER-MODES-v1.0.3.md](FILTER-MODES-v1.0.3.md) and [HARDWARE-VALIDATION-2026-10-13.md](HARDWARE-VALIDATION-2026-10-13.md).

To upgrade an existing v1.0.1/v1.0.2 package-owned runtime, keep Wi-Fi SSH connected, stop and uninstall the old runtime, then install v1.0.3. See [the current upgrade guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md).

## v1.0.2

Status: boot DHCP acquisition patch for the documented 2023-generation K1C
target.

Changes:

- Uses a bounded foreground boot DHCP acquisition after `usb0` carrier is
  present, matching the confirmed live recovery behavior.
- Handles the case where `usb0` exists and is `UP/LOWER_UP` but has no IPv4
  address after reboot.
- Waits for delayed carrier before attempting DHCP.
- Keeps the package DHCP hook in the boot path so successful leases still
  install USB Ethernet as primary with metric `50` and Wi-Fi fallback with
  metric `300`.
- Does not run destructive lease-failure cleanup after a boot DHCP miss, so
  existing useful USB routes are not removed by the failed acquisition attempt.
- Keeps the installation procedure and runtime module hashes unchanged.

Upgrade from v1.0.1:

1. Keep Wi-Fi SSH available.
2. Stop Ethernet-primary mode.
3. Uninstall v1.0.1.
4. Install v1.0.2.
5. Start Ethernet-primary mode explicitly or reboot if boot integration was
   enabled.

## v1.0.1

Status: qualified for the documented 2023-generation K1C target.

Changes:

- Fixes installer path resolution so `install.sh` finds `package/` beside
  itself, even when invoked by absolute or nested relative path.
- Separates the prebuilt runtime archive from the source/build archive.
- Removes maintainer-only qualification and build records from the runtime
  payload.
- Keeps the supported hardware scope unchanged.
- Keeps the three production module hashes unchanged from the physically tested
  v1.0.1 runtime candidate.
- Records completed runtime physical qualification and source-build acceptance.

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
