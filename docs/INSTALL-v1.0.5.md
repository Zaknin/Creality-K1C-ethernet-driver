# Install and upgrade — K1C USB Ethernet v1.0.5

Use the v1.0.5 runtime archive after the v1.0.5 GitHub Release has been published. The repository's default `main` branch describes an older, different local-build workflow; do not use those install scripts for this package.

## Hardware scope and precautions

Qualified target: **2023-generation Creality K1C**, Linux `4.4.94`, MIPS32_R2, and ASIX CDC-NCM USB ID `0b95:1790`. The 2025 revision, other kernels and other adapters are not qualified.

Keep SSH access over a **separately working Wi-Fi interface** throughout installation. Do not switch kernel modules while printing. Save a verified copy of the previous working package and any logs somewhere outside its installation directory; uninstall removes that directory. If multiple links share an IPv4 subnet, preserve an appropriate management reply route before switching interfaces.

Check the target as root:

```sh
uname -r
lsusb | grep -i '0b95:1790'
df -h /overlay /usr/data
```

A full `/overlay` cannot accept a new boot hook. The v1.0.5 installer fails earlier and more cleanly, but **does not increase free storage**. Never delete unrelated firmware files to make room.

## 1. Verify downloaded archive

Download the v1.0.5 runtime TAR and `SHA256SUMS` from the **same release**. On Linux or WSL:

```sh
grep '  k1c-usb-ethernet-v1.0.5-runtime.tar.gz$' SHA256SUMS | sha256sum -c -
```

Stop on a checksum failure. Transfer the verified archive to the printer's Wi-Fi management address:

```sh
scp k1c-usb-ethernet-v1.0.5-runtime.tar.gz root@PRINTER_WIFI_IP:/tmp/
ssh root@PRINTER_WIFI_IP
```

All following commands run as root on the printer.

## 2. Unpack and verify contents

```sh
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.5-runtime.tar.gz
cd k1c-usb-ethernet-v1.0.5-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

Every file must report `OK`.

## 3. Existing installation: backup, stop and uninstall

The installer deliberately refuses **any existing destination**, including partial installations. It never upgrades active `.ko` modules in place. If the following path is the expected **package-owned** runtime, and only after the previous archive/logs have been backed up:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
cat "$P/.package-owned"
"$P/stop-primary-ethernet.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

If the ownership marker is absent or incorrect, **stop**: do not delete an unknown directory. The old uninstall also removes its owned boot hook. Keep access over Wi-Fi.

## 4. Install v1.0.5

To install and enable automatic startup (requires writable overlay):

```sh
sh /tmp/k1c-usb-ethernet-v1.0.5-runtime/install.sh --enable-boot
```

If the installer reports insufficient overlay space for the hook, manual-only installation is supported **after verifying that no prior destination exists**:

```sh
sh /tmp/k1c-usb-ethernet-v1.0.5-runtime/install.sh
```

Manual-only installation does not enable startup after reboot. Both forms refuse to replace existing boot hooks or existing installation directories.

## 5. Start and verify

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/start-primary-ethernet.sh"
"$P/ethernet-failover-status.sh"
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
ip -4 addr show usb0
ip -4 route
```

Filter defaults are `Y` and `N`; USB normally uses route metric 50 with Wi-Fi fallback metric 300. Test actual connectivity using the local site's appropriate gateway, and validate normal printer functions before relying on the link. If boot integration was enabled, perform a controlled reboot only when the printer is idle and recovery access is available.

## 6. Recovery

Reconnect through known-good Wi-Fi SSH. To disable this package's boot integration:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/disable-primary-ethernet-boot.sh"
```

Before uninstalling, preserve needed logs. Stop and uninstall with the packaged scripts, then reinstall the previously saved and checksum-verified version using **that version's own instructions**. Do not copy over loaded modules.

See [filter modes](FILTER-MODES-v1.0.5.md), [hardware acceptance](HARDWARE-ACCEPTANCE-v1.0.5.md) and [release notes](RELEASE-NOTES-v1.0.5.md).
