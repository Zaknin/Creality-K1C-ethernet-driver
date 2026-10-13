# Install the Prebuilt Driver

Use this guide with `k1c-usb-ethernet-v1.0.3-runtime.tar.gz` or
`k1c-usb-ethernet-v1.0.3-runtime.zip`.

The runtime archive already contains compiled `.ko` modules. You do not need an
SDK, compiler, kernel source tree, or build tools.

Keep **Wi-Fi SSH connected** until Ethernet and fallback recovery are verified. Do not perform the upgrade over USB Ethernet SSH: stopping the old package can disconnect that session.

For the current full procedure, including an upgrade from v1.0.2, see the [latest runtime guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md).

## 1. Download and Verify

Download one runtime archive and `SHA256SUMS` from the release page.

Verify from your computer:

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.tar.gz

## 2. Copy to the Printer

Replace `PRINTER_IP` with the current Wi-Fi address:

```sh
scp k1c-usb-ethernet-v1.0.3-runtime.tar.gz root@PRINTER_IP:/tmp/
```

## 3. Extract on the Printer

```sh
ssh root@PRINTER_IP
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.3-runtime.tar.gz
```

For ZIP users, extract the ZIP with the available unzip tool on your host or on
the printer, then copy the extracted directory to `/tmp`.

## 4. Upgrade from an Existing v1.0.1/v1.0.2 Runtime

If the prebuilt v1.0.1 or v1.0.2 runtime is already installed,
**first stop and uninstall it over Wi-Fi SSH**:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/stop-primary-ethernet.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

The uninstall removes the package directory (including state/logs)
and owned boot hook. Save any logs and keep a verified copy of
v1.0.2 before upgrading. The installer deliberately refuses to
overwrite an existing package-owned installation; there is no
in-place hot swap of the loaded modules.

Skip this step for a fresh install. Do not apply these commands to
the separate legacy `k1c-usb-ethernet-local` build-tools package.

## 5. Install Files

From the extracted directory:

```sh
cd /tmp/k1c-usb-ethernet-v1.0.3-runtime
sh ./install.sh --enable-boot
```

The installer can also be invoked by absolute path:

```sh
cd /tmp
sh /tmp/k1c-usb-ethernet-v1.0.3-runtime/install.sh --enable-boot
```

`--enable-boot` installs the boot hook so Ethernet-primary mode starts after a
reboot. It does not start Ethernet-primary mode immediately.

If the installer reports an existing package-owned installation, complete the prior stop/uninstall step before retrying. Keep Wi-Fi enabled throughout.

## 6. Start Immediately

To start without rebooting:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

This is separate from installation. It loads the modules, brings `usb0` up,
runs DHCP, starts route monitoring, prefers USB Ethernet with metric `50`, and
keeps Wi-Fi as fallback with metric `300`.

As an alternative, reboot after installing with `--enable-boot`.

## 7. Check Status

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

Check for:

- `usb0` exists.
- `usb0` has an IPv4 address.
- USB default route metric is `50`.
- Wi-Fi fallback route metric is `300`.
- Gateway lookup from the USB address uses `usb0`.
- Wi-Fi SSH remains available.

Useful manual checks:

```sh
ip addr show usb0
ip addr show wlan0
ip route
ip route get 8.8.8.8
```

If `ethernet-failover-status.sh` shows `usb0.router` and `usb0.ip`, check:

```sh
ip route get "$(cat /usr/data/k1c-usb-ethernet/vendor-native-known-good/state/usb0.router)" \
  from "$(cat /usr/data/k1c-usb-ethernet/vendor-native-known-good/state/usb0.ip)"
```

## 8. Verify the New Receive Filtering Controls

With the new module loaded:

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

Expected defaults: `Y` and `N`, respectively. These settings are
writable at runtime but reset after a module reload/reboot.
Read [FILTER-MODES-v1.0.3.md](FILTER-MODES-v1.0.3.md) before trying
the strict IPv4-only policy; it can discard important Ethernet protocols.

**Important:** these RX filters are separate from the still-unfixed
duplicate `cdc_ncm` connection/speed notification issue (#1).

## 9. Stop, Disable, or Uninstall

Stop Ethernet-primary mode:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
```

Disable boot integration:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

Uninstall:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

## 10. Wi-Fi Recovery

If USB Ethernet fails, reconnect over Wi-Fi SSH, disable boot, and uninstall the new runtime if required. You can then reinstall a saved verified v1.0.2 runtime. The v1.0.3 module has passed focused hardware A/B/C filtering tests, but a complete packaged installer-upgrade/reboot qualification remains outstanding. Do not disable Wi-Fi before confirming both normal operation and recovery.
 SHA256SUMS | sha256sum -c -
```

This verifies just the TAR if you downloaded the TAR and `SHA256SUMS`, not every other archive listed in the manifest. ZIP users can similarly select the ZIP entry. Only continue when the selected archive reports `OK`.

## 2. Copy to the Printer

Replace `PRINTER_IP` with the current Wi-Fi address:

```sh
scp k1c-usb-ethernet-v1.0.3-runtime.tar.gz root@PRINTER_IP:/tmp/
```

## 3. Extract on the Printer

```sh
ssh root@PRINTER_IP
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.3-runtime.tar.gz
```

For ZIP users, extract the ZIP with the available unzip tool on your host or on
the printer, then copy the extracted directory to `/tmp`.

## 4. Install Files

From the extracted directory:

```sh
cd /tmp/k1c-usb-ethernet-v1.0.3-runtime
sh ./install.sh --enable-boot
```

The installer can also be invoked by absolute path:

```sh
cd /tmp
sh /tmp/k1c-usb-ethernet-v1.0.3-runtime/install.sh --enable-boot
```

`--enable-boot` installs the boot hook so Ethernet-primary mode starts after a
reboot. It does not start Ethernet-primary mode immediately.

The installer refuses an existing package-owned installation. For upgrade from
v1.0.1, keep Wi-Fi connected, stop Ethernet-primary mode, uninstall v1.0.1, and
then install v1.0.3.

## 5. Start Immediately

To start without rebooting:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

This is separate from installation. It loads the modules, brings `usb0` up,
runs DHCP, starts route monitoring, prefers USB Ethernet with metric `50`, and
keeps Wi-Fi as fallback with metric `300`.

As an alternative, reboot after installing with `--enable-boot`.

## 6. Check Status

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

Check for:

- `usb0` exists.
- `usb0` has an IPv4 address.
- USB default route metric is `50`.
- Wi-Fi fallback route metric is `300`.
- Gateway lookup from the USB address uses `usb0`.
- Wi-Fi SSH remains available.

Useful manual checks:

```sh
ip addr show usb0
ip addr show wlan0
ip route
ip route get 8.8.8.8
```

If `ethernet-failover-status.sh` shows `usb0.router` and `usb0.ip`, check:

```sh
ip route get "$(cat /usr/data/k1c-usb-ethernet/vendor-native-known-good/state/usb0.router)" \
  from "$(cat /usr/data/k1c-usb-ethernet/vendor-native-known-good/state/usb0.ip)"
```

## 7. Stop, Disable, or Uninstall

Stop Ethernet-primary mode:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
```

Disable boot integration:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

Uninstall:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

## 8. Wi-Fi Recovery

If USB Ethernet fails, reconnect over Wi-Fi SSH and run the stop or uninstall
commands above. Do not disable Wi-Fi until the Ethernet path and recovery path
are proven.
