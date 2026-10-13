# Troubleshooting — v1.0.3 prebuilt runtime

This guide covers the **v1.0.3 prebuilt runtime** (not the older
`main` branch's local-build-tools workflow). For a complete safe
upgrade from v1.0.2 see the [latest runtime guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md).


## SSH or Root Access Fails

Install and recovery require root SSH. Restore Wi-Fi SSH first:

```sh
ssh root@PRINTER_IP
```

Do not continue until this works.

## Unsupported Kernel

The installer expects:

```text
4.4.94
```

Check:

```sh
uname -r
```

Other kernels are refused because the modules are built for one ABI only.

## Installer Cannot Locate `package/`

Use the v1.0.3 runtime archive. The installer expects `package/` beside
`install.sh`. Both of these forms are supported:

```sh
cd /tmp/k1c-usb-ethernet-v1.0.3-runtime
sh ./install.sh --enable-boot
```

```sh
sh /tmp/k1c-usb-ethernet-v1.0.3-runtime/install.sh --enable-boot
```

If this still fails, the archive was not fully extracted.

## Corrupt Archive or Module

Verify downloads:

```sh
sha256sum -c SHA256SUMS
```

Verify extracted runtime files:

```sh
cd k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

## Existing Installation

The v1.0.3 installer refuses an existing package-owned install tree. Keep Wi-Fi
connected, then run:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

Then install v1.0.3. This also applies to upgrades from v1.0.2; do not overwrite a loaded `.ko` in place. Keep the previous verified runtime archive for recovery.

## Adapter Not Detected

Check for the tested adapter:

```sh
lsusb | grep -i '0b95:1790'
```

Check cable, hub, and power. Other adapters are not claimed.

## `usb0` Does Not Appear

Check modules and recent kernel messages:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/status-usb-ethernet.sh
dmesg | tail -n 100
```

## DHCP Failure

Check link and route status:

```sh
ip addr show usb0
ip route
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

The Ethernet network must provide DHCP.

## Wrong Route Metrics or Gateway Uses Wi-Fi

Expected route behavior while USB is healthy:

- USB Ethernet metric `50`.
- Wi-Fi fallback metric `300`.
- Gateway lookup from the USB address selects `usb0`.

Restart Ethernet-primary mode:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

## Disable Boot or Recover Over Wi-Fi

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

If Ethernet is unusable, reconnect over Wi-Fi SSH and run the disable or
uninstall command.

## Clean Uninstall

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

## Confirm the Two RX Filters

After installing v1.0.3 and loading the driver:

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

The expected defaults are `Y` and `N`. If either file does not exist,
you may still be running an old `cdc_ncm` module. Check
`lsmod | grep cdc_ncm` and verify the installed
`package/modules/cdc_ncm.ko` SHA-256:
`f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271`.
Do not hot-replace a module that is in use.

## Receive Drops vs Actual RX Errors

`rx_dropped` can increase when the network stack encounters an
unhandled Ethernet protocol; it is **not** the same as
`rx_errors` (or proof of faulty USB hardware).

```sh
for k in rx_packets rx_dropped rx_errors rx_fifo_errors rx_missed_errors; do
  printf '%s=' "$k"; cat /sys/class/net/usb0/statistics/"$k"
done
sleep 60
for k in rx_packets rx_dropped rx_errors rx_fifo_errors rx_missed_errors; do
  printf '%s=' "$k"; cat /sys/class/net/usb0/statistics/"$k"
done
```

Compare the **differences**, not just absolute counts. If drops keep
increasing, the observed network may contain a different EtherType,
VLAN/802.3 traffic, or other causes: 0x8899 alone is not proof.

The stricter receive policy can be toggled temporarily:

```sh
echo 1 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
# Restore compatible default immediately if services stop working:
echo 0 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

Strict mode may block IPv6, LLDP, PPPoE, EAPOL/802.1X and other
protocols. It is an explicit allowlist, not auto-discovery.
Parameter changes reset on module reload/reboot.

## Repeated CDC-NCM Connection / Speed Notifications

The original
[Issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1)
reported a pair of `network connection: connected` and link-speed
messages every ~128 ms on an **AX88179B**. That is a **separate issue**
from `rx_dropped`. **v1.0.3 does not contain the experimental
notification deduplication patch**; don't claim that installing it
will stop those messages.

Collect timestamps and frequency, then compare with RX counter
deltas and link state:

```sh
dmesg | grep -E 'cdc_ncm.*(network connection|downlink|uplink)' | tail -n 30
cat /sys/class/net/usb0/carrier
```

Report your adapter's USB ID/descriptor, K1C version/kernel,
installed module hash, measured counts and actual SSH/printing
behavior in the issue. Keep logs free of credentials/private
IP addresses when posting publicly.

## Return to a Known-good Runtime

Stay connected over **Wi-Fi SSH**. Disable boot and uninstall the
v1.0.3 package using:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/disable-primary-ethernet-boot.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

Reinstall the saved, checksum-verified v1.0.2 runtime using its
original install procedure. The uninstall deletes the package-owned
directory, including logs/state. Save relevant diagnostics before
uninstalling; do not overwrite the old runtime in place.
