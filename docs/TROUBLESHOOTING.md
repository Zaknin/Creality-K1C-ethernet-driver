# Troubleshooting

These commands assume you are in the repository root on the Linux or WSL build machine unless the command uses `ssh "$PRINTER_HOST"`.

## `check-environment.sh` Fails

Check your private build config:

```sh
cat ../k1c-build.env
scripts/check-environment.sh --env ../k1c-build.env
```

Common fixes:

- Set `ARCH=mips`.
- Set `KERNEL_RELEASE=4.4.94`.
- Fix `KERNEL_DIR`.
- Fix `CROSS_COMPILE`.
- Prepare the kernel tree so it has `include/generated/utsrelease.h`, `include/generated/autoconf.h`, and `Module.symvers`.

## Kernel Tree Is `UNCONFIRMED`

Run:

```sh
. ../k1c-build.env
scripts/inspect-kernel-tree.sh --kernel-dir "$KERNEL_DIR"
```

`UNCONFIRMED` means one or more expected files or version markers were missing. Stop and inspect the tree before building. Do not assume generic Linux `4.4.94` is enough.

## Build Failed

Read the end of the build log:

```sh
tail -n 100 output/logs/build-modules.log
```

If the script says `expected built module missing`, the kernel build did not create one of the three required files.

## Module Verification Failed

Check one module manually:

```sh
file output/modules/cdc_ncm.ko
modinfo output/modules/cdc_ncm.ko
readelf -h output/modules/cdc_ncm.ko
```

`modinfo` and `readelf` may not be installed on every build machine. If `vermagic` is wrong, rebuild with the correct source tree and configuration.

## SSH To The Printer Fails

The install scripts need root SSH access. First restore normal Wi-Fi SSH access:

```sh
ssh "$PRINTER_HOST"
```

Do not continue with upload or install until this works.

## Package Upload Failed

Confirm the package exists:

```sh
ls -lh output/package/k1c-usb-ethernet-local.tar.gz
sha256sum output/package/k1c-usb-ethernet-local.tar.gz
```

Then rerun:

```sh
scripts/deploy-to-printer.sh \
  --host "$PRINTER_HOST" \
  --package output/package/k1c-usb-ethernet-local.tar.gz
```

## Modules Do Not Load

Check the printer log and loaded modules:

```sh
ssh "$PRINTER_HOST" 'dmesg | tail -n 100'
ssh "$PRINTER_HOST" 'lsmod | grep -E "^(mii|usbnet|cdc_ncm)"'
```

A load failure usually points to a source, compiler, `vermagic`, or dependency mismatch.

## `usb0` Does Not Appear

Check the interface and recent kernel messages:

```sh
ssh "$PRINTER_HOST" 'ip link show usb0'
ssh "$PRINTER_HOST" 'dmesg | tail -n 100'
```

Also check the USB adapter, cable, and adapter chipset. This project expects an adapter handled by `cdc_ncm`.

## `usb0` Has No IP Address

Check address and route state:

```sh
ssh "$PRINTER_HOST" 'ip addr show usb0'
ssh "$PRINTER_HOST" 'ip route show'
```

DHCP must be available on the Ethernet network. `runtime/start-usb-ethernet.sh` runs `udhcpc` on `usb0` when `udhcpc` is available.

## Ethernet Works But Routing Is Wrong

Check routes:

```sh
ssh "$PRINTER_HOST" 'ip route show'
```

With `KEEP_WIFI_FALLBACK=1`, `runtime/start-primary-ethernet.sh` skips replacing the default route when a Wi-Fi default route already exists.

With `KEEP_WIFI_FALLBACK=0`, `runtime/start-primary-ethernet.sh` may replace the default route with `usb0` after `usb0` has an IPv4 address.

## Printer Became Unreachable

If Wi-Fi SSH still works, disable automatic startup first:

```sh
scripts/disable-boot.sh --host "$PRINTER_HOST"
```

Then stop Ethernet manually:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/stop-usb-ethernet.sh'
```

Uninstall if needed:

```sh
scripts/uninstall-from-printer.sh --host "$PRINTER_HOST"
```

If no network path works, physical or serial recovery may be required.

## Collect A Diagnostic Report

Run:

```sh
scripts/collect-diagnostics.sh \
  --host "$PRINTER_HOST" \
  --out output/diagnostics
```

The report is saved as:

```text
output/diagnostics/printer-diagnostics.txt
```

Review the file for private IP addresses or host information before sharing it publicly.
