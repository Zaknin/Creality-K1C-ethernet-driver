# Creality K1C USB Ethernet Driver

Unofficial USB Ethernet driver/runtime for the **2023-generation Creality K1C**, Linux `4.4.94`, MIPS32_R2, with tested ASIX CDC-NCM USB ID `0b95:1790`. **The 2025 revision and other kernel/adapter combinations are not qualified.**

## Latest ready-to-install release: v1.0.5

**[Download v1.0.5 — prebuilt runtime TAR/ZIP, source and SHA256SUMS](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.5)**

No SDK or compiler is required to install the released runtime. To rebuild the kernel modules from source, a compatible external Creality/Ingenic kernel tree and MIPS cross-toolchain are required.

**[v1.0.5 installation and upgrade instructions](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.5/docs/INSTALL-v1.0.5.md)** · [Release notes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.5/docs/RELEASE-NOTES-v1.0.5.md) · [Hardware scope and limitations](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.5/docs/RELEASE-NOTES-v1.0.5.md) · [Filter modes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/v1.0.5/docs/FILTER-MODES-v1.0.5.md)

**Historical defect:** v1.0.3 had an installation/startup defect: its startup script expects an outdated CDC-NCM module hash; a full root overlay may also interrupt boot-hook installation. Do not recommend v1.0.3 for new installs. v1.0.5 corrects the hash pin and stages the boot hook before modifying the runtime. Older affected runtime releases were retired during repository privacy cleanup. See [Issue #2](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/2).

The installer refuses to overwrite an existing package-owned runtime. **This is not an in-place upgrade**: back up, stop and uninstall the old runtime before installing the new one. Preserve independent Wi-Fi management access while testing and upgrading.

### Features

- Prebuilt `mii.ko`, `usbnet.ko` and `cdc_ncm.ko` modules for the qualified kernel.
- USB Ethernet primary route (metric `50`) with Wi-Fi fallback (metric `300`).
- DHCP recovery after cable/link return and startup after reboot on the qualified printer.
- Configurable RX filtering: `drop_l2_8899=Y` by default, `rx_ipv4_only=N` by default. Strict filtering may block IPv6 and other L2 protocols; parameter changes are not persistent.
- SHA-256 verified release assets, deterministic archive generation and automatic checks against private network identifiers in the source bundle.

The identical v1.0.4 runtime modules and networking scripts passed a guarded physical upgrade, reboot startup and link failover/failback on one supported K1C. v1.0.5 is a version-only privacy-safe reissue and was not separately physically retested. A physical clean installation, deliberately induced overlay-full condition and forced boot-watchdog rollback were **not** qualified. The independent [AX88179B duplicate notification issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1) remains open.

## About the default `main` branch

The default branch contains the separate historical **v0.1.1 local build-tools** lineage, **not** the prebuilt runtime shipped as v1.0.5. Do not use the `main` branch's older installation paths or build-tools scripts as the v1.0.5 runtime installer.

Use the immutable [v1.0.5 source tag](https://github.com/Zaknin/Creality-K1C-ethernet-driver/tree/v1.0.5) for the corresponding runtime source and the [release-maintenance branch](https://github.com/Zaknin/Creality-K1C-ethernet-driver/tree/release/v1.0.3-rc1) for historical runtime reference (new feature work starts from v1.0.5). The distinct build-tools and runtime histories are deliberately not merged.

## Licensing and disclaimer

This project is independent and unofficial, with no vendor affiliation. Historical build-tools scripts are licensed under [MIT](LICENSE); distributed kernel-derived sources/modules retain applicable licensing obligations. See `COPYING` and `LICENSE.md` in the runtime release, and [DISCLAIMER.md](DISCLAIMER.md) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for the historical build-tools branch.
