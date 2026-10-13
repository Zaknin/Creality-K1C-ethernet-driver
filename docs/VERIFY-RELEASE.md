# Verify K1C USB Ethernet v1.0.3 Release

## 1. Verify the downloaded runtime archive

Download the exact archive you intend to install and `SHA256SUMS`
from the [v1.0.3 GitHub Release](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3).

For the TAR release asset (Linux/WSL):

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.tar.gz$' SHA256SUMS | sha256sum -c -
```

For the ZIP release asset:

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.zip$' SHA256SUMS | sha256sum -c -
```

If all **three** downloadable archives are in the same directory,
you may instead verify the entire file with:

```sh
sha256sum -c SHA256SUMS
```

Do not install anything that fails a checksum.

## 2. Verify the extracted runtime package

After extracting the verified runtime TAR:

```sh
cd k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

These cover `modules/mii.ko`, `modules/usbnet.ko`,
`modules/cdc_ncm.ko` and all other package files.

The published v1.0.3 `cdc_ncm.ko` must have SHA-256:

```text
f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271
```

Expected kernel `vermagic`:

```text
4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT
```

On a Linux build host, inspect with `file modules/*.ko` and, if
available, `modinfo modules/*.ko`. The BusyBox printer may not
ship `modinfo`. A correct hash/ABI is necessary but **not sufficient**
to establish that the runtime will work on every printer.

## 3. Verify the installed runtime and active driver

After installation and startup, on the **printer root shell**:

```sh
cd /usr/data/k1c-usb-ethernet/vendor-native-known-good
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
lsmod | grep -E 'cdc_ncm|usbnet|mii'
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
ip -4 route
```

Expected defaults: `drop_l2_8899=Y`, `rx_ipv4_only=N`.
If either parameter is missing, the loaded `cdc_ncm` may still be
the older module. Verify using the known-good Wi-Fi SSH recovery path;
do not overwrite active modules.

Check gateway ping, printing, failover and restart/reboot separately.
A checksum check is **not** a substitute for those integration tests.

See the [updated installation guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md)
and [filter modes](FILTER-MODES-v1.0.3.md).
