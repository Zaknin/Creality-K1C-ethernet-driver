# Release Qualification

## Verdict

`GO -- qualified for public v1.0.0 on the explicitly supported K1C firmware/kernel ABI, with a documented historical non-blocking EVENT_RX_MEMORY warning.`

## Supported Target

- Printer: Creality K1C only
- Board/SoC family: Ingenic X2000 K1C platform
- Kernel: `4.4.94`
- Observed kernel banner class: `Linux K1C ... 4.4.94 ... mips GNU/Linux`
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Vendor defconfig: `x2000_module_base_linux_sfc_nand_defconfig`
- Required kernel features:
  - `CONFIG_MII=m`
  - `CONFIG_USB_USBNET=m`
  - `CONFIG_USB_NET_CDC_NCM=m`
  - `CONFIG_MODULE_UNLOAD=y`

This release does not claim support for other printers, firmware versions,
kernel ABIs, or USB Ethernet chipsets.

## Adapter Tested

- USB ID: `0b95:1790`
- Driver binding: both ASIX interfaces bound to `cdc_ncm`
- Negotiated link observed: 100 Mbit/s

## Frozen Production Modules

```text
a66d280aa643319a848260e8ade6373415a61e1e07c73e16dacd33f75ac497d8  modules/mii.ko
8a582cb3f480f86126dacc2b7255b45efcb4fb58d591007e6ba653bee08da85d  modules/usbnet.ko
6ff51a9ec99089245d0cad267ac83d312193bb6818f8cec6519c1983cbe8f2bc  modules/cdc_ncm.ko
```

The diagnostic `usbnet.ko` with hash
`3de1204f9211e104a301d34a96d72d566340951f458f03c6f3bc2d613a78c360`
is excluded from runtime release assets and installation archives.

## Build and Source

- Source: vendor-native Linux 4.4.94 module sources
- Toolchain: Ingenic `mips-linux-gnu-gcc` 7.2.0
- Kernel target: `4.4.94`
- Final config: `package/final.config`
- Source files included: `source/mii.c`, `source/usbnet.c`, `source/cdc_ncm.c`

## Validation Summary

### Bind, Open, Close

The modules loaded in order `mii`, `usbnet`, `cdc_ncm`, bound to the ASIX
adapter, created `usb0`, opened and closed without forced removal, and unloaded
in reverse order when safe.

### Carrier and DHCP

`usb0` reached `UP,LOWER_UP` with carrier present. Controlled no-op DHCP tests
proved real packet exchange without applying configuration. Later production
DHCP tests obtained an Ethernet lease, applied Ethernet as primary, and retained
Wi-Fi as fallback.

### Isolated 128 MiB Transfer Test

Temporary benchmark addressing on an isolated documentation subnet proved that
traffic addressed to the Ethernet test address entered through `usb0` and
replies sourced from the Ethernet test address left through `usb0`.

Results:

```text
controller -> printer: 128 MiB, rc 0, about 47s, about 2.8 MB/s
printer -> controller: 128 MiB, rc 0, about 21s, about 6.6 MB/s
packet capture: 140,662 packets, 0 capture drops
byte accounting: matched isolated traffic direction and payload scale
ping loss: 0%
```

`rx_dropped` growth was observed, but it was not demonstrated to represent loss
of valid IPv4 test traffic. It is documented as generic receive-core accounting
that was not fully classified. Do not claim every such drop is harmless.

### Final Instrumented Diagnostic Transfer Test

A separate diagnostic `usbnet.ko` was built from the exact vendor-native source
and config. It exposed read-only counters only and did not change queue sizing,
recovery logic, return values, or runtime behavior.

Results:

```text
30s idle: ping loss 0%
64 MiB controller -> printer: rc 0, about 24s, about 2.8 MB/s
64 MiB printer -> controller: rc 0, about 11s, about 6.5 MB/s
rx_skb_alloc_fail: 0
rx_submit_urb_enomem: 0
rx_submit_urb_other_err: 0
netif_rx_non_success: 0
softnet drop delta: 0
rx_errors: 0
new EVENT_RX_MEMORY warnings: 0
```

Protocol/type counter deltas during the controller-to-printer 64 MiB transfer:

```text
eth_ipv4: +49,373
eth_arp: +126
eth_ipv6: +136
eth_other: +31
packet_otherhost: +0
broadcast: +205
multicast: +272
netif_rx_success: +49,666
netif_rx_non_success: +0
```

### Ethernet Primary and Wi-Fi Fallback

The package uses route metrics because the qualified kernel reports source
policy routing as unsupported. Ethernet uses metric `50` after carrier and DHCP
succeed. Wi-Fi remains configured as fallback with metric `300`.

Validation covered:

- Ethernet DHCP lease acquisition
- Ethernet preferred default route
- Wi-Fi fallback route retained
- DNS via Ethernet while active
- SSH through both network paths during validation
- Ethernet loss causing Wi-Fi fallback
- Ethernet restoration causing Ethernet to become primary again
- exactly one package-managed `udhcpc` process for `usb0`

### Boot Integration

The init hook starts a bounded background wait for USB enumeration and then
starts Ethernet-primary mode. It does not disable Wi-Fi and does not block boot
indefinitely.

Unattended boot acceptance validated:

- boot completed normally
- boot hook ran automatically
- production modules loaded from the stable package
- `usb0` was `UP,LOWER_UP`
- carrier was present
- Ethernet DHCP lease was acquired
- Ethernet default route metric `50`
- Wi-Fi fallback route metric `300`
- DNS resolution worked
- SSH/ping worked through Ethernet and Wi-Fi
- no duplicate `udhcpc` process
- failover and recovery cycle succeeded

### Five-Cycle Failover/Recovery

Five controlled Ethernet down/up cycles passed. During link loss, Wi-Fi became
the working primary route. After restoration, Ethernet DHCP was reacquired and
Ethernet became primary again.

## Historical Warning Disclosure

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

The historical warning is not claimed to have been definitively caused by
either RX skb allocation failure or RX URB submission failure.

## Acceptance Rationale

The release is accepted because the frozen production modules passed lifecycle,
carrier, DHCP, isolated IPv4 transfer, boot, failover, recovery, DNS, and SSH
validation on the explicit supported K1C firmware/kernel ABI. The final
instrumented diagnostic run did not reproduce the historical warning and showed
no RX allocation failures, URB `-ENOMEM`, RX submit errors, `netif_rx()` failures,
softnet backlog drops, RX errors, stalls, lockups, DHCP failures, DNS failures,
or recovery failures.
