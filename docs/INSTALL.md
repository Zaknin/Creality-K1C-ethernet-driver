# Install

Deployment requires an explicit SSH target:

```sh
scripts/deploy-to-printer.sh --host root@PRINTER_ADDRESS --package output/package/k1c-usb-ethernet-local.tar.gz
scripts/install-on-printer.sh --host root@PRINTER_ADDRESS
```

The default install keeps boot activation disabled. Enable boot only after live validation:

```sh
scripts/enable-boot.sh --host root@PRINTER_ADDRESS
```

Disable boot again with:

```sh
scripts/disable-boot.sh --host root@PRINTER_ADDRESS
```

The disabled boot-hook name is `usb_ethernet_primary.disabled`. It is intentionally not named with an init-order prefix.

