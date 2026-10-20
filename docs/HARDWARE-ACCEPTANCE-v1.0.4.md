# v1.0.4 physical acceptance — 2026-10-20

## Scope

One physical 2023-generation Creality K1C with Linux `4.4.94` (MIPS32_R2) and a CDC-NCM ASIX USB adapter, USB ID `0b95:1790`. This is a single-device acceptance report, not a guarantee for other firmware or hardware. No site-specific network topology or addressing is recorded.

The exact `cdc_ncm.ko` SHA-256 is `f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271`. The `mii.ko` and `usbnet.ko` files are unchanged.

## Observed results

| Test | Result | Qualification |
|---|---|---|
| Package SHA-256 and installed modules | PASS | Extracted and installed files checked |
| Guarded upgrade from v1.0.1 to v1.0.4 | PASS | Controlled migration, not an in-place installer upgrade |
| Module load and filter parameters | PASS | `drop_l2_8899=Y`, `rx_ipv4_only=N` |
| USB carrier, DHCP acquisition | PASS | Automatic IPv4 lease on `usb0` |
| Route priority with both links available | PASS | USB metric 50, Wi-Fi metric 300 |
| Reboot autostart | PASS | `S46` launched driver, DHCP and route monitor |
| One-shot success-path boot guard | PASS | Verified runtime, removed temporary init hook |
| Physical Ethernet link disconnection | PASS | Wi-Fi fallback selected without losing management connectivity |
| Ethernet link restoration | PASS | USB DHCP recovered, Ethernet restored as preferred route |
| Post-recovery USB ping | PASS | 20/20 replies, 0% loss; recorded RX/TX error counters 0 |
| Prior known-good v1.0.1 recovery exercise | PASS | Old runtime and boot hook preserved and boot-checked separately |

## Boundaries of evidence

- No clean, blank-device first installation was performed.
- Simulated installer ENOSPC and partial-copy failures passed in CI; the physical printer was not deliberately filled to create ENOSPC.
- The boot guard's success path was tested; deliberate failure-branch automatic rollback was **not** fault-injected.
- The earlier recovery to v1.0.1 was a distinct exercise, not evidence of an induced v1.0.4 boot failure.
- No long-duration printing workload, throughput benchmark, all-fault matrix, 2025 K1C qualification or other adapter variants are claimed.
- The separate repeated link-message issue #1 is unresolved.
- `rx_dropped` is not assumed to mean lost user traffic; receive policy and unsupported L2 protocols can contribute.

## Verdict

**Physical runtime acceptance PASS for the demonstrated upgrade/reboot/failover/failback paths on the tested hardware.** Final release publication additionally requires integrity checks on the exact final archives and explicit maintainer approval.
