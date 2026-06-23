# Stop, Disable, Or Uninstall

There are four different cleanup actions. Use the smallest one that solves the problem.

## Stop Ethernet Now

This stops the current manual Ethernet session on the printer:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/stop-usb-ethernet.sh'
```

It does not remove files and does not change the boot hook.

## Disable Startup

This removes the enabled hook:

```sh
scripts/disable-boot.sh --host "$PRINTER_HOST"
```

The disabled hook remains:

```text
/etc/init.d/usb_ethernet_primary.disabled
```

The installed files remain under:

```text
/usr/data/k1c-usb-ethernet-local
```

## Uninstall From The Printer

This removes the startup hooks and the install directory:

```sh
scripts/uninstall-from-printer.sh --host "$PRINTER_HOST"
```

It removes:

```text
/etc/init.d/usb_ethernet_primary
/etc/init.d/usb_ethernet_primary.disabled
/etc/init.d/S46usb_ethernet_primary.disabled
/usr/data/k1c-usb-ethernet-local
```

## Delete Local Build Outputs

On the Linux or WSL build machine:

```sh
rm -rf output package-work
```

This removes generated local modules, reports, packages, diagnostics, and packaging scratch files. It does not affect the printer.
