# Latest prebuilt K1C USB Ethernet runtime — v1.0.4

**[Download the published v1.0.4 release](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.4)**

Follow the **[version-specific v1.0.4 installation/upgrade guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.4/docs/INSTALL-v1.0.4.md)** from the immutable release tag, not the historical local-build-tools installer on the default `main` branch.

The v1.0.4 release includes a verified ready-to-install runtime TAR, an equivalent ZIP, a source TAR and the SHA256SUMS checksum list. It is qualified only for the documented 2023-generation Creality K1C with Linux `4.4.94` and ASIX USB ID `0b95:1790`; the 2025 revision is not qualified.

## Upgrade precautions

v1.0.3 contains a known `cdc_ncm.ko` runtime hash-pin mismatch and may fail to install a boot hook when the root overlay is full. Use v1.0.4 instead. Do not overwrite a loaded driver or an existing install directory in place; back up the previous runtime, stop and uninstall it, then install the new verified package. Keep Wi-Fi SSH/recovery access available.

Boot-hook installation still needs writable root overlay space. Manual-only installation is possible without enabling boot integration.

See the [v1.0.4 release notes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.4/docs/RELEASE-NOTES-v1.0.4.md), [physical test record](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.4/docs/HARDWARE-ACCEPTANCE-v1.0.4.md) and [filter guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.4/docs/FILTER-MODES-v1.0.4.md).

The old `main` branch's install/build documents relate to a different, local-build-tools workflow and must not be mixed with these prebuilt release archives.
