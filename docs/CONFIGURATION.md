# Configuration

Runtime settings are copied to the printer as:

```text
/usr/data/k1c-usb-ethernet-local/runtime/config.conf.example
```

Create your editable copy on the printer:

```sh
ssh "$PRINTER_HOST"
cp /usr/data/k1c-usb-ethernet-local/runtime/config.conf.example \
   /usr/data/k1c-usb-ethernet-local/runtime/config.conf
vi /usr/data/k1c-usb-ethernet-local/runtime/config.conf
```

## Settings

`USB_IFACE`
: Default: `usb0`. The USB Ethernet interface name. Most users should leave this unchanged.

`WIFI_IFACE`
: Default: `wlan0`. The Wi-Fi interface used for fallback-route checks. Change it only if your printer uses a different Wi-Fi interface name.

`KEEP_WIFI_FALLBACK`
: Default: `1`. When set to `1`, `runtime/start-primary-ethernet.sh` skips replacing the default route if a Wi-Fi default route already exists. When set to `0`, `runtime/start-primary-ethernet.sh` may replace the default route with `usb0` after `usb0` gets an IPv4 address.

`USB_DHCP_TIMEOUT`
: Default: `20`. Timeout passed to `udhcpc` when `runtime/start-usb-ethernet.sh` asks for an address on `usb0`. Ordinary users may increase it if DHCP is slow.

`INSTALL_DIR`
: Default: `/usr/data/k1c-usb-ethernet-local`. Where the package is installed on the printer. Most users should leave this unchanged.

`BOOT_HOOK`
: Default: `/etc/init.d/usb_ethernet_primary`. The enabled startup hook path. Change it only if you know your printer's init setup.

`DISABLED_BOOT_HOOK`
: Default: `/etc/init.d/usb_ethernet_primary.disabled`. The disabled startup hook path. Most users should leave this unchanged.

## Safer First Test

Use this for the first manual test:

```sh
KEEP_WIFI_FALLBACK=1
```

With this setting, `start-primary-ethernet.sh` will not replace the default route while a Wi-Fi default route is present.

## Ethernet Routing Test

Use this only when you have Wi-Fi SSH or another recovery path:

```sh
KEEP_WIFI_FALLBACK=0
```

With this setting, `start-primary-ethernet.sh` may run:

```sh
ip route replace default dev usb0 metric 10
```

That can make Ethernet the primary default route. If the Ethernet network is wrong, you can lose access. Keep recovery ready before testing.
