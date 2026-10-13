# K1C physical A/B/C hardware report — 2026-10-13

**Candidate:** `cdc_ncm.ko` SHA-256
`f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271`.

**Setup:** Forge-K1C (2023 K1C), Linux 4.4.94, ASIX
0b95:1790, usb0 192.168.23.92/24, gateway 192.168.23.100,
Wi-Fi backup 192.168.23.169. Tests performed while using the
experimentally built dual-toggle cdc_ncm kernel module. The runtime
start/stop scripts and original on-disk modules came from the
known-good v1.0.2 runtime.

## Per-window results

Each measurement interval was 25 seconds. Each mode appeared
twice. The three-ping USB gateway check followed every interval.

| Window | drop_l2_8899 | rx_ipv4_only | rx_packets + | rx_dropped + | rx_errors + | rx_fifo_errors + | rx_missed_errors + | Ping |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| A1 stock-like | 0 | 0 | 335 | 13 | 0 | 0 | 0 | 3/3 |
| B1 targeted | 1 | 0 | 331 | 15 | 0 | 0 | 0 | 3/3 |
| C1 strict | 1 | 1 | 4,229 | 0 | 0 | 0 | 0 | 3/3 |
| A2 stock-like | 0 | 0 | 12,283 | 12 | 0 | 0 | 0 | 3/3 |
| B2 targeted | 1 | 0 | 8,985 | 1 | 0 | 0 | 0 | 3/3 |
| C2 strict | 1 | 1 | 8,874 | 0 | 0 | 0 | 0 | 3/3 |

Equal 50-second observation time per mode:
- Stock-like: 25 `rx_dropped`
- Targeted 0x8899: 16 `rx_dropped`
- Strict IPv4-only: **0** `rx_dropped`

The traffic volume varied drastically between windows. B1 had
**more** drops (15) than adjacent stock-like A1 (13), so the data
do not justify treating the targeted mode as reliably better on
*every* 25-second window. A different earlier on/off test with the
single-protocol branch showed 1 dropped with filtering on versus
44 with filtering off across two 25-second intervals per mode.
None of these tests proves improvement in application-level
delivery or throughput, or confirms that all silently suppressed
traffic was irrelevant to all deployments.

The strict filter's zero drops are consistent with preemptive
disposal of non-allowlisted Ethernet-II frames. This behavior is
**intentional policy**, not evidence that the external USB adapter
or the Linux network stack had hardware errors in the first place.

## Connectivity / rollback

- Each of six 3-ping `ping -I usb0` checks succeeded, for **18/18**
  replies.
- `rx_errors`, `rx_fifo_errors` and `rx_missed_errors` had
  **zero increase in all six windows**.
- Candidate loaded and `usb0` acquired primary route metric 50.
- The harness reset both toggles to `drop_l2_8899=Y` and
  `rx_ipv4_only=N` on test completion.
- Detached watchdog logged
  `WATCHDOG: rebooting to original boot-driver modules`.
- After reboot, the printer had original `cdc_ncm` size **17148**
  and correct default routes: `usb0` metric 50,
  `wlan0` metric 300.

## Release implications

**The dual-toggle receive policy passes initial physical K1C
validation.** Keep `drop_l2_8899=1` enabled by default, and
`rx_ipv4_only=0` disabled by default for general compatibility.
Document that strict mode can block IPv6, LLDP, EAPOL, PPPoE
and other EtherTypes. Separate notification-spam changes are not
part of the tested binary and must not be silently bundled.

A ready-to-install release requires **new runtime archives containing
this candidate binary** and consistent module hashes, manifest,
verification records, and source archive. Existing v1.0.2 runtime
binaries must not be relabeled as dual-toggle v1.0.3 binaries.
