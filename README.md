# Creality K1C USB Ethernet Driver

> **Known installation defect in v1.0.3 (2026-10-20):** Although its
> archives and new CDC-NCM module pass SHA-256 checks, the shipped
> `start-usb-ethernet.sh` still expects the **v1.0.2** module hash.
> Startup fails with `hash mismatch`. On printers with no free
> `/overlay` space, `install.sh --enable-boot` can also fail to
> write the boot hook and leave a partial installation. **Hold off on
> new v1.0.3 installations.** A tested, unpublished
> [v1.0.4 fix candidate](https://github.com/Zaknin/Creality-K1C-ethernet-driver/pull/4)
> addresses the hash pin and clean failure behavior; physical
> reboot/upgrade qualification is still pending. See
> [Issue #2](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/2).
>
Unofficial USB Ethernet connectivity for the **2023-generation Creality K1C**
with Linux `4.4.94` and a compatible ASIX USB adapter (`0b95:1790`).
The 2025 K1C revision has **not** been validated.

## Latest ready-to-install release: v1.0.3

**[Download K1C USB Ethernet v1.0.3](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3)**

The release provides **prebuilt** MIPS modules (`mii.ko`, `usbnet.ko`,
`cdc_ncm.ko`), a printer installer, a source archive and a `SHA256SUMS`
file. You do **not** need a compiler or SDK to install the runtime.

Choose one runtime archive:
- `k1c-usb-ethernet-v1.0.3-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.3-runtime.zip`

Download `SHA256SUMS` and verify the selected archive before installing.
The source archive is provided for users building modules themselves.

**[Current runtime installation and upgrade guide](docs/LATEST-RUNTIME.md)** ·
**[Filter modes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/release/v1.0.3-rc1/docs/FILTER-MODES-v1.0.3.md)** ·
**[Troubleshooting](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/release/v1.0.3-rc1/docs/TROUBLESHOOTING.md)**

### Receive-filter options in v1.0.3

The `cdc_ncm` module provides two runtime switches:

| Parameter | Default | Function |
|---|---|---|
| `drop_l2_8899` | `Y` (on) | Silently discard the unsupported EtherType `0x8899` before delivery to the Linux network stack |
| `rx_ipv4_only` | `N` (off) | Optional, more restrictive Ethernet receive policy: pass IPv4, ARP, 802.3-length frames and outer VLAN-tagged frames; discard other EtherTypes |

The strict policy is **not** automatic kernel protocol discovery.
It can discard IPv6, LLDP, EAPOL/802.1X, PPPoE and other traffic; VLAN
outer tags are passed without inspecting the inner protocol. Keep it off
unless you have validated your network. Sysfs changes **do not survive
module reload or reboot**.

On one 2023 K1C, two 25-second hardware windows per mode measured
25 `rx_dropped` with both filters off, 16 with only `0x8899` filtering,
and **0** with strict filtering. All 18 gateway pings succeeded and the
measured `rx_errors` did not increase. The traffic rates differed
substantially; no performance gain is claimed.

**Important for [Issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1):**
v1.0.3 addresses one *possible source* of `rx_dropped` (unhandled L2
EtherTypes). It does **not** include the separate patch for repeated
`cdc_ncm ... network connection: connected` / speed notifications.
Those two symptoms must be tested separately.

### Supported hardware and recovery

- Physically tested: 2023-generation K1C, kernel `4.4.94`,
  MIPS32_R2 ABI `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`,
  USB ID `0b95:1790`.
- Unqualified: 2025-generation K1C, other kernels/ABIs and untested
  adapter variants.
- **Keep Wi-Fi SSH working during installation, upgrades and initial
  tests.** The runtime uses USB metric `50` with Wi-Fi fallback metric
  `300` when both are healthy.
- Upgrades from v1.0.2 are **not in-place**: stop the old runtime,
  uninstall the old package-owned tree, then install v1.0.3. See the
  [upgrade guide](docs/LATEST-RUNTIME.md) and keep the v1.0.2 archive
  for recovery.
- The new driver and rollback were tested on hardware; a full fresh
  v1.0.3 installer-upgrade/reboot qualification has **not** yet been
  completed.

## About the default `main` branch

**This branch is the older v0.1.1 _build-tools_ lineage**, not the
runtime/source tree shipped with v1.0.3. Its `VERSION=0.1.1` is intentional.
The guides in `docs/BUILD.md`, `docs/CONFIGURATION.md`, and
`docs/INSTALL.md` describe that historical **locally built** workflow
with different install paths and boot hooks; they are **not** the
prebuilt v1.0.3 installation procedure.

For v1.0.3's corresponding source and installed runtime code, use
the immutable [`v1.0.3` tag](https://github.com/Zaknin/Creality-K1C-ethernet-driver/tree/v1.0.3)
and the release's source TAR. Updated explanatory documentation is
maintained on the [release-maintenance branch](https://github.com/Zaknin/Creality-K1C-ethernet-driver/tree/release/v1.0.3-rc1).
The separate build-tools and runtime histories were intentionally not merged.

## Licensing and disclaimer

This is an independent, unofficial community project with no
vendor affiliation. Original build-tools branch scripts are under the
[MIT License](LICENSE); distributed kernel-derived sources/modules
retain their own applicable licenses. See the `COPYING` and `LICENSE.md`
files in the runtime release, and this build-tools branch's
`DISCLAIMER.md` and `THIRD-PARTY-NOTICES.md`.
