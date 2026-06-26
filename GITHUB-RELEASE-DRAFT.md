# GitHub Release Notes: v1.0.1

## 1. What this release is

`v1.0.1` is a qualified patch release for the Creality K1C USB Ethernet
runtime. It provides ready-to-install prebuilt runtime archives and a separate
source archive for users who want to compile the three kernel modules
themselves.

Release assets:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`
- `k1c-usb-ethernet-v1.0.1-source.tar.gz`
- `SHA256SUMS`

The runtime TAR and ZIP contain ready-to-install compiled modules. The source
TAR is for compilation and does not contain compiled `.ko` files.

## 2. Changes since v1.0.0

- Fixed installer path resolution so `install.sh` finds `package/` beside
  itself even when invoked by absolute path, such as:

  ```sh
  sh /tmp/k1c-usb-ethernet-v1.0.1-runtime/install.sh --enable-boot
  ```

- Split release packaging into prebuilt runtime assets and a source-build
  archive.
- Documented the accepted source-build workflow and its external prerequisites.
- Preserved the qualified runtime module hashes.

## 3. Supported hardware

- Tested printer generation: 2023-generation Creality K1C
- Kernel: `4.4.94`
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Tested USB adapter: ASIX `0b95:1790`

The 2025 K1C revision has not been tested. Compatibility with the 2025 revision
is unknown and is not claimed.

## 4. Install the prebuilt driver

Use one runtime asset:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`

Runtime users do not need an SDK, compiler, kernel source tree, or build
environment. Keep Wi-Fi enabled until USB Ethernet and fallback recovery are
verified.

Short TAR flow:

```sh
sha256sum -c SHA256SUMS
scp k1c-usb-ethernet-v1.0.1-runtime.tar.gz root@PRINTER_IP:/tmp/
ssh root@PRINTER_IP
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.1-runtime.tar.gz
sh /tmp/k1c-usb-ethernet-v1.0.1-runtime/install.sh --enable-boot
```

Installing with `--enable-boot` installs the boot hook but does not immediately
start Ethernet-primary mode. Start explicitly or reboot.

## 5. Compile from source

Use:

- `k1c-usb-ethernet-v1.0.1-source.tar.gz`

The source archive contains the released module sources, build records, and
helper scripts. It does not contain compiled `.ko` files, a vendor kernel tree,
SDK, toolchain, sysroot, firmware, or private build output.

Source compilation requires separately obtained external prerequisites:

- compatible prepared Creality/Ingenic X2000 Linux `4.4.94` kernel source;
- matching generated kernel configuration and headers;
- Ingenic-compatible MIPS toolchain.

For the accepted K1C configuration, `CONFIG_MODVERSIONS` is disabled. A
top-level kernel `Module.symvers` was not required in the accepted workflow;
Kbuild generated a module-local `Module.symvers` during `modpost`.
`source/Module.symvers.known-good` is a 53-symbol module-export reference, not
a full kernel symbol table.

Output hashes may differ because kernel modules can embed build paths. Runtime
ABI compatibility is checked through source identity, target configuration,
architecture, vermagic, dependencies, and verification output, not universal
byte-for-byte reproducibility.

## 6. Verify downloads

Download `SHA256SUMS` and the assets you plan to use, then run:

```sh
sha256sum -c SHA256SUMS
```

`SHA256SUMS` covers exactly:

- `k1c-usb-ethernet-v1.0.1-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.1-runtime.zip`
- `k1c-usb-ethernet-v1.0.1-source.tar.gz`

Only use assets that report `OK`.

## 7. Upgrade from v1.0.0

The v1.0.1 installer refuses an existing package-owned installation. Keep Wi-Fi
SSH available, then stop and uninstall v1.0.0:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

Install v1.0.1 after v1.0.0 is removed.

## 8. Start and status

Start immediately:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

Check status:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

Expected route behavior while USB is healthy:

- USB Ethernet default route metric `50`
- Wi-Fi fallback default route metric `300`
- gateway lookup from the USB address selects `usb0`

## 9. Uninstall and recovery

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

## 10. Known limitations

- Unofficial community release; not affiliated with or supported by Creality.
- Physical support claim is limited to the documented 2023-generation K1C.
- 2025 K1C compatibility is unknown and not claimed.
- The source-build workflow requires external vendor/toolchain inputs not
  redistributed here.
- Self-built modules must be validated before use on a printer.

## 11. Source and license compliance

The runtime archives include compiled Linux kernel modules. The source archive
includes corresponding module source files and build records.

`COPYING` contains the Linux kernel GPLv2 text. `LICENSE.md` explains the
mixed-license structure and does not claim that kernel-derived source or
modules are MIT-licensed.

## 12. Qualification summary

Runtime physical qualification passed across installation, reboot persistence,
Ethernet-cable loss and recovery, physical USB adapter removal and recreation,
uninstall, and final reinstall.

Source-build acceptance passed from a fresh source archive using a prepared K1C
kernel tree and Ingenic-compatible MIPS toolchain. All three built modules were
ELF32 LSB MIPS/MIPS32 rel2 and used vermagic
`4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`.
