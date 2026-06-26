# Release Qualification

## Verdict

`GO_RUNTIME_AND_SOURCE_QUALIFICATION_COMPLETE`

`v1.0.1` is qualified for the explicitly documented 2023-generation Creality
K1C target running kernel `4.4.94` with module ABI/vermagic
`4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`.

Publication remains a separate maintainer-controlled action. This qualification
record does not itself push commits, create a tag, edit a GitHub release, upload
assets, or publish anything.

## Qualification Anchors

- Runtime-tested commit: `ffa20861042817d09e0b19dd0ca46496897aac0c`
- Runtime-tested TAR SHA-256:
  `f1a67de8a4f47530d9621c18da5e53379e680f26f25c44b1cb6ae8cc8d3efb9a`
- Final documentation/source-work commit before asset regeneration:
  `87189f868206b16edbecaedb487cfa935fe6e81c`
- Runtime physical evidence:
  `physical-probe-reports/v1.0.1-qualification-20260626T104226Z`
- Source-build evidence:
  `source-build-reports/v1.0.1-source-build-20260626T1130Z`

Only documentation, source-build workflow files, qualification metadata, package
metadata, checksum files, and generated archives changed after runtime physical
testing. The installer, runtime scripts, boot hook, route monitor, DHCP helper,
primary-routing library, start/stop/status scripts, uninstall script, boot
disable script, and production modules remain byte-identical to the physically
tested runtime commit.

## Supported Target

- Tested printer generation: 2023-generation Creality K1C
- Board/SoC family: Ingenic X2000 K1C platform
- Kernel: `4.4.94`
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- Vendor defconfig: `x2000_module_base_linux_sfc_nand_defconfig`
- Tested USB adapter: ASIX `0b95:1790`
- Driver binding: ASIX interfaces bound through `cdc_ncm`

The 2025 K1C revision has not been tested. Compatibility with that revision is
unknown and is not claimed. This release does not claim support for other
printers, firmware versions, kernel ABIs, or USB Ethernet chipsets.

## Frozen Production Modules

```text
a66d280aa643319a848260e8ade6373415a61e1e07c73e16dacd33f75ac497d8  modules/mii.ko
8a582cb3f480f86126dacc2b7255b45efcb4fb58d591007e6ba653bee08da85d  modules/usbnet.ko
6ff51a9ec99089245d0cad267ac83d312193bb6818f8cec6519c1983cbe8f2bc  modules/cdc_ncm.ko
```

Do not replace the production modules with source-acceptance outputs. The
accepted source-build `usbnet.ko` differed from the runtime module only because
of its embedded build path; the runtime package keeps the physically qualified
production module hash above.

## Runtime Physical Gates

The v1.0.1 runtime passed:

```text
EXISTING_INSTALL_REFUSAL=PASS
V1_0_0_UNINSTALL_GATE=PASS
ABSOLUTE_PATH_INSTALL=PASS
INSTALL_ONLY_BEHAVIOR=PASS
IMMEDIATE_START_GATE=PASS
REBOOT_PERSISTENCE_GATE=PASS
CABLE_LOSS_FAILOVER=PASS
CABLE_RECOVERY=PASS
USB_REMOVAL_FAILOVER=PASS
USB_RECREATION_GATE=PASS
V1_0_1_UNINSTALL_GATE=PASS
FINAL_REINSTALL_GATE=PASS
```

Physical validation covered installation from the runtime TAR, existing-package
refusal, v1.0.0 uninstall, absolute-path installer invocation, install-only
behavior, explicit start, reboot persistence, Ethernet-cable loss and recovery,
physical USB adapter removal and recreation, v1.0.1 uninstall, and final
reinstall. The final state retained Wi-Fi reachability while preferring USB
Ethernet when healthy.

Accepted route behavior while USB Ethernet is healthy:

```text
default via 192.168.23.100 dev usb0 metric 50
default via 192.168.23.100 dev wlan0 metric 300
192.168.23.0/24 dev usb0 scope link src 192.168.23.92 metric 50
192.168.23.0/24 dev wlan0 scope link src 192.168.23.169 metric 300
```

Validation confirmed one package-managed `udhcpc` process for `usb0`, one
route-monitor process, route recovery without duplication, and cleanup during
uninstall.

## Source-Build Acceptance

`SOURCE_BUILD_ACCEPTANCE=PASS`

The accepted source-build workflow used:

- prepared K1C kernel tree for kernel `4.4.94`;
- Ingenic `mips-linux-gnu-gcc` 7.2.0 toolchain;
- `CONFIG_MODVERSIONS` disabled;
- generated headers matching `4.4.94`;
- the source archive build helpers.

A top-level kernel `Module.symvers` was not required because the tested K1C
configuration has `CONFIG_MODVERSIONS` disabled. Kbuild generated the
module-local `output/modules/Module.symvers` during `modpost`.

All source-build commands exited `0`. All three outputs were ELF32 LSB
MIPS/MIPS32 rel2 modules with vermagic
`4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`. Source-built `mii.ko` and
`cdc_ncm.ko` matched the runtime modules byte-for-byte. Source-built
`usbnet.ko` differed because of its embedded build path; source, ABI,
architecture, compiler family, dependencies, and vermagic matched.

The source archive does not contain compiled `.ko` files, a vendor SDK,
toolchain, firmware, sysroot, or private build tree. Users must separately
obtain compatible external kernel source and toolchain inputs.

## Historical Warning Disclosure

During development, a small bounded burst of
`cdc_ncm ... kevent 2 may have been dropped` messages was observed.

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
