# Install On The Printer

Run the host-side commands in this guide on the Linux or WSL build machine. Commands beginning with `ssh "$PRINTER_HOST"` run on the printer.

## 1. Keep Wi-Fi Connected

Do not disconnect Wi-Fi before testing Ethernet. The install step leaves automatic startup disabled so you can recover if the Ethernet setup does not work.

## 2. Set `PRINTER_HOST`

Replace `PRINTER_IP` with the printer's current Wi-Fi address:

```sh
export PRINTER_HOST=root@PRINTER_IP
```

## 3. Test SSH

```sh
ssh "$PRINTER_HOST"
```

Exit the SSH session before continuing.

## 4. Upload The Package

```sh
scripts/deploy-to-printer.sh \
  --host "$PRINTER_HOST" \
  --package output/package/k1c-usb-ethernet-local.tar.gz
```

By default the upload staging path is:

```text
/tmp/k1c-usb-ethernet-local-stage
```

The script uploads `package.tar.gz` there and checks its SHA-256 on the printer.

## 5. Install The Uploaded Package

```sh
scripts/install-on-printer.sh --host "$PRINTER_HOST"
```

The install path is:

```text
/usr/data/k1c-usb-ethernet-local
```

The install command also creates a disabled boot hook:

```text
/etc/init.d/usb_ethernet_primary.disabled
```

It does not create the enabled hook yet:

```text
/etc/init.d/usb_ethernet_primary
```

## 6. Edit Runtime Config

On the printer:

```sh
ssh "$PRINTER_HOST"
cp /usr/data/k1c-usb-ethernet-local/runtime/config.conf.example \
   /usr/data/k1c-usb-ethernet-local/runtime/config.conf
vi /usr/data/k1c-usb-ethernet-local/runtime/config.conf
```

For the first test, keep:

```sh
KEEP_WIFI_FALLBACK=1
```

Exit the SSH session before continuing.

## 7. Start Ethernet Manually

From the build machine:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/start-usb-ethernet.sh'
```

This loads `mii`, `usbnet`, and `cdc_ncm`, brings up `usb0` if present, runs DHCP with `udhcpc` when available, and prints status.

## 8. Check Status

```sh
scripts/test-connectivity.sh --host "$PRINTER_HOST"
```

Look for:

- `usb0`
- an IPv4 address on `usb0`
- `mii`, `usbnet`, and `cdc_ncm` in `lsmod`
- routes that match your test plan

## 9. Test The Ethernet IP

Find the Ethernet IP in the status output, then from another terminal:

```sh
ping ETHERNET_IP
ssh root@ETHERNET_IP
```

Do not enable boot until Wi-Fi SSH and Ethernet SSH both work.

## 10. Enable Boot

```sh
scripts/enable-boot.sh --host "$PRINTER_HOST"
```

This copies:

```text
/etc/init.d/usb_ethernet_primary.disabled
```

to:

```text
/etc/init.d/usb_ethernet_primary
```

## 11. Recovery Commands

Disable startup without uninstalling:

```sh
scripts/disable-boot.sh --host "$PRINTER_HOST"
```

Stop Ethernet manually:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/stop-usb-ethernet.sh'
```

Uninstall:

```sh
scripts/uninstall-from-printer.sh --host "$PRINTER_HOST"
```

If no network path works, you may need physical or serial recovery.
