# Install or upgrade the latest prebuilt K1C USB Ethernet runtime (v1.0.3)

**This is the current prebuilt-release guide.** The other guides in this
`main` branch concern the historical `v0.1.1` *local build-tools*
workflow; its install paths and startup scripts are different.

- [Get the immutable v1.0.3 release](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3)
- [v1.0.3 filter modes](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/release/v1.0.3-rc1/docs/FILTER-MODES-v1.0.3.md)
- [v1.0.3 updated troubleshooting](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/release/v1.0.3-rc1/docs/TROUBLESHOOTING.md)

## Scope and precautions

Use this only for a **2023 K1C, kernel 4.4.94**, with a CDC-NCM
ASIX USB Ethernet adapter `0b95:1790`. The 2025 revision and
other kernels are untested. Run `uname -r` on the printer before
proceeding. Maintain SSH access through **Wi-Fi** throughout; stopping
or uninstalling Ethernet will interrupt a session connected over
`usb0`. Keep a copy of the known-good v1.0.2 runtime archive.

The v1.0.3 CDC-NCM filter was hardware tested. A complete v1.0.3
package-upgrade/reboot qualification has not yet been performed;
do not describe that as completed.

## 1. Download and verify (Linux/WSL build PC)

Download `SHA256SUMS` and
`k1c-usb-ethernet-v1.0.3-runtime.tar.gz` from the GitHub Release
to the same directory, then:

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.tar.gz$' SHA256SUMS | sha256sum -c -
```

Expected: `k1c-usb-ethernet-v1.0.3-runtime.tar.gz: OK`. This
command checks only the TAR, rather than requiring all three
download assets to be present.

Upload using your printer's **Wi-Fi IP**:

```sh
scp k1c-usb-ethernet-v1.0.3-runtime.tar.gz root@PRINTER_WIFI_IP:/tmp/
ssh root@PRINTER_WIFI_IP
```

The remaining commands run on the **printer** as root.

## 2. Unpack and check the runtime

```sh
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.3-runtime.tar.gz
cd k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

`mii.ko`, `usbnet.ko`, and `cdc_ncm.ko` must all report `OK`.

## 3. Stop and remove the existing package (upgrade only)

The prebuilt installer **will refuse** a package-owned installation
at `/usr/data/k1c-usb-ethernet/vendor-native-known-good`. This is
deliberate. If v1.0.2 or v1.0.1 is installed there, keep the Wi-Fi
SSH connection open and run:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/stop-primary-ethernet.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

Uninstall also disables the owned boot hook
`/etc/init.d/S46usb_ethernet_primary`. It removes the **old
package-owned install directory**, including its logs/state, so save
any diagnostics first. Do not run these commands for an unrelated
local-build-tools installation at `/usr/data/k1c-usb-ethernet-local`.

## 4. Install v1.0.3

On the printer:

```sh
sh /tmp/k1c-usb-ethernet-v1.0.3-runtime/install.sh --enable-boot
```

This installs the package under
`/usr/data/k1c-usb-ethernet/vendor-native-known-good` and
enables boot integration. It does **not** immediately start
Ethernet-primary mode. To start without rebooting:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/start-primary-ethernet.sh"
"$P/ethernet-failover-status.sh"
```

Do not disconnect Wi-Fi; verify `usb0` has an IPv4 address and
the expected USB-primary/Wi-Fi-backup routes.

## 5. Check both RX switches and communication

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
ip -4 route
ip -4 addr show usb0
```

Expected defaults: `Y` and `N`. The USB primary default route
normally has metric `50`, and Wi-Fi fallback `300`. Use your
network's actual gateway for a `ping -I usb0 -c 10 -W 2 GATEWAY_IP`
check. Run a normal printer/network workflow and, once safe,
confirm startup after reboot.

To try the opt-in strict receive policy:

```sh
echo 1 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

To restore the compatible default policy **without** reboot:

```sh
echo 0 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
echo 1 > /sys/module/cdc_ncm/parameters/drop_l2_8899
```

These sysfs changes do **not** persist across driver reloads/reboots.
Strict mode can drop IPv6, EAPOL, LLDP, PPPoE and other protocols.
Length-coded 802.3 and outer VLAN-tagged frames are passed without
inspecting inner protocols.

## 6. Compare receive drops with real errors

```sh
for k in rx_packets rx_dropped rx_errors rx_fifo_errors rx_missed_errors; do
  printf '%s=' "$k"
  cat "/sys/class/net/usb0/statistics/$k"
done
sleep 60
for k in rx_packets rx_dropped rx_errors rx_fifo_errors rx_missed_errors; do
  printf '%s=' "$k"
  cat "/sys/class/net/usb0/statistics/$k"
done
dmesg | grep -E 'cdc_ncm.*(network connection|downlink|uplink)' | tail -n 20
```

`rx_dropped` increasing because the network stack has no handler
for an EtherType is different from physical/driver `rx_errors`.
And repeated `cdc_ncm` connection/speed messages are **another
separate symptom**: the duplicate-notification patch was **not**
shipped in v1.0.3. If you are testing
[Issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1),
report the counter **deltas** and whether notification spam persists.

## Recovery / reverting to v1.0.2

If the new install fails, reconnect using **Wi-Fi SSH** and disable
v1.0.3 boot integration, then uninstall the package:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/disable-primary-ethernet-boot.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

Restore v1.0.2 from your saved **verified** runtime archive using its
original installation guide (including `--enable-boot` if desired).
Do not mix old and new `.ko` files or overwrite the old installation
in place. If neither Wi-Fi nor Ethernet SSH works, physical recovery
may be necessary.
