#!/bin/sh
set -u

USB_IF="${USB_IF:-usb0}"
WIFI_IF="${WIFI_IF:-wlan0}"
PACKAGE_DIR="${PACKAGE_DIR:-/usr/data/k1c-usb-ethernet}"
REPORT_DIR="${REPORT_DIR:-/tmp}"
REPORT="${REPORT:-$REPORT_DIR/k1c-route-capability-probe-$(date -u +%Y%m%dT%H%M%SZ).txt}"
USB_METRIC="${USB_METRIC:-50}"
WIFI_METRIC="${WIFI_METRIC:-300}"
DEFAULT_TEST_METRIC="${DEFAULT_TEST_METRIC:-301}"
KEEP_USB="${KEEP_USB:-0}"
ALLOW_NON_WIFI_SSH="${ALLOW_NON_WIFI_SSH:-0}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-75}"

STARTED_USB=0
STARTED_DHCP=0
USB_DHCP_PID=""
TMP_DIR="/tmp/k1c-route-probe.$$"

mkdir -p "$REPORT_DIR" "$TMP_DIR"

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$REPORT"
}

section() {
  log ""
  log "== $* =="
}

cmd_quote() {
  printf '%s' "$*" | sed 's/[	 ][	 ]*/ /g'
}

run_cmd() {
  label="$1"
  shift
  out="$TMP_DIR/$label.out"
  err="$TMP_DIR/$label.err"
  section "$label"
  log "cmd=$(cmd_quote "$@")"
  "$@" >"$out" 2>"$err"
  rc=$?
  log "rc=$rc"
  log "stdout:"
  sed 's/^/  /' "$out" | tee -a "$REPORT"
  log "stderr:"
  sed 's/^/  /' "$err" | tee -a "$REPORT"
  return "$rc"
}

first_ipv4() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }'
}

first_prefix() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/.*\//, "", $2); print $2; exit }'
}

prefix24() {
  printf '%s\n' "$1" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }'
}

default_gw() {
  ip route show default dev "$1" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

restore_defaults_for_dev() {
  dev="$1"
  file="$2"
  i=0
  while [ "$i" -lt 8 ]; do
    line="$(ip route show default dev "$dev" 2>/dev/null | sed -n '1p')"
    [ -n "$line" ] || break
    set -- $line
    gw=""
    metric=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        via) gw="$2"; shift 2 ;;
        metric) metric="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [ -n "$gw" ] && [ -n "$metric" ]; then
      ip route del default via "$gw" dev "$dev" metric "$metric" >/dev/null 2>&1 || break
    elif [ -n "$gw" ]; then
      ip route del default via "$gw" dev "$dev" >/dev/null 2>&1 || break
    else
      ip route del default dev "$dev" >/dev/null 2>&1 || break
    fi
    i=$((i + 1))
  done
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    set -- $line
    [ "${1:-}" = "default" ] || continue
    gw=""
    metric=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        via) gw="$2"; shift 2 ;;
        metric) metric="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$gw" ] || continue
    if [ -n "$metric" ]; then
      ip route replace default via "$gw" dev "$dev" metric "$metric" >/dev/null 2>&1 || true
    else
      ip route replace default via "$gw" dev "$dev" >/dev/null 2>&1 || true
    fi
  done < "$file"
}

restore_connected_metric() {
  dev="$1"
  ip_addr="$2"
  prefix="$3"
  original="$4"
  [ -n "$ip_addr" ] && [ -n "$prefix" ] || return 0
  route_prefix="$(prefix24 "$ip_addr")"
  case "$prefix" in
    24) : ;;
    *) route_prefix="$ip_addr/$prefix" ;;
  esac
  metric="$(printf '%s\n' "$original" | awk '{ for (i = 1; i <= NF; i++) if ($i == "metric") { print $(i + 1); exit } }')"
  if [ -n "$metric" ]; then
    ip route change "$route_prefix" dev "$dev" proto kernel scope link src "$ip_addr" metric "$metric" >/dev/null 2>&1 || true
  else
    ip route change "$route_prefix" dev "$dev" proto kernel scope link src "$ip_addr" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  section "automatic restore"
  restore_connected_metric "$WIFI_IF" "$WIFI_IP" "$WIFI_PREFIX" "$WIFI_CONNECTED_ORIG"
  restore_defaults_for_dev "$WIFI_IF" "$TMP_DIR/wifi-defaults.before"
  if [ -n "${USB_IP:-}" ] && [ -n "${USB_PREFIX:-}" ]; then
    restore_connected_metric "$USB_IF" "$USB_IP" "$USB_PREFIX" "$USB_CONNECTED_ORIG"
  fi
  restore_defaults_for_dev "$USB_IF" "$TMP_DIR/usb-defaults.before"
  [ -n "$USB_DHCP_PID" ] && kill "$USB_DHCP_PID" >/dev/null 2>&1 || true
  ip addr flush dev "$USB_IF" >/dev/null 2>&1 || true
  if [ "$KEEP_USB" != "1" ] && [ "$STARTED_USB" = "1" ] && [ -x "$PACKAGE_DIR/stop-usb-ethernet.sh" ]; then
    "$PACKAGE_DIR/stop-usb-ethernet.sh" >>"$REPORT" 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
  log "probe cleanup complete keep_usb=$KEEP_USB report=$REPORT"
}

trap cleanup EXIT INT TERM

(
  sleep "$TIMEOUT_SECONDS"
  log "ERROR: timeout ${TIMEOUT_SECONDS}s reached; terminating probe"
  kill "$$" >/dev/null 2>&1 || true
) &
WATCHDOG_PID=$!

: > "$REPORT"
section "identity and prerequisites"
log "report=$REPORT"
log "kernel=$(uname -r 2>/dev/null || echo unknown)"
log "ip_version=$(ip -V 2>&1 || echo unknown)"
log "busybox=$(busybox 2>&1 | sed -n '1p')"
run_cmd route-table-before ip route show || true
run_cmd addr-before ip -4 addr show || true

WIFI_IP="$(first_ipv4 "$WIFI_IF")"
WIFI_PREFIX="$(first_prefix "$WIFI_IF")"
WIFI_GW="$(default_gw "$WIFI_IF")"
WIFI_CONNECTED_PREFIX="$(prefix24 "$WIFI_IP")"
WIFI_CONNECTED_ORIG="$(ip route show "$WIFI_CONNECTED_PREFIX" dev "$WIFI_IF" 2>/dev/null | sed -n '1p')"
ip route show default dev "$WIFI_IF" 2>/dev/null > "$TMP_DIR/wifi-defaults.before"
ip route show default dev "$USB_IF" 2>/dev/null > "$TMP_DIR/usb-defaults.before"

SSH_SERVER="$(printf '%s\n' "${SSH_CONNECTION:-}" | awk '{ print $3 }')"
log "ssh_server=${SSH_SERVER:-unknown} wifi_ip=${WIFI_IP:-none} wifi_gw=${WIFI_GW:-none}"
if [ -z "$WIFI_IP" ] || [ -z "$WIFI_GW" ]; then
  log "ERROR: Wi-Fi prerequisites not satisfied; refusing to run route mutation tests"
  exit 1
fi
if [ -n "$SSH_SERVER" ] && [ "$SSH_SERVER" != "$WIFI_IP" ] && [ "$ALLOW_NON_WIFI_SSH" != "1" ]; then
  log "ERROR: SSH server address does not match $WIFI_IF; set ALLOW_NON_WIFI_SSH=1 only if you verified Wi-Fi access"
  exit 1
fi

section "start usb without production routing"
if [ -x "$PACKAGE_DIR/start-usb-ethernet.sh" ]; then
  run_cmd start-usb-modules "$PACKAGE_DIR/start-usb-ethernet.sh" --up || true
  STARTED_USB=1
else
  run_cmd link-set-usb-up ip link set dev "$USB_IF" up || true
fi

cat > "$TMP_DIR/udhcpc-script.sh" <<'EOS'
#!/bin/sh
set -u
REPORT="${PROBE_REPORT:-/tmp/k1c-route-capability-probe-udhcpc.txt}"
STATE="${PROBE_STATE:-/tmp}"
printf '%s udhcpc event=%s interface=%s ip=%s router=%s mask=%s dns=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1:-unknown}" "${interface:-unknown}" "${ip:-}" "${router:-}" "${subnet:-${mask:-}}" "${dns:-}" >> "$REPORT"
case "${1:-}" in
  bound|renew)
    prefix="${subnet:-${mask:-24}}"
    case "$prefix" in
      255.255.255.0) prefix=24 ;;
    esac
    printf '%s\n' "${ip:-}" > "$STATE/ip"
    printf '%s\n' "$prefix" > "$STATE/prefix"
    printf '%s\n' "${router:-}" > "$STATE/router"
    ip addr flush dev "${interface:-usb0}" >/dev/null 2>&1 || true
    ip addr add "$ip/$prefix" brd "${broadcast:-+}" dev "${interface:-usb0}" >> "$REPORT" 2>&1 || exit 1
    ip link set dev "${interface:-usb0}" up >> "$REPORT" 2>&1 || exit 1
    ;;
esac
exit 0
EOS
chmod 755 "$TMP_DIR/udhcpc-script.sh"

if command -v udhcpc >/dev/null 2>&1; then
  section "temporary usb dhcp"
  PROBE_REPORT="$REPORT" PROBE_STATE="$TMP_DIR" udhcpc -i "$USB_IF" -n -q -t 3 -T 4 -s "$TMP_DIR/udhcpc-script.sh" -p "$TMP_DIR/udhcpc.pid" >>"$REPORT" 2>&1 || true
  STARTED_DHCP=1
else
  log "WARN: udhcpc not found; using existing $USB_IF address if present"
fi

USB_IP="$(cat "$TMP_DIR/ip" 2>/dev/null || first_ipv4 "$USB_IF")"
USB_PREFIX="$(cat "$TMP_DIR/prefix" 2>/dev/null || first_prefix "$USB_IF")"
USB_GW="$(cat "$TMP_DIR/router" 2>/dev/null || true)"
[ -n "$USB_PREFIX" ] || USB_PREFIX=24
USB_CONNECTED_PREFIX="$(prefix24 "$USB_IP")"
USB_CONNECTED_ORIG="$(ip route show "$USB_CONNECTED_PREFIX" dev "$USB_IF" 2>/dev/null | sed -n '1p')"
log "usb_ip=${USB_IP:-none} usb_prefix=${USB_PREFIX:-none} usb_gw=${USB_GW:-none}"
if [ -z "$USB_IP" ]; then
  log "ERROR: no temporary USB address acquired; route capability tests skipped"
  exit 1
fi

run_cmd route-table-before-tests ip route show || true

section "capability tests"
run_cmd change-usb-kernel-connected-exact ip route change "$USB_CONNECTED_PREFIX" dev "$USB_IF" proto kernel scope link src "$USB_IP" metric "$USB_METRIC" || true
run_cmd route-after-usb-connected-change ip route show "$USB_CONNECTED_PREFIX" dev "$USB_IF" || true
run_cmd lookup-usb-source ip route get "${USB_GW:-$WIFI_GW}" from "$USB_IP" || true

run_cmd change-wifi-kernel-connected-exact ip route change "$WIFI_CONNECTED_PREFIX" dev "$WIFI_IF" proto kernel scope link src "$WIFI_IP" metric "$WIFI_METRIC" || true
run_cmd route-after-wifi-connected-change ip route show "$WIFI_CONNECTED_PREFIX" dev "$WIFI_IF" || true

run_cmd change-wifi-default-in-place ip route change default via "$WIFI_GW" dev "$WIFI_IF" metric "$DEFAULT_TEST_METRIC" || true
run_cmd route-after-wifi-default-change ip route show default dev "$WIFI_IF" || true

run_cmd delete-exact-wifi-default ip route del default via "$WIFI_GW" dev "$WIFI_IF" metric "$DEFAULT_TEST_METRIC" || true
run_cmd restore-wifi-default-test ip route replace default via "$WIFI_GW" dev "$WIFI_IF" metric "$DEFAULT_TEST_METRIC" || true

run_cmd flush-route-cache ip route flush cache || true
run_cmd source-specific-usb-lookup ip route get "${USB_GW:-$WIFI_GW}" from "$USB_IP" || true
run_cmd source-specific-wifi-lookup ip route get "$WIFI_GW" from "$WIFI_IP" || true
run_cmd route-table-after-tests ip route show || true

kill "$WATCHDOG_PID" >/dev/null 2>&1 || true
log "probe complete; no capability is accepted until this report is reviewed"
