#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"
USB_METRIC="${USB_METRIC:-50}"
WIFI_METRIC="${WIFI_METRIC:-300}"

mkdir -p "$STATE_DIR"

log() {
  printf '%s usb0-udhcpc[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$*" >> "$LOG_FILE"
}

read_first_default_gw() {
  ip route show default dev wlan0 2>/dev/null | awk 'NR == 1 { print $3 }'
}

read_wlan_ip() {
  ip -4 addr show dev wlan0 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }'
}

read_wlan_prefix() {
  ip -4 addr show dev wlan0 2>/dev/null | awk '/ inet / { sub(/.*\//, "", $2); print $2; exit }'
}

route_for_prefix() {
  addr="$1"
  prefix="$2"
  case "$prefix" in
    255.255.255.0) prefix=24 ;;
    255.255.0.0) prefix=16 ;;
    255.0.0.0) prefix=8 ;;
  esac
  case "$prefix" in
    24) echo "$addr" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }' ;;
    16) echo "$addr" | awk -F. '{ print $1 "." $2 ".0.0/16" }' ;;
    8) echo "$addr" | awk -F. '{ print $1 ".0.0.0/8" }' ;;
    *) printf '%s/%s\n' "$addr" "$prefix" ;;
  esac
}

save_fallback_state() {
  [ -s "$STATE_DIR/wifi.gateway" ] || read_first_default_gw > "$STATE_DIR/wifi.gateway"
  [ -s "$STATE_DIR/wifi.ip" ] || read_wlan_ip > "$STATE_DIR/wifi.ip"
  [ -s "$STATE_DIR/wifi.prefix" ] || read_wlan_prefix > "$STATE_DIR/wifi.prefix"
  [ -f "$STATE_DIR/resolv.conf.wifi" ] || cp /etc/resolv.conf "$STATE_DIR/resolv.conf.wifi" 2>/dev/null || true
}

restore_wifi_fallback() {
  wifi_gw="$(cat "$STATE_DIR/wifi.gateway" 2>/dev/null || read_first_default_gw)"
  wifi_ip="$(cat "$STATE_DIR/wifi.ip" 2>/dev/null || read_wlan_ip)"
  wifi_prefix="$(cat "$STATE_DIR/wifi.prefix" 2>/dev/null || read_wlan_prefix)"
  wifi_route=""
  [ -n "$wifi_ip" ] && [ -n "$wifi_prefix" ] && wifi_route="$(route_for_prefix "$wifi_ip" "$wifi_prefix")"
  ip addr flush dev usb0 2>/dev/null || true
  ip route del default dev usb0 2>/dev/null || true
  ip route flush dev usb0 2>/dev/null || true
  if [ -n "$wifi_gw" ]; then
    ip route replace default via "$wifi_gw" dev wlan0 metric 100 2>/dev/null || ip route replace default via "$wifi_gw" dev wlan0 2>/dev/null || true
  fi
  if [ -n "$wifi_route" ]; then
    ip route replace "$wifi_route" dev wlan0 src "$wifi_ip" metric 100 2>/dev/null || true
  fi
  if [ -f "$STATE_DIR/resolv.conf.wifi" ]; then
    cp "$STATE_DIR/resolv.conf.wifi" /etc/resolv.conf 2>/dev/null || true
  fi
  rm -f "$STATE_DIR/usb0.env" "$STATE_DIR/usb0.ip" "$STATE_DIR/usb0.router" "$STATE_DIR/ethernet.active"
  log "fallback restored wifi_gw=$wifi_gw wifi_ip=$wifi_ip"
}

write_usb_dns() {
  : > /etc/resolv.conf
  for ns in ${dns:-}; do
    echo "nameserver $ns # usb0" >> /etc/resolv.conf
  done
}

apply_usb_primary() {
  save_fallback_state
  wifi_gw="$(cat "$STATE_DIR/wifi.gateway" 2>/dev/null || true)"
  wifi_ip="$(cat "$STATE_DIR/wifi.ip" 2>/dev/null || true)"
  wifi_prefix="$(cat "$STATE_DIR/wifi.prefix" 2>/dev/null || true)"
  prefix="${mask:-24}"
  gw="${router:-}"
  wifi_route=""
  [ -n "${ip:-}" ] || { log "bound without ip"; return 1; }
  [ -n "$gw" ] || { log "bound without router"; return 1; }
  usb_route="$(route_for_prefix "$ip" "$prefix")"
  [ -n "$wifi_ip" ] && [ -n "$wifi_prefix" ] && wifi_route="$(route_for_prefix "$wifi_ip" "$wifi_prefix")"

  ip addr flush dev usb0 2>/dev/null || true
  ip addr add "$ip/$prefix" brd "${broadcast:-+}" dev usb0
  ip link set dev usb0 up
  ip route replace default via "$gw" dev usb0 metric "$USB_METRIC"
  ip route replace "$usb_route" dev usb0 src "$ip" metric "$USB_METRIC" 2>/dev/null || true
  if [ -n "$wifi_gw" ]; then
    ip route replace default via "$wifi_gw" dev wlan0 metric "$WIFI_METRIC" 2>/dev/null || true
  fi
  if [ -n "$wifi_route" ]; then
    ip route replace "$wifi_route" dev wlan0 src "$wifi_ip" metric "$WIFI_METRIC" 2>/dev/null || true
  fi
  if [ -n "${dns:-}" ]; then
    write_usb_dns
  fi

  env | sort > "$STATE_DIR/usb0.env"
  printf '%s\n' "$ip" > "$STATE_DIR/usb0.ip"
  printf '%s\n' "$gw" > "$STATE_DIR/usb0.router"
  printf '%s\n' "$USB_METRIC" > "$STATE_DIR/usb0.metric"
  printf '%s\n' "$WIFI_METRIC" > "$STATE_DIR/wifi.metric"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$STATE_DIR/ethernet.active"
  log "ethernet primary ip=$ip/$prefix router=$gw dns=${dns:-none} usb_metric=$USB_METRIC wifi_metric=$WIFI_METRIC"
}

event="${1:-unknown}"
log "event=$event interface=${interface:-unknown} ip=${ip:-none} router=${router:-none} dns=${dns:-none} lease=${lease:-none} carrier=$(cat /sys/class/net/usb0/carrier 2>/dev/null || echo absent)"
case "$event" in
  deconfig)
    restore_wifi_fallback
    ;;
  bound|renew)
    apply_usb_primary
    ;;
  nak|leasefail)
    restore_wifi_fallback
    ;;
  *)
    log "ignored event=$event"
    ;;
esac

exit 0
