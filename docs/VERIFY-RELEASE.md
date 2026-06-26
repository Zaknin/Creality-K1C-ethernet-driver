# Verify Release Assets

## Verify Downloads

Download `SHA256SUMS` and the assets you plan to use:

```text
k1c-usb-ethernet-v1.0.1-runtime.tar.gz
k1c-usb-ethernet-v1.0.1-runtime.zip
k1c-usb-ethernet-v1.0.1-source.tar.gz
```

Run:

```sh
sha256sum -c SHA256SUMS
```

Only use assets that report `OK`.

## Verify Runtime Package Contents

After extracting the runtime archive:

```sh
cd k1c-usb-ethernet-v1.0.1-runtime/package
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
