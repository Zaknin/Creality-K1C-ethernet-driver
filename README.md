# Creality K1C USB Ethernet v1.0.3 — Release Candidate

**Not published as a GitHub Release.** This branch stages the
dual-toggle receive filter validated on a physical 2023 K1C running
Linux 4.4.94, while preserving the v1.0.2 installation/runtime
script behavior.

## New `cdc_ncm` parameters

- `drop_l2_8899=Y` (default): filter only EtherType 0x8899.
- `rx_ipv4_only=N` (default): optional strict IPv4/ARP/802.3/VLAN
  allowlist, dropping other Ethernet-II protocols.

Both parameters can be modified at runtime via
`/sys/module/cdc_ncm/parameters/`. Changes **reset to defaults**
after reloading the module or rebooting.

See [filter mode guide](docs/FILTER-MODES-v1.0.3.md) and
[hardware report](docs/HARDWARE-VALIDATION-2026-10-13.md).

## Important packaging rule

**The `package/modules/cdc_ncm.ko` tracked in this source branch is
still the original v1.0.2 binary. Do not publish or install this branch
as a runtime archive by simply repacking its tracked files.**

The release-asset assembler
[`tools/assemble-v1.0.3.py`](tools/assemble-v1.0.3.py)
explicitly replaces that file in staging with the physical-hardware
tested `cdc_ncm.ko` (SHA-256
`f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271`),
verifies the untouched `mii.ko` and `usbnet.ko`, regenerates
checksums and metadata, and emits new v1.0.3 candidate assets.
It does not modify the checked-out files, create tags, or publish.

Final production release should be published **only after** archive
validation and the desired installation/reboot regression checks.
The unrelated, unverified notification-spam patch is not included.

## Scope

Supported/physically tested: 2023-generation Creality K1C,
ASIX USB ID 0b95:1790, Linux 4.4.94, MIPS32_R2.
Compatibility with 2025-generation K1C is not claimed.
