# K1C USB Ethernet Package

Version 1.0.0 provides validated vendor-native USB Ethernet modules and
network scripts for the explicitly supported Creality K1C firmware/kernel ABI.

## Supported Target

- Printer: Creality K1C
- Kernel: `4.4.94`
- Kernel ABI: `SMP preempt mod_unload MIPS32_R2 32BIT`
- USB Ethernet adapter tested: ASIX `0b95:1790` in CDC-NCM mode

Do not use this package on unrelated printers, kernels, or firmware builds.
The scripts intentionally refuse incompatible kernel/module combinations.

## Runtime Files

- `modules/mii.ko`
- `modules/usbnet.ko`
- `modules/cdc_ncm.ko`
- `module-hashes.sha256`
- `final.config`
- `toolchain.txt`
- `source-provenance.txt`
- `evidence-references.txt`
- `start-usb-ethernet.sh`
- `stop-usb-ethernet.sh`
- `status-usb-ethernet.sh`
- `start-primary-ethernet.sh`
- `stop-primary-ethernet.sh`
- `usb0-udhcpc-script.sh`
- `ethernet-failover-status.sh`
- `disable-primary-ethernet-boot.sh`
- `S46usb_ethernet_primary`
- `uninstall-usb-ethernet.sh`

## Manual Module Mode

Load verified modules only:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-usb-ethernet.sh
```

Load verified modules and explicitly bring `usb0` up:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-usb-ethernet.sh --up
```

This mode does not run DHCP and does not alter Wi-Fi, routes, DNS, or boot
configuration.

## Ethernet Primary With Wi-Fi Fallback

Start Ethernet as the preferred path:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/start-primary-ethernet.sh
```

Stop Ethernet-primary mode and restore Wi-Fi fallback:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
```

Inspect state:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/ethernet-failover-status.sh
```

The qualified K1C kernel does not support `ip rule`, so this package uses route
metrics. Ethernet uses metric `50` when carrier and DHCP are available. Wi-Fi
is retained as fallback with metric `300`.

## Boot Integration

The public installer can install the boot hook when requested. The boot hook
uses bounded waits for USB enumeration and starts Ethernet-primary mode without
disabling Wi-Fi.

Disable boot integration:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/disable-primary-ethernet-boot.sh
```

## Recovery

If Ethernet setup causes trouble, keep using Wi-Fi and run:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-primary-ethernet.sh
```

For module-only recovery:

```sh
/usr/data/k1c-usb-ethernet/vendor-native-known-good/stop-usb-ethernet.sh
```

No reboot is normally required. Reboot only if SSH is unavailable or the kernel
network stack is otherwise unresponsive.

## Historical Warning

During development, a small bounded burst of
`cdc_ncm ... kevent 2 may have been dropped`
messages was observed.

Event 2 is `EVENT_RX_MEMORY`. The event bit is set before deferred recovery
work is scheduled, so repeated requests can be coalesced while the worker is
already pending.

The warning did not recur during the final instrumented diagnostic run. That
run recorded zero RX skb allocation failures, zero RX URB `-ENOMEM` returns,
zero other RX submission errors, zero `netif_rx()` failures, and zero softnet
backlog drops.

Isolated IPv4 traffic, DHCP, DNS, SSH, automatic startup, Ethernet/Wi-Fi
failover, and recovery all completed successfully.

Further investigation is recommended only if this warning coincides with RX
errors, traffic stalls, failed DHCP renewal, carrier instability, increasing
packet loss, or failure to recover after link interruption.
