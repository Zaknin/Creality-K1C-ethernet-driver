# Issue #1 field-test request (v1.0.3)

This is a focused test plan for the maintainer and
[original AX88179B reporter](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1).
The reporter saw **two distinct symptoms** with v1.0.2:

1. `rx_dropped` increasing by roughly one frame per 2–3 seconds.
2. Duplicate `cdc_ncm` connection and 1000 Mbps speed notifications
   roughly every 128 ms, flooding the printer's small syslog.

**v1.0.3 includes a fix for one possible source of RX drops, not
the duplicate-notification patch.** The default filter is specific
to EtherType 0x8899; we have not confirmed the reporter's network
has that EtherType.

## Safe test setup

- Confirm a 2023-generation K1C running Linux `4.4.94`;
  note the actual adapter name and `lsusb` VID:PID.
- Use the **[published v1.0.3 runtime](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3)**,
  with `SHA256SUMS`; do not use an ad hoc `.ko` replacement.
- Keep **Wi-Fi SSH** accessible. The prebuilt installer refuses to
  overwrite an old package-owned installation. Use the
  [upgrade instructions](LATEST-RUNTIME.md) to stop/uninstall v1.0.2
  and install v1.0.3 safely.
- Save diagnostic logs you care about before uninstalling v1.0.2;
  its package-owned directory and state/logs will be removed.

## What to measure after installing

Check active v1.0.3 module settings:

```sh
uname -r
lsusb | grep -i '0b95:1790'
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
ip -4 route
```

Expected defaults `Y` (targeted 0x8899 filter on) and `N`
(strict policy off). A switch not present suggests the old module
is still loaded.

Record before/after RX statistics over 60 seconds:

```sh
for k in rx_packets rx_dropped rx_errors; do
  printf '%s=' "$k"
  cat /sys/class/net/usb0/statistics/"$k"
done

sleep 60

for k in rx_packets rx_dropped rx_errors; do
  printf '%s=' "$k"
  cat /sys/class/net/usb0/statistics/"$k"
done
```

Inspect the **separate notification symptom**:

```sh
dmesg | grep -E 'cdc_ncm.*(network connection|downlink|uplink)' | tail -n 25
cat /sys/class/net/usb0/carrier
```

Report whether the repeated `connected`/link-speed messages
continue at a similar cadence (don't assume filtering stopped them).
Check gateway ping, DHCP/route status, SSH and ordinary printing.

**Optional** (only if the network is intended to use untagged IPv4
without IPv6/EAPOL/PPPoE/LLDP dependencies): try strict mode to
compare the 60-second `rx_dropped` delta:

```sh
echo 1 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
# Run the same statistics and network checks, then return:
echo 0 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

This allowlist passes VLAN-tagged frames and 802.3-length frames
without inspecting their encapsulated protocol, so it is not a
perfect zero-drop guarantee. Toggles revert to their defaults
after reboot.

## Feedback requested in Issue #1

Please include: printer kernel, adapter model/USB ID, v1.0.3
installation result, loaded parameter values, before/after
`rx_dropped` and `rx_errors`, whether duplicate notifications
persist, and any loss of network/printing. Redact identifying
network addresses/credentials if sharing public logs.

The issue stays **open** until the reporter confirms the result
or we separately qualify a duplicate-notification fix.
