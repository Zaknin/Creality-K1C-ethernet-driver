# K1C USB Ethernet v1.0.3

Two independently selectable CDC-NCM RX filter modes:

- drop_l2_8899=Y by default: silently discard EtherType 0x8899.
- rx_ipv4_only=N by default: optional strict IPv4/ARP/LLC/VLAN allowlist, dropping other Ethernet-II EtherTypes.

The Linux 4.4.94 MIPS CDC-NCM module was tested on a 2023-generation Creality K1C with ASIX 0b95:1790. Three modes were each tested twice over 25 seconds: RX drops 25 with both OFF, 16 with 0x8899-only, and zero with strict filtering. All 18 USB gateway pings passed; RX errors, FIFO and missed counters did not increase in measured windows. A watchdog reboot restored the stock module and routes. Traffic rates varied between windows; no speedup is claimed.

The v1.0.2 boot DHCP and Wi-Fi fallback scripts are retained. Strict mode may suppress IPv6 and other L2 protocols. Sysfs changes are runtime-only and reset after reboot. The unrelated notification-spam patch is not included.

Supported: 2023 K1C, kernel 4.4.94, ASIX 0b95:1790. 2025 K1C is not qualified. Verify SHA256SUMS before installation, and keep Wi-Fi enabled during upgrade. An existing package-owned install must be stopped and uninstalled before installing v1.0.3.
