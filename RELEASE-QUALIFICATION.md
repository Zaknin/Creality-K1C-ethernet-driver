# Release Qualification

## Verdict

`GO -- qualification complete; publication remains a separate maintainer-controlled action.`

The unpublished v1.0.0 runtime was qualified on the target 2023-generation
Creality K1C on 2026-06-25.

Qualified candidate:

- uninstall source-fix commit:
  `25ec035f53ceb778c40da90069190bdadca17faf`
- rebuilt candidate commit:
  `0e188c2`
- tested TAR SHA-256:
  `523d51dfa4ff159abeb977f2349584a7417e5a151507bd974418395992b731a9`
- tested ZIP SHA-256:
  `81ed343420812342183bceba5492f13bc34a1cae6090614c761e9ff32cbea502`

All repository regressions, package manifests, archive checks, and physical
acceptance gates passed.

Physical validation covered clean startup, exact USB-primary and Wi-Fi-fallback
routes, source-address route lookups, repeated physical USB removal and
reconnection, Ethernet-cable-only loss and recovery, process uniqueness, and
actual uninstall while the USB Ethernet adapter remained physically connected.

An earlier uninstall attempt exposed a real defect: the runtime directory was
removed while the boot hook and route-monitor process remained. The defect was
fixed in commit `25ec035`, covered by a TERM-to-SIGKILL regression, rebuilt into
candidate commit `0e188c2`, and retested successfully on the printer.

The final public archives are rebuilt after qualification-record and release
metadata updates. The executable runtime scripts and kernel modules remain
byte-identical to the physically qualified candidate. Only
`package/package-manifest.txt` and `package/SHA256SUMS` differ for release
metadata correction. No runtime behavior changed, and no repeat physical test
was required for this non-executable metadata and checksum-record update.

This verdict does not itself push commits, create a final tag, or publish a
GitHub release.

## Supported Target

- Tested printer generation: 2023-generation Creality K1C
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

Tested only on a 2023-generation Creality K1C running kernel 4.4.94 with the documented module ABI. The 2025 K1C revision has not been tested; compatibility is unknown and is not claimed.

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
policy routing as unsupported.

While USB Ethernet is healthy, the accepted route state is:

```text
default via 192.168.23.100 dev usb0 metric 50
default via 192.168.23.100 dev wlan0 metric 300
192.168.23.0/24 dev usb0 scope link src 192.168.23.92 metric 50
192.168.23.0/24 dev wlan0 scope link src 192.168.23.169 metric 300
```

Validation confirmed that gateway and LAN lookups from the Ethernet source
address select `usb0`, while Wi-Fi remains configured as fallback.

Validation covered:

- Ethernet DHCP lease acquisition;
- Ethernet preferred default route;
- Wi-Fi fallback default and connected route;
- repair of firmware-recreated metricless or duplicate routes;
- same-subnet USB and Wi-Fi connected-route reconciliation;
- DNS and SSH through the active network path;
- physical USB loss causing Wi-Fi fallback;
- Ethernet-cable-only loss causing Wi-Fi fallback;
- USB restoration causing Ethernet to become primary again;
- exactly one package-managed `udhcpc` process for `usb0`;
- exactly one route-monitor process.

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

### Repeated Physical Failover and Recovery

Three complete physical ASIX USB removal and reconnection cycles passed.

During each removal:

- the ASIX USB device and `usb0` disappeared;
- USB routes were removed;
- Wi-Fi remained reachable and became the working path.

During each reconnection:

- the ASIX adapter re-enumerated;
- `usb0` was recreated and brought administratively up;
- carrier returned;
- stale DHCP state was replaced with one current-generation DHCP process;
- the Ethernet lease returned;
- the exact USB-primary and Wi-Fi-fallback routes were restored;
- gateway lookups again selected `usb0`.

A separate Ethernet-cable-only link-loss and recovery cycle also passed.
No duplicate monitor or DHCP processes accumulated.

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

## Corrected v1.0.0 Regression Coverage

Automated validation covers:

- firmware metricless Wi-Fi default repair;
- duplicate default-route collapse;
- same-subnet connected-route repair;
- USB `bound`, `renew`, and reconciliation idempotence;
- Wi-Fi route recreation after reconnect;
- USB cable-loss fallback;
- physical-style USB interface destruction and recreation;
- stale DHCP replacement after interface recreation;
- unrelated PID protection;
- missing-route tolerance;
- bounded command-failure handling;
- stale-lock recovery;
- no-op reconciliation without route mutation;
- boot-hook installation;
- marker-gated uninstall refusal;
- boot-hook removal during uninstall;
- verified monitor and DHCP termination;
- bounded TERM-to-SIGKILL process cleanup;
- prevention of runtime-directory deletion while owned processes remain.

Repository tests use mocked network commands, temporary state directories,
temporary resolver files, and mocked sysfs state. They do not modify the
development machine's real routes.

All shell syntax checks, all four regression suites, `package/SHA256SUMS`,
`dist/SHA256SUMS`, archive extraction, and TAR/ZIP content-equivalence checks
passed for the corrected candidate.

## Completed Physical Acceptance

Physical-printer acceptance was completed against the corrected and rebuilt
candidate.

Completed checks included:

- clean installation from the rebuilt TAR archive;
- archive SHA-256 verification on the printer;
- complete installed `package/SHA256SUMS` verification;
- boot-hook installation and startup;
- active USB address `192.168.23.92`;
- Wi-Fi fallback address `192.168.23.169`;
- exact four-route USB-primary/Wi-Fi-fallback state;
- gateway lookup through `usb0` using the USB source address;
- one monitor process and one USB DHCP process;
- three physical USB removal and reconnection cycles;
- one Ethernet-cable-only loss and recovery cycle;
- Wi-Fi fallback during USB or carrier loss;
- restoration of USB-primary routing after recovery;
- no process or route duplication;
- actual `uninstall-usb-ethernet.sh --yes` execution while the adapter remained
  physically connected.

The final uninstall qualification returned `0` and confirmed:

```text
ACTIVE_GATE=PASS
UNINSTALL_RC=0
UNINSTALL_COMMAND=PASS
BOOT_HOOK_ABSENT=PASS
RUNTIME_DIRECTORY_ABSENT=PASS
POST_MONITOR_COUNT=0
POST_DHCP_COUNT=0
CUSTOM_MODULE_COUNT=0
USB0_INTERFACE_ABSENT=PASS
USB_ROUTE_COUNT_ZERO=PASS
WIFI_DEFAULT_PRESENT=PASS
WIFI_CONNECTED_PRESENT=PASS
WIFI_GATEWAY_LOOKUP=PASS
WIFI_GATEWAY_PING=PASS
QUALIFICATION_FAILED=0
UNINSTALL_FIX_QUALIFICATION_OK
FINAL_QUALIFICATION_SSH_EXIT=0
```

The earlier draft requirement for a separate 60-second Wi-Fi-disabled run was
superseded by the completed physical USB-removal, cable-loss, source-route, and
repeated-reconnect checks. These directly exercised both failover directions
while verifying the selected source and output interface.

## Acceptance Rationale

The release is accepted as `GO` for the explicitly documented 2023-generation
Creality K1C kernel ABI and tested ASIX adapter.

The frozen production modules remain unchanged from the previously qualified
module set. The corrected routing runtime passed automated regression,
clean-boot operation, repeated physical failover and recovery, and final
uninstall cleanup.

The historical bounded `EVENT_RX_MEMORY` warning remains disclosed. It did not
recur during the final instrumented transfer run, and the diagnostic counters
did not identify allocation, submission, backlog, or `netif_rx()` failure.

Raw physical-lab evidence is retained privately because it contains local
addresses, usernames, hostnames, and filesystem paths. It is not shipped in the
public release.

Public publication still requires the maintainer-controlled release procedure:
final documentation rebuild, checksum verification, immutable draft release
preparation, asset attachment, release verification, and explicit publication.
