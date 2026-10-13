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

## Physical three-mode A/B/C runner

The branch contains `tests/k1c-rx-allowlist-hw-test.py`, which:
1. Requires the original K1C module to be loaded and verified with
   `module-hashes.sha256`, verifies the SHA-256 of the staged candidate,
   checks Wi-Fi fallback and stock boot hook.
2. Arms a detached watchdog that reboots into the unmodified on-disk
   original modules after 480 seconds, even if the A/B/C runner crashes.
3. Unloads the original modules using the known-good package stop
   routine, loads the candidate from the **separate test directory**, and
   starts Ethernet primary via the known-good package start routine.
4. Cycles `stock-like (0,0)` → `targeted (1,0)` →
   `strict (1,1)`, **twice**, measuring deltas over 25 seconds and
   performing a three-ping IPv4 gateway test over `usb0` after each
   interval.
5. Restores targeted-only filtering at the end; the watchdog still
   reboots the printer to the original module.

"Stock-like" here means **both filters off on the experimental module**.
This isolates filter effects within one loaded binary; it is not a
separately loaded original `cdc_ncm.ko`. The earlier unmodified
v1.0.2 baseline and 0x8899 hardware results remain available.

Stage from Ubuntu, setting `HASH` to the verified SHA-256 of this
branch's freshly cross-built `cdc_ncm.ko`. Copy both the module and the
test runner to:

```text
/usr/data/k1c-usb-ethernet/rx-allowlist-test/cdc_ncm.ko
/usr/data/k1c-usb-ethernet/rx-allowlist-test/k1c-rx-allowlist-hw-test.py
```

Then run on the printer:

```sh
T=/usr/data/k1c-usb-ethernet/rx-allowlist-test
HASH=<verified_64_character_candidate_sha256>
nohup /opt/bin/python3 -u "$T/k1c-rx-allowlist-hw-test.py" "$HASH" \
  >"$T/hardware-ab.log" 2>&1 </dev/null &
```

Read `hardware-ab.log` after ~210 seconds. **Do not execute twice.**
The watchdog will reboot the printer back to original after eight
minutes; confirm `cdc_ncm` size 17148 and normal routes afterward.

Release gate: both strict-mode windows must keep USB IPv4 working,
produce no rising RX error counters, and show reproducible benefit
over targeted mode if it is to be the new default. If strict mode
offers no measurable extra benefit, ship it as an **opt-in feature**
with targeted-only default and document what protocols strict mode
blocks.
