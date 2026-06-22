#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"

echo "PACKAGE=$PACKAGE_DIR"
echo "POLICY_ROUTING=unavailable_on_this_kernel"
echo "POLICY_ROUTING_PROBE=$(ip rule show 2>&1 | head -n 1)"
echo "ROUTING_MODE=route_metrics_with_same_subnet_limitation"
echo
echo "STATE"
for f in wifi.ip wifi.gateway wifi.metric usb0.ip usb0.router usb0.metric ethernet.active udhcpc-usb0.pid usb0-monitor.pid; do
  if [ -f "$STATE_DIR/$f" ]; then
    printf '%s=' "$f"
    cat "$STATE_DIR/$f"
  else
    echo "$f=missing"
  fi
done
echo
echo "LINKS"
ip -brief addr show wlan0 2>&1 || true
ip -brief addr show usb0 2>&1 || true
if [ -d /sys/class/net/usb0 ]; then
  printf 'usb0_carrier='; cat /sys/class/net/usb0/carrier 2>/dev/null || true
fi
echo
echo "ROUTES"
ip route 2>&1 || true
echo
echo "DNS"
cat /etc/resolv.conf 2>/dev/null || true
echo
echo "ROUTE_GET"
ip route get 8.8.8.8 2>&1 || true
if [ -s "$STATE_DIR/usb0.ip" ]; then
  ip route get 8.8.8.8 from "$(cat "$STATE_DIR/usb0.ip")" 2>&1 || true
fi
if [ -s "$STATE_DIR/wifi.ip" ]; then
  ip route get 8.8.8.8 from "$(cat "$STATE_DIR/wifi.ip")" 2>&1 || true
fi
echo
"$PACKAGE_DIR/status-usb-ethernet.sh"
