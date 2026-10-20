# CDC-NCM RX filter modes — v1.0.5 candidate

The **v1.0.5 candidate reuses the byte-identical CDC-NCM kernel module**
from [v1.0.3](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3).
Its tested binary SHA-256 remains:

```text
f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271
```

The new changes are in the installer/start scripts and release integrity
checks, not in the MIPS driver source or binary. The 2023-generation
K1C/kernel `4.4.94`/ASIX `0b95:1790` scope is unchanged.

## Defaults

| Parameter | Default | Behavior |
|---|---|---|
| `drop_l2_8899` | `Y` | Silently drop Ethernet-II EtherType 0x8899 |
| `rx_ipv4_only` | `N` | Opt-in IPv4, ARP, 802.3-length and outer-VLAN receive allowlist |

After starting the driver, from a root shell on the printer:

```sh
cat /sys/module/cdc_ncm/parameters/drop_l2_8899
cat /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

To test the stricter mode, only where no required service depends
on filtered protocols:

```sh
echo 1 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
```

To restore the recommended defaults:

```sh
echo 0 > /sys/module/cdc_ncm/parameters/rx_ipv4_only
echo 1 > /sys/module/cdc_ncm/parameters/drop_l2_8899
```

Strict mode can drop IPv6, LLDP, PPPoE, EAPOL and other Ethernet-II
protocols. Outer VLAN tags and 802.3 length-coded frames are passed
through, including their nested content. These settings are NOT
persisted after a module reload or reboot.

The laboratory A/B/C driver tests in
[HARDWARE-VALIDATION-2026-10-13.md](HARDWARE-VALIDATION-2026-10-13.md)
apply to the identical binary. On one supported 2023-generation K1C,
v1.0.5 passed a guarded upgrade, reboot autostart, DHCP, carrier-loss
fallback and link-up recovery. Physical clean-install and forced-failure
rollback were not tested. See
[HARDWARE-ACCEPTANCE-v1.0.5.md](HARDWARE-ACCEPTANCE-v1.0.5.md).

## Changes relative to v1.0.3

- Correctly pin the hardware-tested `cdc_ncm.ko` SHA-256 in
  `start-usb-ethernet.sh`, as in the package's hash manifests.
- Check that a boot hook can actually be written to the printer
  root overlay before modifying `/usr/data`.
- Refuse to overwrite an existing installation or unrelated boot hook;
  rollback files created on unsuccessful installation.
- Support installation **without** `--enable-boot` even where root
  overlay cannot accommodate a new init script, with manual startup.

**This does not magically enable boot integration on an already-full
`/overlay`.** Do not delete unrelated printer files or change firmware
just to make the hook fit. Any alternate boot mechanism must be
verified against the exact firmware first.

The independent AX88179B duplicate connection/speed notification
issue ([#1](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1))
remains open; the notification suppression experiment is not included.
