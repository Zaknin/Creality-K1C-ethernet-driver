# Verify Release Assets

## Verify Downloads

Download `SHA256SUMS` and the assets you plan to use:

```text
k1c-usb-ethernet-v1.0.3-runtime.tar.gz
k1c-usb-ethernet-v1.0.3-runtime.zip
k1c-usb-ethernet-v1.0.3-source.tar.gz
```

Run:

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.tar.gz

## Verify Runtime Package Contents

After extracting the runtime archive:

```sh
cd k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

Expected modules:

```text
modules/mii.ko
modules/usbnet.ko
modules/cdc_ncm.ko
```

Expected ABI/vermagic:

```text
4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT
```

If available on your host, inspect modules with:

```sh
file modules/*.ko
modinfo modules/*.ko
```

BusyBox-only printer environments may not have `modinfo`; in that case rely on
the package hashes, installer refusal checks, and runtime status commands.

## Verify Installed Tree

The installer verifies module hashes before and after copying. You can recheck:

```sh
cd /usr/data/k1c-usb-ethernet/vendor-native-known-good
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```
 SHA256SUMS | sha256sum -c -
```

This checks the selected TAR if you downloaded only it and `SHA256SUMS`. To verify the whole release with `sha256sum -c SHA256SUMS`, all three archives must be downloaded to the same directory. ZIP users should select the ZIP entry instead.

## Verify Runtime Package Contents

After extracting the runtime archive:

```sh
cd k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

Expected modules:

```text
modules/mii.ko
modules/usbnet.ko
modules/cdc_ncm.ko
```

Expected ABI/vermagic:

```text
4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT
```

If available on your host, inspect modules with:

```sh
file modules/*.ko
modinfo modules/*.ko
```

BusyBox-only printer environments may not have `modinfo`; in that case rely on
the package hashes, installer refusal checks, and runtime status commands.

## Verify Installed Tree

The installer verifies module hashes before and after copying. You can recheck:

```sh
cd /usr/data/k1c-usb-ethernet/vendor-native-known-good
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

## Hardware-Tested v1.0.3 CDC-NCM Module

Expected SHA-256 of the `cdc_ncm.ko` inside the runtime:

```text
f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271
```

Once the module is loaded, the v1.0.3 RX parameter files should exist:

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

Expected defaults: `Y` and `N`. Their presence does not by itself
prove application-level printing or failover success; test those
separately on the printer.
