# Creality K1C USB Ethernet v1.0.5

This is a **privacy-safe, version-only reissue** based on a sanitized Git history. The original v1.0.4 MIPS kernel modules and networking/routing scripts remain byte-identical. The installer, runtime README and package manifest identify v1.0.5, and the source archive has been regenerated from privacy-reviewed history.

## Compatibility

- Supported/tested original runtime: 2023-generation Creality K1C, Linux 4.4.94, MIPS32_R2, ASIX USB ID 0b95:1790.
- Not qualified: 2025 K1C, other kernel ABIs or USB adapter models.
- USB Ethernet primary metric 50, Wi-Fi fallback metric 300.
- RX defaults: `drop_l2_8899=Y`, `rx_ipv4_only=N`.

## Functional status

The identical driver and networking scripts passed guarded upgrade, reboot startup, USB DHCP, failover, failback and 20/20 USB pings under v1.0.4. v1.0.5 adds no kernel or network-stack functional change; it **has not** undergone separate printer-level first-install/ENOSPC/rollback testing. Automated v1.0.5 installer and source/privacy checks must pass on its final commit before publishing.

## Installation

See [v1.0.5 installation guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/privacy/v1.0.5-release/docs/INSTALL-v1.0.5.md). Back up and uninstall the previous package before installing; in-place overwrites are refused. Keep independent Wi-Fi recovery access available. A full root overlay still prevents new boot-hook installation. This release does not fix the independent AX88179B link-notification issue #1.

## Privacy and release identity

The Git commit ancestry and shipped source bundle have been reviewed to remove private network addressing and local hardware identifiers. The historical immutable releases are separate published artifacts; this new release does not change or delete their contents.

## Download files

- `k1c-usb-ethernet-v1.0.5-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.5-runtime.zip`
- `k1c-usb-ethernet-v1.0.5-source.tar.gz`
- `SHA256SUMS`

Verify the checksums before installation. These release notes do not imply that an earlier version was physically retested.
