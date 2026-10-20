# Creality K1C USB Ethernet — v1.0.6 development candidate

**NOT RELEASED.** The latest published, supported package is [v1.0.5](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.5).

This experimental branch extends the privacy-safe v1.0.5 runtime without rebuilding or changing the K1C 4.4.94/MIPS32_R2 kernel modules. Supported hardware scope remains original-generation 2023 K1C and USB ID `0b95:1790`.

Planned v1.0.6 changes:

- Move runtime, DHCP/route and boot-hook **logs** to volatile `/run/k1c-usb-ethernet/`, with per-file best-effort soft size limiting. Runtime state files still use `/usr/data`.
- Add experimental `sh install.sh --enable-boot --boot-hook symlink`; the default `--enable-boot` continues to copy the hook until supported-printer cold boot validation is complete.
- Protect foreign/modified or dangling symlinks from accidental removal on disable/uninstall.
- Preserve Wi-Fi recovery, no in-place upgrades, installer rollback and exact module hashes.

Read [development acceptance and limitations](docs/V106-DEVELOPMENT.md) before testing. **Do not deploy symlink startup on a printer without verified independent recovery access.** Full `/overlay` can reject the symlink too; boot ordering on actual firmware is not yet qualified.

Two prior reports remain distinct: [installer/overlay Issue #2](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/2) and [ASIX AX88179B notification Issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1). The notification spam issue is not addressed by these changes.
