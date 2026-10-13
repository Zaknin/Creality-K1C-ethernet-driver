# Install the Prebuilt K1C USB Ethernet v1.0.3

Download the [official v1.0.3 release](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3).
This guide is for a **2023-generation Creality K1C**, Linux `4.4.94`,
with compatible ASIX USB adapter `0b95:1790`.

The runtime archive already contains the required MIPS kernel modules:
`mii.ko`, `usbnet.ko` and `cdc_ncm.ko`. No SDK is needed for installation.
The 2025-generation K1C and other kernel ABIs are not qualified.

**Keep Wi-Fi SSH accessible for the whole upgrade.** If you are currently
connected over USB Ethernet SSH, reconnect via Wi-Fi before stopping
the old runtime. Keep the original v1.0.2 archive for recovery.

## 1. Download and check the archive (Linux/WSL computer)

Download `k1c-usb-ethernet-v1.0.3-runtime.tar.gz` and `SHA256SUMS`
to the same directory. Check only the downloaded TAR:

```sh
grep '  k1c-usb-ethernet-v1.0.3-runtime.tar.gz$' SHA256SUMS | sha256sum -c -
```

Expected: `k1c-usb-ethernet-v1.0.3-runtime.tar.gz: OK`.
If downloading the ZIP instead, check its matching line in
`SHA256SUMS` before extracting.

## 2. Transfer and extract (printer's Wi-Fi IP)

From the Linux/WSL computer:

```sh
scp k1c-usb-ethernet-v1.0.3-runtime.tar.gz root@PRINTER_WIFI_IP:/tmp/
ssh root@PRINTER_WIFI_IP
```

Continue the commands below in the **printer's root shell**:

```sh
cd /tmp
tar -xzf k1c-usb-ethernet-v1.0.3-runtime.tar.gz
cd /tmp/k1c-usb-ethernet-v1.0.3-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

All checks must report `OK`.

## 3. Upgrading an existing v1.0.1/v1.0.2 runtime

**Skip for a fresh installation.**

The current prebuilt runtime lives in:

```text
/usr/data/k1c-usb-ethernet/vendor-native-known-good
```

The v1.0.3 installer intentionally refuses to overwrite an
existing package-owned runtime. Over **Wi-Fi SSH**:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/stop-primary-ethernet.sh"
"$P/uninstall-usb-ethernet.sh" --yes
```

The uninstall also disables the owned boot hook
`/etc/init.d/S46usb_ethernet_primary` and deletes the old
package directory, including logs and state. Save any diagnostic
information beforehand. Do not apply these commands to the older
build-tools installation in `/usr/data/k1c-usb-ethernet-local`.

## 4. Install and start v1.0.3

In the **printer root shell**:

```sh
sh /tmp/k1c-usb-ethernet-v1.0.3-runtime/install.sh --enable-boot
```

The installer copies files and enables automatic boot integration,
but does not immediately start Ethernet-primary mode. Start it:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/start-primary-ethernet.sh"
"$P/ethernet-failover-status.sh"
```

When both interfaces are healthy, the USB default route normally
uses metric `50`, with Wi-Fi backup metric `300`.

## 5. Check functionality and the two filters

```sh
ip -4 addr show usb0
ip -4 route
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

Expected parameter defaults: `Y` and `N`. Check access to your
actual LAN gateway with `ping -I usb0 -c 10 -W 2 GATEWAY_IP`.
Also check SSH, normal printing and Ethernet/Wi-Fi fallback,
including after reboot.

- `drop_l2_8899=Y`: ignore EtherType 0x8899 frames.
- `rx_ipv4_only=N`: strict L2 filtering disabled by default.

The optional strict mode can suppress IPv6, EAPOL/802.1X,
LLDP and PPPoE. Do not enable without checking network requirements.
See [filter modes](FILTER-MODES-v1.0.3.md). Runtime sysfs changes
are **not persistent** across reload/reboot.

The v1.0.3 receive filters are **not** a fix for the repeated
CDC-NCM connection/speed notification issue
([Issue #1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1)).

## 6. Stop, uninstall or recover

Stop Ethernet-primary:

```sh
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
"$P/stop-primary-ethernet.sh"
```

Disable boot integration (also stops the package):

```sh
"$P/disable-primary-ethernet-boot.sh"
```

Uninstall this package (requires its `.package-owned` marker):

```sh
"$P/uninstall-usb-ethernet.sh" --yes
```

If needed, reinstall your verified saved v1.0.2 runtime using its
own install instructions. Never overwrite a currently loaded `.ko`
in place. If no network access remains, physical recovery may be
necessary.

See [troubleshooting](TROUBLESHOOTING.md) and the
[latest upgrade guide](https://github.com/Zaknin/Creality-K1C-ethernet-driver/blob/main/docs/LATEST-RUNTIME.md).

**Qualification note:** the new CDC-NCM module was physically tested
in A/B/C mode and successfully recovered by watchdog. Full v1.0.3
package upgrade and subsequent reboot acceptance remains a separate
qualification step.
