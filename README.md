# Creality K1C Ethernet Driver

This repository helps you build and install USB Ethernet support for a Creality K1C printer. It does not contain ready-made driver files. It gives you scripts to build, check, package, upload, install, test, disable, and remove the Ethernet setup.

This repository does not include ready-to-install kernel modules. You must build `mii.ko`, `usbnet.ko`, and `cdc_ncm.ko` from a compatible Creality K1C kernel source tree before you can install Ethernet support.

This is an unofficial community project and is not affiliated with,
endorsed by, or supported by Creality.

For source limits and redistribution notes, read [DISCLAIMER.md](DISCLAIMER.md) and [docs/SOURCE-ACQUISITION.md](docs/SOURCE-ACQUISITION.md).

## Before You Start

You need:

- A Creality K1C with root SSH access.
- A Linux build machine or WSL.
- A compatible K1C kernel source tree.
- A compatible MIPS cross-compiler.
- A USB Ethernet adapter supported by `cdc_ncm`.
- The printer still connected through Wi-Fi during the first install and tests.

Keep Wi-Fi working until Ethernet has been tested. The install step leaves automatic startup disabled so a bad Ethernet setup is less likely to lock you out.

## Which Files Do I Use?

| File | Purpose |
| --- | --- |
| `config/build.env.example` | Template for kernel and compiler paths |
| `config/runtime.conf.example` | Printer-side Ethernet and Wi-Fi fallback settings |
| `scripts/check-environment.sh` | Checks the build machine, kernel tree, and compiler |
| `scripts/inspect-kernel-tree.sh` | Checks whether the kernel tree looks compatible |
| `scripts/build-modules.sh` | Builds the three kernel modules |
| `scripts/verify-modules.sh` | Checks module type, metadata, vermagic, and hashes |
| `scripts/package-local-build.sh` | Creates the package that will be uploaded |
| `scripts/deploy-to-printer.sh` | Uploads the package over SSH |
| `scripts/install-on-printer.sh` | Installs the uploaded package with boot disabled |
| `scripts/test-connectivity.sh` | Shows USB interface, routes, and loaded modules |
| `scripts/enable-boot.sh` | Enables Ethernet startup after testing |
| `scripts/disable-boot.sh` | Disables Ethernet startup without uninstalling |
| `scripts/collect-diagnostics.sh` | Saves printer diagnostics locally |
| `scripts/uninstall-from-printer.sh` | Removes the installation from the printer |

Run files under `scripts/` on the Linux or WSL build machine. Files under `runtime/` are copied to the printer and normally run there.

Do not run `scripts/lib.sh` or `runtime/common.sh` directly. They are helper files. `scripts/prepare-kernel.sh` is also not a setup wizard. It prints a reminder that this repository cannot download or prepare a vendor kernel tree for you.

## Quick Start

Run these commands on the Linux or WSL build machine.

1. Clone the repository.

   ```sh
   git clone https://github.com/Zaknin/Creality-K1C-ethernet-driver.git
   cd Creality-K1C-ethernet-driver
   ```

2. Create a private build configuration outside the repository.

   ```sh
   cp config/build.env.example ../k1c-build.env
   nano ../k1c-build.env
   ```

   Edit it for your machine:

   ```sh
   ARCH=mips
   KERNEL_RELEASE=4.4.94
   KERNEL_DIR=/path/to/compatible/k1c-kernel
   CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-
   OUTPUT_DIR=output/modules
   BUILD_LOG_DIR=output/logs
   ```

3. Check the build environment.

   ```sh
   scripts/check-environment.sh --env ../k1c-build.env
   ```

4. Inspect the kernel tree.

   ```sh
   . ../k1c-build.env
   scripts/inspect-kernel-tree.sh --kernel-dir "$KERNEL_DIR"
   ```

   Results:

   - `LIKELY`: the expected files and version markers were found.
   - `UNCONFIRMED`: stop and inspect the source tree before relying on it.
   - `INCOMPATIBLE`: do not continue with that tree.

5. Build the three modules.

   ```sh
   scripts/build-modules.sh --env ../k1c-build.env
   ```

   Expected files:

   ```text
   output/modules/mii.ko
   output/modules/usbnet.ko
   output/modules/cdc_ncm.ko
   output/logs/build-modules.log
   ```

6. Verify the modules.

   ```sh
   scripts/verify-modules.sh \
     --modules-dir output/modules \
     --kernel-release 4.4.94
   ```

   Reports are written to:

   ```text
   output/verify/
   ```

7. Create the local printer package.

   ```sh
   scripts/package-local-build.sh \
     --modules-dir output/modules \
     --out output/package
   ```

   This creates:

   ```text
   output/package/k1c-usb-ethernet-local.tar.gz
   ```

8. Set the printer SSH destination.

   Replace `PRINTER_IP` with the printer's current Wi-Fi address.

   ```sh
   export PRINTER_HOST=root@PRINTER_IP
   ```

   Test SSH first:

   ```sh
   ssh "$PRINTER_HOST"
   ```

   Exit the SSH session before continuing.

9. Upload and install the package.

   Run on the build machine:

   ```sh
   scripts/deploy-to-printer.sh \
     --host "$PRINTER_HOST" \
     --package output/package/k1c-usb-ethernet-local.tar.gz

   scripts/install-on-printer.sh --host "$PRINTER_HOST"
   ```

   Installation does not enable automatic startup. Keep Wi-Fi connected while you test.

## Configure The Printer

The installed runtime files live here on the printer:

```text
/usr/data/k1c-usb-ethernet-local/runtime/
```

Create an editable runtime config on the printer:

```sh
ssh "$PRINTER_HOST"
cp /usr/data/k1c-usb-ethernet-local/runtime/config.conf.example \
   /usr/data/k1c-usb-ethernet-local/runtime/config.conf
vi /usr/data/k1c-usb-ethernet-local/runtime/config.conf
```

The most important setting is:

```sh
KEEP_WIFI_FALLBACK=1
```

With `KEEP_WIFI_FALLBACK=1`, `runtime/start-primary-ethernet.sh` will skip replacing the default route if a Wi-Fi default route already exists. This is the safer first test.

With `KEEP_WIFI_FALLBACK=0`, `runtime/start-primary-ethernet.sh` may replace the default route with `usb0` after `usb0` has an IPv4 address. Keep Wi-Fi SSH or another recovery path available before testing this.

## Start Manually

Run on the build machine:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/start-usb-ethernet.sh'
```

Then check status:

```sh
scripts/test-connectivity.sh --host "$PRINTER_HOST"
```

You can also run the printer-side status script directly:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/status-usb-ethernet.sh'
```

Successful output should show:

- `mii`, `usbnet`, and `cdc_ncm` loaded.
- A `usb0` interface.
- An IPv4 address on `usb0`.
- Default routes that make sense for your test mode.

DHCP assigns the Ethernet address, so this README does not list a fixed address.

## Test Ethernet Before Enabling Boot

Find the Ethernet IP:

```sh
scripts/test-connectivity.sh --host "$PRINTER_HOST"
```

From another terminal, test that address:

```sh
ping ETHERNET_IP
ssh root@ETHERNET_IP
```

Only enable startup after Wi-Fi SSH and Ethernet SSH both work:

```sh
scripts/enable-boot.sh --host "$PRINTER_HOST"
```

Undo startup without uninstalling:

```sh
scripts/disable-boot.sh --host "$PRINTER_HOST"
```

## Stop Or Uninstall

Manual stop:

```sh
ssh "$PRINTER_HOST" \
  '/usr/data/k1c-usb-ethernet-local/runtime/stop-usb-ethernet.sh'
```

Remove the printer installation:

```sh
scripts/uninstall-from-printer.sh --host "$PRINTER_HOST"
```

## Troubleshooting Shortcut

Collect a local diagnostic report:

```sh
scripts/collect-diagnostics.sh \
  --host "$PRINTER_HOST" \
  --out output/diagnostics
```

The report is written to:

```text
output/diagnostics/printer-diagnostics.txt
```

Read [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for symptom-based fixes.

## More Documentation

- [docs/SOURCE-ACQUISITION.md](docs/SOURCE-ACQUISITION.md): what kind of kernel tree you need and why generic source may not work.
- [docs/BUILD.md](docs/BUILD.md): complete build-machine setup and module build guide.
- [docs/VERIFY.md](docs/VERIFY.md): how module checks work and how to read reports.
- [docs/PACKAGE.md](docs/PACKAGE.md): how the local upload package is made.
- [docs/INSTALL.md](docs/INSTALL.md): detailed printer installation and first-start guide.
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md): every runtime setting in `config/runtime.conf.example`.
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md): fixes organized by symptom.
- [docs/UNINSTALL.md](docs/UNINSTALL.md): stop, disable, uninstall, and local cleanup commands.
