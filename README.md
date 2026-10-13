# Creality K1C USB Ethernet v1.0.3

**[Download the released v1.0.3 runtime and source archives](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3)**

Ready-to-install **prebuilt** USB Ethernet modules for the
**2023-generation Creality K1C**, Linux `4.4.94`, MIPS32_R2,
and tested ASIX USB ID `0b95:1790`. The 2025 K1C revision is
not qualified.

## Install or upgrade

See the **[current v1.0.3 installation/upgrade guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md)**.
Keep Wi-Fi SSH reachable throughout the process. The installer
**refuses** to overwrite an existing package-owned runtime; stop
and uninstall v1.0.2 first, then install v1.0.3. Save your old
working runtime archive for recovery.

The release has four downloadable files:

- `k1c-usb-ethernet-v1.0.3-runtime.tar.gz` — prebuilt, ready to install
- `k1c-usb-ethernet-v1.0.3-runtime.zip` — the same runtime in ZIP form
- `k1c-usb-ethernet-v1.0.3-source.tar.gz` — corresponding source and build scripts
- `SHA256SUMS` — archive checksums

No SDK is needed to **install** the runtime. An external compatible
vendor kernel tree and cross-compiler are needed only to **rebuild**
the modules from source.

## Receive filtering

Two independent runtime module parameters:

| Parameter | Default | Effect |
|---|---|---|
| `drop_l2_8899` | `Y` | Silently discard 0x8899 Ethernet frames |
| `rx_ipv4_only` | `N` | Opt-in IPv4/ARP/802.3-length/outer-VLAN allowlist |

This is a fixed allowlist, **not** automatic discovery of protocol
support. Strict mode can drop IPv6, LLDP, PPPoE, EAPOL and other
EtherTypes; VLAN outer tags are passed without checking inner types.
Changing a parameter through sysfs is **not persistent** after a
module reload or reboot.

Read the [filter mode instructions](docs/FILTER-MODES-v1.0.3.md)
and the [hardware test report](docs/HARDWARE-VALIDATION-2026-10-13.md).

In one two-cycle 25-second-per-mode hardware comparison,
`rx_dropped` was 25 with both switches off, 16 with the
0x8899-only filter and **0** with strict filtering. All 18 USB
gateway pings passed. Traffic volumes differed substantially;
this is evidence of frame filtering, not a throughput claim.

### Known limitations

The [Issue #1 notification-spam problem](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1)
is **separate**: v1.0.3 does not include the experimental patch
that suppresses duplicate `network connection: connected` and
speed notifications. The original reporter's AX88179B has not
been independently tested with this released binary.

The new module was physically tested and recovered using a watchdog,
but a **complete v1.0.3 installer-upgrade/reboot acceptance suite**
has not been completed.

## Documentation and release history

- [Installation and upgrade](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Filter modes](docs/FILTER-MODES-v1.0.3.md)
- [Verify release](docs/VERIFY-RELEASE.md)
- [Build from source](docs/BUILD-FROM-SOURCE.md)
- [Release history](docs/RELEASE-HISTORY.md)

The [published `v1.0.3` Git tag](https://github.com/Zaknin/Creality-K1C-ethernet-driver/tree/v1.0.3)
and its release archives are **immutable**; documentation corrections
on this maintenance branch do not modify those files.
