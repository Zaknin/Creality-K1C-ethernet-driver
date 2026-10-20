# Runtime Package

This directory is the installed runtime payload for Creality K1C USB Ethernet
v1.0.6. It contains the prebuilt production modules and the scripts needed to
install, start, stop, inspect, disable, and uninstall them.

## Supported Target

- Tested printer generation: 2023-generation Creality K1C
- Kernel: `4.4.94`
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Tested USB adapter: ASIX `0b95:1790`

The 2025 K1C revision has not been tested. Compatibility with the 2025 revision
is unknown and is not claimed.

## Included Modules

```text
modules/mii.ko
modules/usbnet.ko
modules/cdc_ncm.ko
```

Verify module hashes with:

```sh
sha256sum -c module-hashes.sha256
```

## Main Commands

Start Ethernet-primary mode after installation:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

Check status:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

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

Keep Wi-Fi enabled until Ethernet and the fallback path are verified.

## v1.0.6 candidate logging and boot-hook behavior

Runtime logs default to /run/k1c-usb-ethernet (volatile). Set K1C_ALLOW_PERSISTENT_LOGS=1 and LOG_FILE to opt in to persistent logs. Each log has a best-effort 256 KiB soft limit.
The default --enable-boot installation still copies the hook; test --enable-boot --boot-hook symlink only with independent recovery access. A full overlay may reject even the symlink, and boot ordering must be physically validated.
