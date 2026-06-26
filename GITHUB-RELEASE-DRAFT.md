# Draft GitHub Release: v1.0.1

Do not publish until maintainer approval, asset verification, and physical
v1.0.1 validation are complete.

## 1. What this release is

`v1.0.1` is a patch release candidate for the Creality K1C USB Ethernet runtime.
It fixes the installer path-resolution defect found in `v1.0.0` and separates
the prebuilt runtime assets from the source/build asset.

The production module binaries are intended to remain byte-identical to
`v1.0.0`; this release changes installer behavior, documentation, packaging,
and release layout.

## 2. Supported hardware

- Tested printer generation: 2023-generation Creality K1C
- Kernel: `4.4.94`
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Tested USB adapter: ASIX `0b95:1790`

The 2025 K1C revision has not been tested. Compatibility with the 2025 revision
is unknown and is not claimed.

## 3. Install the prebuilt driver

Use one runtime asset:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`

The runtime archive already contains compiled `.ko` modules. Runtime users do
not need an SDK, compiler, kernel source tree, or build tools.

Short form:

```sh
sha256sum -c SHA256SUMS
scp k1c-usb-ethernet-v1.0.1-runtime.tar.gz root@PRINTER_IP:/tmp/
ssh root@PRINTER_IP
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.1-runtime.tar.gz
cd k1c-usb-ethernet-v1.0.1-runtime
sh ./install.sh --enable-boot
```

The installer can also be invoked by absolute path:

```sh
sh /tmp/k1c-usb-ethernet-v1.0.1-runtime/install.sh --enable-boot
```

## 4. Compile from source

Use:

- `k1c-usb-ethernet-v1.0.1-source.tar.gz`

The source archive contains the released module source files, build records,
and helper scripts. It does not contain compiled `.ko` files, a vendor kernel
tree, SDK, toolchain, sysroot, or firmware.

The build path still depends on a separately acquired compatible prepared
Creality/Ingenic X2000 Linux `4.4.94` kernel tree and MIPS toolchain. The source
bundle is a coherent build workflow, not a guarantee of byte-for-byte
reproduction without those exact external inputs.

## 5. Verify downloads

Verify all downloaded assets:

```sh
sha256sum -c SHA256SUMS
```

`SHA256SUMS` covers exactly:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`
- `k1c-usb-ethernet-v1.0.1-source.tar.gz`

## 6. Upgrade from v1.0.0

The v1.0.1 installer refuses an existing package-owned installation. Keep Wi-Fi
SSH available, then:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

Install v1.0.1 after v1.0.0 is removed.

## 7. Start and status

Installing with `--enable-boot` enables startup after reboot. It does not start
Ethernet-primary mode immediately.

Start immediately:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

Check status:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

Expected route behavior while USB is healthy:

- USB Ethernet metric `50`
- Wi-Fi fallback metric `300`
- gateway lookup from the USB address selects `usb0`

## 8. Uninstall and recovery

Disable boot integration:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

Uninstall:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

Keep Wi-Fi enabled during installation and testing so you can recover over Wi-Fi
SSH if USB Ethernet fails.

## 9. Known limitations

- Unofficial community release; not affiliated with or supported by Creality.
- Physical support claim remains limited to the documented 2023-generation K1C.
- 2025 K1C compatibility is unknown and not claimed.
- The source build path requires external vendor/toolchain inputs not
  redistributed here.

## 10. Source and license compliance

The runtime archive includes compiled Linux kernel modules. The source archive
includes corresponding module source files and build records.

`COPYING` contains the Linux kernel GPLv2 text. `LICENSE.md` explains the
mixed-license structure and does not claim that kernel-derived source or modules
are MIT-licensed.

## 11. Qualification state

Current state:

`GO_candidate_pending_v1.0.1_physical_validation`

Do not publish this release as fully qualified until v1.0.1 physical printer
validation is complete.
