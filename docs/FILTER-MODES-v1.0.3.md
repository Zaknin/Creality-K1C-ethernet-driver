# RX filter modes in v1.0.3 (2023 K1C, Linux 4.4.94)

v1.0.3 adds **two independently switchable** CDC-NCM RX policies.
The installer and USB-primary/DHCP/Wi-Fi-fallback logic come from
v1.0.2; the MIPS `cdc_ncm.ko` binary is replaced by the physically
tested dual-policy candidate.

## Defaults

| Parameter | Default | Action when enabled |
|---|---|---|
| `drop_l2_8899` | `Y` | Discard only EtherType `0x8899` before passing to Linux |
| `rx_ipv4_only` | `N` | Allow IPv4, ARP, 802.3 length frames, outer 802.1Q/802.1ad VLAN; silently discard other Ethernet-II EtherTypes |

The two parameters **do not detect what the Linux kernel has an
installed handler for**. The strict mode is an explicit allowlist
policy, not dynamic protocol autodetection.

## Three runtime modes

Use root SSH and leave Wi-Fi enabled. The module must have loaded
and `usb0` must be healthy.

```sh
P=/sys/module/cdc_ncm/parameters

# A: all policy filtering off (stock-like delivery behavior)
echo 0 > "$P/rx_ipv4_only"
echo 0 > "$P/drop_l2_8899"

# B: only targeted 0x8899 filtering (recommended default)
echo 0 > "$P/rx_ipv4_only"
echo 1 > "$P/drop_l2_8899"

# C: strict IPv4-only (opt-in, only if all required services still work)
echo 1 > "$P/drop_l2_8899"
echo 1 > "$P/rx_ipv4_only"

# Inspect active flags:
cat "$P/drop_l2_8899"
cat "$P/rx_ipv4_only"

# Restore recommended defaults:
echo 0 > "$P/rx_ipv4_only"
echo 1 > "$P/drop_l2_8899"
```

**Changing sysfs flags is not persistent.** On a module reload/reboot,
the module returns to the compiled defaults (`Y` / `N`).
Automatic persistence of the strict mode is intentionally not
implemented in this maintenance release, to avoid changing the
already-qualified boot and DHCP scripts.

Strict mode can suppress **IPv6**, LLDP, EAPOL/802.1X,
PPPoE, PTP and other Ethernet-II protocols. The 802.3-length
and outer VLAN tag exceptions are deliberately passed through to Linux
**without inspecting encapsulated inner protocols**: VLAN-tagged IPv6
may therefore still be delivered to the Linux network stack. The
allowlist does **not** guarantee zero drops in every network.
Keep strict mode off on networks that depend on such protocols.

## Evidence and limitations

The two-filter module was built with the Ingenic K1C kernel 4.4.94
toolchain and physically tested on a 2023-generation Creality K1C
with an ASIX USB Ethernet adapter, candidate SHA-256:

```text
f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271
```

An alternating A/B/C test with two 25-second windows per mode
recorded: no filters: 25 `rx_dropped`; 0x8899 filter only:
16 `rx_dropped`; strict: **0 `rx_dropped`**.
All six USB-interface gateway checks succeeded (18/18 ICMP),
and `rx_errors`, FIFO errors and missed counters showed no increase
in the measured windows. Packet rates differed significantly between
windows; these data demonstrate filtering, not a throughput improvement.
The automatic rollback restored the previous module and routes.

See `docs/HARDWARE-VALIDATION-2026-10-13.md` in the source tree
for individual measurements and caveats.

## Compatibility

Only 2023-generation K1C / Linux `4.4.94` /
MIPS32_R2 tested. The 2025 K1C is not qualified.
Do not install on a mismatched kernel, and do not overwrite the
known-good installation without a separate upgrade/recovery plan.

**[Issue #1 CDC-NCM notification-spam changes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1) are not included**
in the v1.0.3 binary. The RX filtering and notification-spam symptoms
must be evaluated separately, especially on an AX88179B adapter.

The documented RX results are from one lab network with EtherType
0x8899 broadcasts; the original reporter's network is not known to
have the same EtherType. The filter does not correct malformed NTBs,
actual `rx_errors`, or repeated connection/speed log messages.
