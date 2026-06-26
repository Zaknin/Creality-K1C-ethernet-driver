# Troubleshooting

## SSH or Root Access Fails

Install and recovery require root SSH. Restore Wi-Fi SSH first:

```sh
ssh root@PRINTER_IP
```

Do not continue until this works.

## Unsupported Kernel

The installer expects:

```text
4.4.94
```

Check:

```sh
uname -r
```

Other kernels are refused because the modules are built for one ABI only.

## Installer Cannot Locate `package/`

Use the v1.0.1 runtime archive. The installer expects `package/` beside
`install.sh`. Both of these forms are supported:

```sh
cd /tmp/k1c-usb-ethernet-v1.0.1-runtime
sh ./install.sh --enable-boot
```

```sh
sh /tmp/k1c-usb-ethernet-v1.0.1-runtime/install.sh --enable-boot
```

If this still fails, the archive was not fully extracted.

## Corrupt Archive or Module

Verify downloads:

```sh
sha256sum -c SHA256SUMS
```

Verify extracted runtime files:

```sh
cd k1c-usb-ethernet-v1.0.1-runtime/package
sha256sum -c module-hashes.sha256
sha256sum -c SHA256SUMS
```

## Existing Installation

The v1.0.1 installer refuses an existing package-owned install tree. Keep Wi-Fi
connected, then run:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```

Then install v1.0.1.

## Adapter Not Detected

Check for the tested adapter:

```sh
lsusb | grep -i '0b95:1790'
```

Check cable, hub, and power. Other adapters are not claimed.

## `usb0` Does Not Appear

Check modules and recent kernel messages:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/status-usb-ethernet.sh
dmesg | tail -n 100
```

## DHCP Failure

Check link and route status:

```sh
ip addr show usb0
ip route
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

The Ethernet network must provide DHCP.

## Wrong Route Metrics or Gateway Uses Wi-Fi

Expected route behavior while USB is healthy:

- USB Ethernet metric `50`.
- Wi-Fi fallback metric `300`.
- Gateway lookup from the USB address selects `usb0`.

Restart Ethernet-primary mode:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

## Disable Boot or Recover Over Wi-Fi

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

If Ethernet is unusable, reconnect over Wi-Fi SSH and run the disable or
uninstall command.

## Clean Uninstall

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/uninstall-usb-ethernet.sh --yes
```
