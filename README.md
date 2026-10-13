# Creality K1C USB Ethernet Driver v1.0.3

Ready-to-install Ethernet for 2023-generation Creality K1C, Linux 4.4.94, with ASIX 0b95:1790 USB Ethernet.

Two independent CDC-NCM RX parameters: drop_l2_8899=Y (default) and rx_ipv4_only=N (default). The strict mode is opt-in and can block IPv6, LLDP, EAPOL, PPPoE and other non-IPv4 Ethernet protocols. Parameter changes via sysfs reset on reboot.

See docs/FILTER-MODES-v1.0.3.md for commands and docs/HARDWARE-VALIDATION-2026-10-13.md for device evidence.
Issue #1 notification-spam patch is NOT included.
