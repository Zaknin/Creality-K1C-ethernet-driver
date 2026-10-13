# Experimental K1C IPv4-only L2 allowlist

This is an **experimental extension** of the physically validated `0x8899`
filter branch, and **not** a claim that the driver can automatically query
Linux for all registered packet handlers.

## Why it is not truly automatic

On Linux 4.4 the protocol lookup and the corresponding fallback
`rx_dropped` increment occur in `net/core/dev.c`, after the CDC-NCM
receive function hands the Ethernet frame to the network stack. The
packet-type registry used for this lookup is internal to the kernel,
not a stable exported query available to an external USB module.

The practical alternative for this printer is an **opt-in allowlist**.

## Policy

Module parameters:

- `drop_l2_8899=1`: original, single-protocol filter, default **on**.
- `rx_ipv4_only=0`: additional broad filter, default **off**.

With `rx_ipv4_only=1`, accept:

- EtherType `0x0800` IPv4 (including DHCP/mDNS/IGMP over IPv4)
- EtherType `0x0806` ARP
- 802.3 length-coded frames (`type/length < 0x0600`) for the
  kernel LLC handlers
- `0x8100` 802.1Q and `0x88a8` 802.1ad outer VLAN frames, leaving
  the normal VLAN handling to the kernel

Silently discard all other **Ethernet-II** EtherTypes in the
validated CDC-NCM RX frame loop, before skb allocation. Filtered
payload bytes are still accounted for in `rx_overhead` bookkeeping
as received NTB payload.

This means IPv6, 802.1X/EAPOL, PPPoE, LLDP, PTP, 0x8899, etc. **will
not work in strict mode**. It is suitable only for a printer whose
USB Ethernet interface is intentionally used for untagged IPv4.
Neither this allowlist nor the original 0x8899 filter corrects true
RX errors, malformed CDC-NCM frames, queue overruns, or higher-layer
drops.

## Runtime controls (after candidate module is loaded)

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only

# Expand from targeted filtering to strict IPv4-only filtering
echo 1 > /sys/module/cdc_ncm/parameters/rx_ipv4_only

# Restore only the hardware-validated targeted 0x8899 filtering
echo 0 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

When strict mode is on, `drop_l2_8899=0` does **not** restore 0x8899:
the strict allowlist also rejects it.

## Next verification gate

On the Ubuntu build VM, check out this **separate branch** and run:

```sh
python3 tests/test_cdc_ncm_8899_filter.py
scripts/check-environment.sh --env <your-actual-env-file>
scripts/build-modules.sh --env <your-actual-env-file>
scripts/verify-modules.sh --modules-dir <built-module-dir> --kernel-release 4.4.94
```

Do not blindly overwrite the verified `cdc_ncm.ko` or the installed
printer boot files. Use a new build/output directory and compare the
SHA-256 hash of the experimental binary. Physical test only after
the native regression and cross-build succeed.

The existing `0x8899` branch passed hardware A/B testing
with 1 vs 44 `rx_dropped` (equal aggregate 50s windows) and a
10/10 USB-IPv4 ping test. **Those measurements do not yet apply
to this broader experimental branch.**
