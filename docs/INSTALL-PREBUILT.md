# Install the Prebuilt Driver

Use this guide with `k1c-usb-ethernet-v1.0.1-runtime.tar.gz` or
`k1c-usb-ethernet-v1.0.1-runtime.zip`.

The runtime archive already contains compiled `.ko` modules. You do not need an
SDK, compiler, kernel source tree, or build tools.

Keep Wi-Fi enabled until Ethernet and fallback recovery are verified.

## 1. Download and Verify

Download one runtime archive and `SHA256SUMS` from the release page.

Verify from your computer:

```sh
sha256sum -c SHA256SUMS
```

Only continue if the selected runtime archive reports `OK`.

## 2. Copy to the Printer

Replace `PRINTER_IP` with the current Wi-Fi address:

```sh
scp k1c-usb-ethernet-v1.0.1-runtime.tar.gz root@PRINTER_IP:/tmp/
```

## 3. Extract on the Printer

```sh
ssh root@PRINTER_IP
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.1-runtime.tar.gz
```

For ZIP users, extract the ZIP with the available unzip tool on your host or on
the printer, then copy the extracted directory to `/tmp`.

## 4. Install Files

From the extracted directory:

```sh
cd /tmp/k1c-usb-ethernet-v1.0.1-runtime
sh ./install.sh --enable-boot
```

The installer can also be invoked by absolute path:

```sh
cd /tmp
sh /tmp/k1c-usb-ethernet-v1.0.1-runtime/install.sh --enable-boot
```

`--enable-boot` installs the boot hook so Ethernet-primary mode starts after a
reboot. It does not start Ethernet-primary mode immediately.

The installer refuses an existing package-owned installation. For upgrade from
v1.0.0, keep Wi-Fi connected, stop Ethernet-primary mode, uninstall v1.0.0, and
then install v1.0.1.

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
