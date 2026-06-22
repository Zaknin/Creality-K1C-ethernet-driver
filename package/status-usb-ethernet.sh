#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
MODULE_DIR="$PACKAGE_DIR/modules"

module_state() {
  name="$1"
  if grep -q "^$name " /proc/modules; then
    awk -v m="$name" '$1 == m { print "loaded refcount=" $3 " deps=" $4 }' /proc/modules
  else
    echo "not loaded"
  fi
}

echo "PACKAGE=$PACKAGE_DIR"
echo "KERNEL=$(uname -r)"
echo
echo "MODULES"
for mod in mii usbnet cdc_ncm; do
  file="$MODULE_DIR/$mod.ko"
  if [ -f "$file" ]; then
    printf '%s hash=' "$mod"
    sha256sum "$file" | awk '{print $1}'
  else
    echo "$mod hash=missing"
  fi
  printf '%s state=' "$mod"
  module_state "$mod"
done

echo
echo "USB_BINDINGS"
for dev in /sys/bus/usb/devices/*; do
  [ -r "$dev/idVendor" ] || continue
  [ -r "$dev/idProduct" ] || continue
  vendor="$(cat "$dev/idVendor" 2>/dev/null || true)"
  product="$(cat "$dev/idProduct" 2>/dev/null || true)"
  [ "$vendor:$product" = "0b95:1790" ] || continue
  for intf in "$dev":*; do
    [ -d "$intf" ] || continue
    number="$(cat "$intf/bInterfaceNumber" 2>/dev/null || echo unknown)"
    class="$(cat "$intf/bInterfaceClass" 2>/dev/null || echo unknown)"
    subclass="$(cat "$intf/bInterfaceSubClass" 2>/dev/null || echo unknown)"
    protocol="$(cat "$intf/bInterfaceProtocol" 2>/dev/null || echo unknown)"
    if [ -L "$intf/driver" ]; then
      driver="$(basename "$(readlink "$intf/driver")")"
    else
      driver="unbound"
    fi
    printf '%s bInterfaceNumber=%s bInterfaceClass=%s bInterfaceSubClass=%s bInterfaceProtocol=%s driver=%s\n' \
      "$(basename "$intf")" "$number" "$class" "$subclass" "$protocol" "$driver"
  done
done

echo
echo "USB0"
if [ -d /sys/class/net/usb0 ]; then
  ip link show dev usb0 2>&1 || true
  printf 'carrier='; cat /sys/class/net/usb0/carrier 2>/dev/null || true
  printf 'operstate='; cat /sys/class/net/usb0/operstate 2>/dev/null || true
  for f in rx_packets tx_packets rx_bytes tx_bytes rx_errors tx_errors rx_dropped tx_dropped; do
    printf '%s=' "$f"
    cat "/sys/class/net/usb0/statistics/$f" 2>/dev/null || true
  done
else
  echo "usb0 not present"
fi

echo
echo "ADDRESSES"
ip addr 2>&1 || true
echo
echo "ROUTES"
ip route 2>&1 || true
echo
echo "RECENT_KERNEL_MESSAGES"
dmesg | grep -E 'cdc_ncm|usbnet|usb0|0b95|1790' | tail -n 80 || true
