#!/bin/sh
set -u

USB_IF="${USB_IF:-usb0}"
WIFI_IF="${WIFI_IF:-wlan0}"
PACKAGE_DIR="${PACKAGE_DIR:-/usr/data/k1c-usb-ethernet}"
REPORT_DIR="${REPORT_DIR:-/tmp}"
REPORT="${REPORT:-$REPORT_DIR/k1c-route-capability-probe-$(date -u +%Y%m%dT%H%M%SZ).txt}"
USB_METRIC="${USB_METRIC:-50}"
WIFI_METRIC="${WIFI_METRIC:-300}"
KEEP_USB="${KEEP_USB:-0}"
ALLOW_NON_WIFI_SSH="${ALLOW_NON_WIFI_SSH:-0}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-90}"
DETACHED_VERIFY="${DETACHED_VERIFY:-0}"
DETACHED_ROLLBACK_DELAY="${DETACHED_ROLLBACK_DELAY:-8}"
GENERAL_LAN_TEST_IP="${GENERAL_LAN_TEST_IP:-8.8.8.8}"

TMP_DIR="/tmp/k1c-route-probe.$$"
STARTED_USB=0
WATCHDOG_PID=""
USB_DHCP_PID=""
WIFI_IP=""
WIFI_PREFIX=""
WIFI_GW=""
WIFI_CONNECTED_PREFIX=""
USB_IP=""
USB_PREFIX=""
USB_GW=""
USB_CONNECTED_PREFIX=""
SSH_CLIENT_IP=""
TEMP_SSH_ROUTE=0

USB_KERNEL_CONNECTED_EXACT_DELETE="UNSUPPORTED"
WIFI_KERNEL_CONNECTED_EXACT_DELETE="UNSUPPORTED"
WIFI_METRICLESS_DEFAULT_DELETE="UNSUPPORTED"
EXPLICIT_CONNECTED_ROUTE_ADD="UNSUPPORTED"
ROUTE_CACHE_FLUSH="UNSUPPORTED"
WIFI_CONNECTED_ROUTE_INITIAL_TYPE="unknown"
WIFI_CONNECTED_ROUTE_DELETE_FORM="none"
WIFI_CONNECTED_ROUTE_CONVERSION="UNSUPPORTED"
USB_SOURCE_LOOKUP_AFTER_CONVERSION="unknown"
USB_GATEWAY_SRC_AFTER_CONVERSION="unknown"
PROBE_SSH_PRESERVATION_ROUTE_ACTIVE="NO"
PROBE_SSH_PRESERVATION_LOOKUP="not_tested"
USB_GATEWAY_LOOKUP_AFTER_CONVERSION="unknown"
USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION="not_tested"
ROUTE_ONLY_FORWARDING_STATE="NO"
ROLLBACK_WIFI_CONNECTED_RESTORE_FORM="none"
ROLLBACK_WIFI_STATE="FAIL"
SAFE_ROUTE_ONLY_STRATEGY="NO"
USB_CONNECTED_CONVERTED=0
WIFI_CONNECTED_CONVERTED=0
DEFAULTS_CONVERTED=0

mkdir -p "$REPORT_DIR" "$TMP_DIR"

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$REPORT"
}

section() {
  log ""
  log "== $* =="
}

cmd_string() {
  printf '%s' "$*" | sed 's/[	 ][	 ]*/ /g'
}

run_cmd() {
  cmd_label="$1"
  shift
  out="$TMP_DIR/$cmd_label.out"
  err="$TMP_DIR/$cmd_label.err"
  section "$cmd_label"
  log "cmd=$(cmd_string "$@")"
  "$@" >"$out" 2>"$err"
  rc=$?
  log "rc=$rc"
  log "stdout:"
  sed 's/^/  /' "$out" | tee -a "$REPORT"
  log "stderr:"
  sed 's/^/  /' "$err" | tee -a "$REPORT"
  return "$rc"
}

capture_routes() {
  capture_label="$1"
  section "$capture_label"
  ip route show > "$TMP_DIR/$capture_label.routes" 2>"$TMP_DIR/$capture_label.err"
  rc=$?
  log "cmd=ip route show"
  log "rc=$rc"
  log "stdout:"
  sed 's/^/  /' "$TMP_DIR/$capture_label.routes" | tee -a "$REPORT"
  log "stderr:"
  sed 's/^/  /' "$TMP_DIR/$capture_label.err" | tee -a "$REPORT"
  return "$rc"
}

first_ipv4() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }'
}

first_prefix() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/.*\//, "", $2); print $2; exit }'
}

prefix_for_addr() {
  addr="$1"
  prefix="$2"
  case "$prefix" in
    24|"") printf '%s\n' "$addr" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }' ;;
    *) printf '%s/%s\n' "$addr" "$prefix" ;;
  esac
}

default_gw() {
  ip route show default dev "$1" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

same_24() {
  a="$(printf '%s\n' "$1" | awk -F. '{ print $1 "." $2 "." $3 }')"
  b="$(printf '%s\n' "$2" | awk -F. '{ print $1 "." $2 "." $3 }')"
  [ "$a" = "$b" ]
}

route_has_explicit_connected() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" -v metric="$metric" '
      {
        has_src=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "src" && $(i + 1) == src) has_src=1
          if ($i == "metric" && $(i + 1) == metric) has_metric=1
        }
        if (has_src && has_metric) found=1
      }
      END { exit found ? 0 : 1 }'
}

route_has_metricless_connected() {
  prefix="$1"
  dev="$2"
  src="$3"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" '
      {
        has_src=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "src" && $(i + 1) == src) has_src=1
          if ($i == "metric") has_metric=1
        }
        if (has_src && !has_metric) found=1
      }
      END { exit found ? 0 : 1 }'
}

metricless_connected_line() {
  prefix="$1"
  dev="$2"
  src="$3"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" '
      {
        has_src=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "src" && $(i + 1) == src) has_src=1
          if ($i == "metric") has_metric=1
        }
        if (has_src && !has_metric) {
          print
          exit
        }
      }'
}

connected_route_initial_type() {
  line="$1"
  [ -n "$line" ] || {
    printf '%s\n' unknown
    return
  }
  printf '%s\n' "$line" |
    awk '{
      has_proto=0; has_scope=0
      for (i = 1; i <= NF; i++) {
        if ($i == "proto" && $(i + 1) == "kernel") has_proto=1
        if ($i == "scope" && $(i + 1) == "link") has_scope=1
      }
      if (has_proto && has_scope) print "kernel"
      else if (has_scope) print "manual"
      else print "unknown"
    }'
}

metricless_default_exists() {
  gw="$1"
  dev="$2"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v gw="$gw" '
      {
        has_gw=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "via" && $(i + 1) == gw) has_gw=1
          if ($i == "metric") has_metric=1
        }
        if (has_gw && !has_metric) found=1
      }
      END { exit found ? 0 : 1 }'
}

metric_default_exists() {
  gw="$1"
  dev="$2"
  metric="$3"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v gw="$gw" -v metric="$metric" '
      {
        has_gw=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "via" && $(i + 1) == gw) has_gw=1
          if ($i == "metric" && $(i + 1) == metric) has_metric=1
        }
        if (has_gw && has_metric) found=1
      }
      END { exit found ? 0 : 1 }'
}

lookup_dev() {
  ip route get "$1" ${2:+from "$2"} 2>/dev/null |
    awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

lookup_src() {
  ip route get "$1" ${2:+from "$2"} 2>/dev/null |
    awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

lookup_has_via() {
  ip route get "$1" ${2:+from "$2"} 2>/dev/null |
    awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") found=1 } END { exit found ? 0 : 1 }'
}

direct_gateway_verified() {
  gw="$1"
  dev="$2"
  [ "$(lookup_dev "$gw")" = "$dev" ] || return 1
  ! lookup_has_via "$gw" || return 1
  return 0
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
      run_cmd "rollback-del-default-$dev-$i" ip route del default via "$gw" dev "$dev" metric "$metric" || break
    elif [ -n "$gw" ]; then
      run_cmd "rollback-del-default-$dev-$i" ip route del default via "$gw" dev "$dev" || break
    else
      run_cmd "rollback-del-default-$dev-$i" ip route del default dev "$dev" || break
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
      run_cmd "rollback-restore-default-$dev-$metric" ip route replace default via "$gw" dev "$dev" metric "$metric" || true
    else
      run_cmd "rollback-restore-default-$dev-metricless" ip route replace default via "$gw" dev "$dev" || true
    fi
  done < "$file"
}

remove_defaults_for_dev() {
  dev="$1"
  i=0
  while [ "$i" -lt 8 ]; do
    line="$(ip route show default dev "$dev" 2>/dev/null | sed -n '1p')"
    [ -n "$line" ] || return 0
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
      run_cmd "rollback-del-default-$dev-$i" ip route del default via "$gw" dev "$dev" metric "$metric" || break
    elif [ -n "$gw" ]; then
      run_cmd "rollback-del-default-$dev-$i" ip route del default via "$gw" dev "$dev" || break
    else
      run_cmd "rollback-del-default-$dev-$i" ip route del default dev "$dev" || break
    fi
    i=$((i + 1))
  done
}

restore_connected_metricless() {
  dev="$1"
  prefix="$2"
  ip_addr="$3"
  metric="$4"
  gw="${5:-}"
  [ -n "$prefix" ] && [ -n "$ip_addr" ] || return 0
  run_cmd "rollback-del-explicit-$dev-$metric" ip route del "$prefix" dev "$dev" src "$ip_addr" metric "$metric" || true
  for form in scope_link proto_kernel plain; do
    case "$form" in
      scope_link)
        run_cmd "rollback-restore-connected-$dev-$form" ip route replace "$prefix" dev "$dev" scope link src "$ip_addr" || true
        ;;
      proto_kernel)
        run_cmd "rollback-restore-connected-$dev-$form" ip route replace "$prefix" dev "$dev" proto kernel scope link src "$ip_addr" || true
        ;;
      plain)
        run_cmd "rollback-restore-connected-$dev-$form" ip route replace "$prefix" dev "$dev" src "$ip_addr" || true
        ;;
    esac
    if route_has_metricless_connected "$prefix" "$dev" "$ip_addr"; then
      if [ -z "$gw" ] || direct_gateway_verified "$gw" "$dev"; then
        [ "$dev" = "$WIFI_IF" ] && ROLLBACK_WIFI_CONNECTED_RESTORE_FORM="$form"
        log "rollback_connected_restore_verified dev=$dev prefix=$prefix form=$form"
        return 0
      fi
      if [ -n "$gw" ] && ! lookup_has_via "$gw"; then
        [ "$dev" = "$WIFI_IF" ] && ROLLBACK_WIFI_CONNECTED_RESTORE_FORM="$form"
        log "rollback_connected_restore_present_pending_usb_cleanup dev=$dev prefix=$prefix form=$form lookup_dev=$(lookup_dev "$gw")"
        return 0
      fi
    fi
    if [ -n "$gw" ]; then
      if lookup_has_via "$gw"; then via_status=yes; else via_status=no; fi
      log "rollback_connected_restore_verify_failed dev=$dev prefix=$prefix form=$form lookup_dev=$(lookup_dev "$gw") via=$via_status"
    fi
  done
  log "rollback_connected_restore_failed dev=$dev prefix=$prefix"
  return 1
}

verify_wifi_rollback() {
  stage="${1:-final}"
  ok=1
  section "rollback verification"
  wifi_addr_after="$(first_ipv4 "$WIFI_IF")"
  log "rollback_stage=$stage rollback_wifi_ip=${wifi_addr_after:-none} expected=${WIFI_IP:-none}"
  if [ "$wifi_addr_after" = "$WIFI_IP" ]; then
    log "rollback_wifi_address=OK stage=$stage"
  else
    log "rollback_wifi_address=FAIL stage=$stage"
    ok=0
  fi
  if route_has_metricless_connected "$WIFI_CONNECTED_PREFIX" "$WIFI_IF" "$WIFI_IP"; then
    log "rollback_wifi_connected_route=OK stage=$stage"
  else
    log "rollback_wifi_connected_route=FAIL stage=$stage"
    ok=0
  fi
  if metricless_default_exists "$WIFI_GW" "$WIFI_IF"; then
    log "rollback_wifi_default=OK stage=$stage"
  else
    log "rollback_wifi_default=FAIL stage=$stage"
    ok=0
  fi
  gw_dev="$(lookup_dev "$WIFI_GW")"
  if lookup_has_via "$WIFI_GW"; then via_status=yes; else via_status=no; fi
  log "rollback_gateway_lookup_dev=${gw_dev:-unknown} stage=$stage via=$via_status"
  if [ "$gw_dev" = "$WIFI_IF" ] && [ "$via_status" = no ]; then
    log "rollback_gateway_lookup=OK stage=$stage"
  else
    log "rollback_gateway_lookup=FAIL stage=$stage"
    ok=0
  fi
  if command -v ping >/dev/null 2>&1; then
    run_cmd rollback-ping-gateway ping -c 1 -W 2 "$WIFI_GW" || true
  else
    log "rollback_ping_gateway=not_available"
  fi
  [ "$ok" = "1" ] || return 1
  return 0
}

cleanup() {
  section "automatic rollback"
  if [ -n "$SSH_CLIENT_IP" ] && [ "$TEMP_SSH_ROUTE" = "1" ]; then
    run_cmd rollback-del-ssh-host-route ip route del "$SSH_CLIENT_IP/32" dev "$WIFI_IF" || true
    [ -n "$WIFI_GW" ] && run_cmd rollback-del-ssh-host-route-via ip route del "$SSH_CLIENT_IP/32" via "$WIFI_GW" dev "$WIFI_IF" || true
  fi
  restore_defaults_for_dev "$WIFI_IF" "$TMP_DIR/wifi-defaults.before"
  restore_connected_metricless "$WIFI_IF" "$WIFI_CONNECTED_PREFIX" "$WIFI_IP" "$WIFI_METRIC" "$WIFI_GW" || true
  verify_wifi_rollback immediate && ROLLBACK_WIFI_STATE="OK" || ROLLBACK_WIFI_STATE="FAIL"
  remove_defaults_for_dev "$USB_IF"
  [ -n "$USB_CONNECTED_PREFIX" ] && [ -n "$USB_IP" ] && run_cmd rollback-del-usb-explicit ip route del "$USB_CONNECTED_PREFIX" dev "$USB_IF" src "$USB_IP" metric "$USB_METRIC" || true
  [ -n "$USB_CONNECTED_PREFIX" ] && [ -n "$USB_IP" ] && run_cmd rollback-del-usb-metricless ip route del "$USB_CONNECTED_PREFIX" dev "$USB_IF" || true
  if [ -s "$TMP_DIR/udhcpc.pid" ]; then
    USB_DHCP_PID="$(sed -n '1p' "$TMP_DIR/udhcpc.pid" 2>/dev/null || true)"
    [ -n "$USB_DHCP_PID" ] && run_cmd rollback-stop-temporary-udhcpc kill "$USB_DHCP_PID" || true
  fi
  run_cmd rollback-flush-cache ip route flush cache || true
  run_cmd rollback-flush-usb-address ip addr flush dev "$USB_IF" || true
  if [ "$KEEP_USB" != "1" ] && [ "$STARTED_USB" = "1" ] && [ -x "$PACKAGE_DIR/stop-usb-ethernet.sh" ]; then
    run_cmd rollback-stop-usb "$PACKAGE_DIR/stop-usb-ethernet.sh" || true
  fi
  if verify_wifi_rollback post_usb_cleanup; then
    ROLLBACK_WIFI_STATE="OK"
  else
    log "rollback post-usb verification failed; retrying Wi-Fi connected route restore"
    restore_connected_metricless "$WIFI_IF" "$WIFI_CONNECTED_PREFIX" "$WIFI_IP" "$WIFI_METRIC" "$WIFI_GW" || true
    run_cmd rollback-refinal-flush-cache ip route flush cache || true
    verify_wifi_rollback final_retry && ROLLBACK_WIFI_STATE="OK" || ROLLBACK_WIFI_STATE="FAIL"
  fi
  if [ -e /etc/init.d/S46usb_ethernet_primary ]; then
    log "WARN: boot hook path exists after probe: /etc/init.d/S46usb_ethernet_primary"
  else
    log "boot hook absent: /etc/init.d/S46usb_ethernet_primary"
  fi
  run_cmd rollback-final-routes ip route show || true
  rm -rf "$TMP_DIR"
  log "probe cleanup complete keep_usb=$KEEP_USB report=$REPORT"
}

print_matrix() {
  section "capability matrix"
  printf '%s\n' \
    "USB_KERNEL_CONNECTED_EXACT_DELETE=$USB_KERNEL_CONNECTED_EXACT_DELETE" \
    "WIFI_KERNEL_CONNECTED_EXACT_DELETE=$WIFI_KERNEL_CONNECTED_EXACT_DELETE" \
    "WIFI_METRICLESS_DEFAULT_DELETE=$WIFI_METRICLESS_DEFAULT_DELETE" \
    "EXPLICIT_CONNECTED_ROUTE_ADD=$EXPLICIT_CONNECTED_ROUTE_ADD" \
    "ROUTE_CACHE_FLUSH=$ROUTE_CACHE_FLUSH" \
    "WIFI_CONNECTED_ROUTE_INITIAL_TYPE=$WIFI_CONNECTED_ROUTE_INITIAL_TYPE" \
    "WIFI_CONNECTED_ROUTE_DELETE_FORM=$WIFI_CONNECTED_ROUTE_DELETE_FORM" \
    "WIFI_CONNECTED_ROUTE_CONVERSION=$WIFI_CONNECTED_ROUTE_CONVERSION" \
    "PROBE_SSH_PRESERVATION_ROUTE_ACTIVE=$PROBE_SSH_PRESERVATION_ROUTE_ACTIVE" \
    "PROBE_SSH_PRESERVATION_LOOKUP=$PROBE_SSH_PRESERVATION_LOOKUP" \
    "USB_GATEWAY_LOOKUP_AFTER_CONVERSION=$USB_GATEWAY_LOOKUP_AFTER_CONVERSION" \
    "USB_GATEWAY_SRC_AFTER_CONVERSION=$USB_GATEWAY_SRC_AFTER_CONVERSION" \
    "USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION=$USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION" \
    "USB_SOURCE_LOOKUP_AFTER_CONVERSION=$USB_SOURCE_LOOKUP_AFTER_CONVERSION" \
    "ROUTE_ONLY_FORWARDING_STATE=$ROUTE_ONLY_FORWARDING_STATE" \
    "ROLLBACK_WIFI_CONNECTED_RESTORE_FORM=$ROLLBACK_WIFI_CONNECTED_RESTORE_FORM" \
    "ROLLBACK_WIFI_STATE=$ROLLBACK_WIFI_STATE" \
    "SAFE_ROUTE_ONLY_STRATEGY=$SAFE_ROUTE_ONLY_STRATEGY" | tee -a "$REPORT"
}

finish() {
  rc="${1:-0}"
  if [ -n "$WATCHDOG_PID" ]; then
    kill "$WATCHDOG_PID" >/dev/null 2>&1 || true
  fi
  cleanup
  if [ "$ROUTE_ONLY_FORWARDING_STATE" = "YES" ] && [ "$ROLLBACK_WIFI_STATE" = "OK" ]; then
    SAFE_ROUTE_ONLY_STRATEGY="YES"
  else
    SAFE_ROUTE_ONLY_STRATEGY="NO"
  fi
  print_matrix
  exit "$rc"
}

trap 'finish 1' INT TERM

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
log "ssh_client=${SSH_CLIENT:-unknown}"
log "ssh_connection=${SSH_CONNECTION:-unknown}"
run_cmd route-table-before ip route show || true
run_cmd addr-before ip -4 addr show || true

WIFI_IP="$(first_ipv4 "$WIFI_IF")"
WIFI_PREFIX="$(first_prefix "$WIFI_IF")"
WIFI_GW="$(default_gw "$WIFI_IF")"
WIFI_CONNECTED_PREFIX="$(prefix_for_addr "$WIFI_IP" "$WIFI_PREFIX")"
SSH_CLIENT_IP="$(printf '%s\n' "${SSH_CLIENT:-}" | awk '{ print $1 }')"
[ -n "$SSH_CLIENT_IP" ] || SSH_CLIENT_IP="$(printf '%s\n' "${SSH_CONNECTION:-}" | awk '{ print $1 }')"
SSH_SERVER="$(printf '%s\n' "${SSH_CONNECTION:-}" | awk '{ print $3 }')"

ip route show default dev "$WIFI_IF" 2>/dev/null > "$TMP_DIR/wifi-defaults.before"
ip route show default dev "$USB_IF" 2>/dev/null > "$TMP_DIR/usb-defaults.before"

log "wifi_ip=${WIFI_IP:-none} wifi_prefix=${WIFI_PREFIX:-none} wifi_gw=${WIFI_GW:-none} ssh_client_ip=${SSH_CLIENT_IP:-unknown} ssh_server=${SSH_SERVER:-unknown}"
if [ -z "$WIFI_IP" ] || [ -z "$WIFI_GW" ]; then
  log "ERROR: Wi-Fi prerequisites not satisfied; refusing route mutation tests"
  finish 1
fi
if [ -n "$SSH_SERVER" ] && [ "$SSH_SERVER" != "$WIFI_IP" ] && [ "$ALLOW_NON_WIFI_SSH" != "1" ]; then
  log "ERROR: SSH server address does not match $WIFI_IF; set ALLOW_NON_WIFI_SSH=1 only after verifying Wi-Fi access"
  finish 1
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
    case "$prefix" in 255.255.255.0) prefix=24 ;; esac
    printf '%s\n' "${ip:-}" > "$STATE/ip"
    printf '%s\n' "$prefix" > "$STATE/prefix"
    printf '%s\n' "${router:-}" > "$STATE/router"
    ip addr flush dev "${interface:-usb0}" >> "$REPORT" 2>&1 || true
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
else
  log "WARN: udhcpc not found; using existing $USB_IF address if present"
fi

USB_IP="$(cat "$TMP_DIR/ip" 2>/dev/null || first_ipv4 "$USB_IF")"
USB_PREFIX="$(cat "$TMP_DIR/prefix" 2>/dev/null || first_prefix "$USB_IF")"
USB_GW="$(cat "$TMP_DIR/router" 2>/dev/null || default_gw "$USB_IF")"
[ -n "$USB_PREFIX" ] || USB_PREFIX=24
USB_CONNECTED_PREFIX="$(prefix_for_addr "$USB_IP" "$USB_PREFIX")"
log "usb_ip=${USB_IP:-none} usb_prefix=${USB_PREFIX:-none} usb_gw=${USB_GW:-none}"
if [ -z "$USB_IP" ]; then
  log "ERROR: no temporary USB address acquired; route capability tests skipped"
  finish 1
fi

run_cmd route-table-before-tests ip route show || true

if [ -n "$SSH_CLIENT_IP" ] && [ "$DETACHED_VERIFY" != "1" ]; then
  section "ssh preservation route"
  if same_24 "$SSH_CLIENT_IP" "$WIFI_IP"; then
    run_cmd add-ssh-client-host-route ip route replace "$SSH_CLIENT_IP/32" dev "$WIFI_IF" src "$WIFI_IP" || true
  else
    run_cmd add-ssh-client-host-route ip route replace "$SSH_CLIENT_IP/32" via "$WIFI_GW" dev "$WIFI_IF" src "$WIFI_IP" || true
  fi
  TEMP_SSH_ROUTE=1
  PROBE_SSH_PRESERVATION_ROUTE_ACTIVE="YES"
  if [ "$(lookup_dev "$SSH_CLIENT_IP" "$WIFI_IP")" != "$WIFI_IF" ]; then
    log "ERROR: cannot verify SSH client host route through $WIFI_IF; aborting"
    finish 1
  fi
fi

test_connected_delete_sequence() {
  label="$1"
  dev="$2"
  prefix="$3"
  ip_addr="$4"
  metric="$5"
  initial_line="$(metricless_connected_line "$prefix" "$dev" "$ip_addr")"
  initial_type="$(connected_route_initial_type "$initial_line")"
  if [ "$label" = "wifi" ]; then
    WIFI_CONNECTED_ROUTE_INITIAL_TYPE="$initial_type"
  fi

  section "$label explicit connected add"
  if route_has_explicit_connected "$prefix" "$dev" "$ip_addr" "$metric"; then
    log "$label explicit metric route already present before add"
  else
    run_cmd "$label-add-explicit" ip route add "$prefix" dev "$dev" src "$ip_addr" metric "$metric" || true
  fi
  capture_routes "$label-after-explicit-add" || true
  if ! route_has_explicit_connected "$prefix" "$dev" "$ip_addr" "$metric"; then
    log "$label explicit metric route was not installed"
    return 1
  fi
  EXPLICIT_CONNECTED_ROUTE_ADD="SUPPORTED"
  if ! route_has_metricless_connected "$prefix" "$dev" "$ip_addr"; then
    log "$label original metricless route not present before delete tests"
    return 1
  fi

  for form in exact proto_scope proto dev_only; do
    section "$label delete attempt $form"
    case "$form" in
      exact)
        run_cmd "$label-del-exact" ip route del "$prefix" dev "$dev" proto kernel scope link src "$ip_addr" || true
        ;;
      proto_scope)
        run_cmd "$label-del-proto-scope" ip route del "$prefix" dev "$dev" proto kernel scope link || true
        ;;
      proto)
        run_cmd "$label-del-proto" ip route del "$prefix" dev "$dev" proto kernel || true
        ;;
      dev_only)
        run_cmd "$label-del-dev-only" ip route del "$prefix" dev "$dev" || true
        ;;
    esac
    capture_routes "$label-after-delete-$form" || true

    if route_has_explicit_connected "$prefix" "$dev" "$ip_addr" "$metric" &&
       ! route_has_metricless_connected "$prefix" "$dev" "$ip_addr"; then
      log "$label delete form $form removed metricless route and preserved explicit route"
      if [ "$label" = "wifi" ]; then
        WIFI_CONNECTED_ROUTE_DELETE_FORM="$form"
        WIFI_CONNECTED_ROUTE_CONVERSION="SUPPORTED"
      fi
      [ "$form" = "exact" ] && return 0
      return 2
    fi
    if ! route_has_explicit_connected "$prefix" "$dev" "$ip_addr" "$metric"; then
      log "$label delete form $form removed the explicit replacement route; stopping as unsafe"
      return 1
    fi
    if route_has_metricless_connected "$prefix" "$dev" "$ip_addr"; then
      log "$label delete form $form did not remove metricless route; trying next form"
    fi
  done
  return 1
}

section "usb connected route conversion"
test_connected_delete_sequence usb "$USB_IF" "$USB_CONNECTED_PREFIX" "$USB_IP" "$USB_METRIC"
usb_rc=$?
if [ "$usb_rc" -eq 0 ]; then
  USB_KERNEL_CONNECTED_EXACT_DELETE="SUPPORTED"
  USB_CONNECTED_CONVERTED=1
elif [ "$usb_rc" -eq 2 ]; then
  USB_CONNECTED_CONVERTED=1
fi
run_cmd usb-route-after-conversion ip route show "$USB_CONNECTED_PREFIX" dev "$USB_IF" || true
run_cmd usb-lookup-after-conversion ip route get "${USB_GW:-$WIFI_GW}" from "$USB_IP" || true

section "wifi connected route conversion"
if ! route_has_explicit_connected "$WIFI_CONNECTED_PREFIX" "$WIFI_IF" "$WIFI_IP" "$WIFI_METRIC"; then
  run_cmd wifi-preadd-explicit ip route add "$WIFI_CONNECTED_PREFIX" dev "$WIFI_IF" src "$WIFI_IP" metric "$WIFI_METRIC" || true
fi
if ! route_has_explicit_connected "$WIFI_CONNECTED_PREFIX" "$WIFI_IF" "$WIFI_IP" "$WIFI_METRIC"; then
  log "ERROR: safe Wi-Fi replacement route could not be installed; aborting before Wi-Fi metricless deletion"
else
  test_connected_delete_sequence wifi "$WIFI_IF" "$WIFI_CONNECTED_PREFIX" "$WIFI_IP" "$WIFI_METRIC"
  wifi_rc=$?
  if [ "$wifi_rc" -eq 0 ]; then
    WIFI_KERNEL_CONNECTED_EXACT_DELETE="SUPPORTED"
    WIFI_CONNECTED_CONVERTED=1
  elif [ "$wifi_rc" -eq 2 ]; then
    WIFI_CONNECTED_CONVERTED=1
  fi
fi
run_cmd wifi-route-after-conversion ip route show "$WIFI_CONNECTED_PREFIX" dev "$WIFI_IF" || true
[ -n "$SSH_CLIENT_IP" ] && run_cmd wifi-ssh-lookup-after-conversion ip route get "$SSH_CLIENT_IP" from "$WIFI_IP" || true

section "metricless wifi default deletion"
TEST_GW="${USB_GW:-$WIFI_GW}"
run_cmd default-install-usb ip route replace default via "$TEST_GW" dev "$USB_IF" metric "$USB_METRIC" || true
run_cmd default-install-wifi ip route replace default via "$WIFI_GW" dev "$WIFI_IF" metric "$WIFI_METRIC" || true
capture_routes default-before-metricless-delete || true
if metricless_default_exists "$WIFI_GW" "$WIFI_IF"; then
  run_cmd default-del-wifi-metricless ip route del default via "$WIFI_GW" dev "$WIFI_IF" || true
  capture_routes default-after-metricless-delete || true
  if ! metricless_default_exists "$WIFI_GW" "$WIFI_IF" &&
     metric_default_exists "$WIFI_GW" "$WIFI_IF" "$WIFI_METRIC" &&
     metric_default_exists "$TEST_GW" "$USB_IF" "$USB_METRIC"; then
    WIFI_METRICLESS_DEFAULT_DELETE="SUPPORTED"
    DEFAULTS_CONVERTED=1
  elif ! metric_default_exists "$WIFI_GW" "$WIFI_IF" "$WIFI_METRIC"; then
    log "metricless default delete removed the metric-$WIFI_METRIC Wi-Fi default too; testing metric-0 syntax after restore"
    run_cmd default-restore-wifi-metricless ip route replace default via "$WIFI_GW" dev "$WIFI_IF" || true
    run_cmd default-restore-wifi-metric ip route replace default via "$WIFI_GW" dev "$WIFI_IF" metric "$WIFI_METRIC" || true
    run_cmd default-del-wifi-metric0 ip route del default via "$WIFI_GW" dev "$WIFI_IF" metric 0 || true
    capture_routes default-after-metric0-delete || true
    if ! metricless_default_exists "$WIFI_GW" "$WIFI_IF" &&
       metric_default_exists "$WIFI_GW" "$WIFI_IF" "$WIFI_METRIC"; then
      WIFI_METRICLESS_DEFAULT_DELETE="SUPPORTED"
      DEFAULTS_CONVERTED=1
    fi
  fi
else
  log "metricless Wi-Fi default was not present; deletion capability remains unsupported"
fi

section "final lookup verification"
if [ "$DETACHED_VERIFY" = "1" ] && [ -n "$SSH_CLIENT_IP" ]; then
  run_cmd final-del-ssh-host-route ip route del "$SSH_CLIENT_IP/32" dev "$WIFI_IF" || true
  TEMP_SSH_ROUTE=0
  PROBE_SSH_PRESERVATION_ROUTE_ACTIVE="NO"
fi
if run_cmd final-flush-route-cache ip route flush cache; then
  ROUTE_CACHE_FLUSH="SUPPORTED"
fi
run_cmd final-lookup-general-lan ip route get "$GENERAL_LAN_TEST_IP" from "$USB_IP" || true
run_cmd final-lookup-gateway ip route get "$TEST_GW" || true
run_cmd final-lookup-gateway-from-usb ip route get "$TEST_GW" from "$USB_IP" || true
[ -n "$SSH_CLIENT_IP" ] && run_cmd final-lookup-ssh-from-usb ip route get "$SSH_CLIENT_IP" from "$USB_IP" || true
[ -n "$SSH_CLIENT_IP" ] && run_cmd final-lookup-ssh-from-wifi ip route get "$SSH_CLIENT_IP" from "$WIFI_IP" || true
USB_GATEWAY_LOOKUP_AFTER_CONVERSION="$(lookup_dev "$TEST_GW" "$USB_IP")"
[ -n "$USB_GATEWAY_LOOKUP_AFTER_CONVERSION" ] || USB_GATEWAY_LOOKUP_AFTER_CONVERSION="unknown"
USB_GATEWAY_SRC_AFTER_CONVERSION="$(lookup_src "$TEST_GW")"
[ -n "$USB_GATEWAY_SRC_AFTER_CONVERSION" ] || USB_GATEWAY_SRC_AFTER_CONVERSION="unknown"
USB_SOURCE_LOOKUP_AFTER_CONVERSION="$USB_GATEWAY_LOOKUP_AFTER_CONVERSION"
USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION="$(lookup_dev "$GENERAL_LAN_TEST_IP" "$USB_IP")"
[ -n "$USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION" ] || USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION="unknown"
[ -n "$SSH_CLIENT_IP" ] && PROBE_SSH_PRESERVATION_LOOKUP="$(lookup_dev "$SSH_CLIENT_IP" "$USB_IP")"
[ -n "$PROBE_SSH_PRESERVATION_LOOKUP" ] || PROBE_SSH_PRESERVATION_LOOKUP="unknown"
ssh_lookup_ok=1
[ -n "$SSH_CLIENT_IP" ] && [ "$PROBE_SSH_PRESERVATION_LOOKUP" != "$USB_IF" ] && ssh_lookup_ok=0
if [ "$USB_CONNECTED_CONVERTED" = "1" ] &&
   [ "$WIFI_CONNECTED_CONVERTED" = "1" ] &&
   [ "$DEFAULTS_CONVERTED" = "1" ] &&
   route_has_explicit_connected "$USB_CONNECTED_PREFIX" "$USB_IF" "$USB_IP" "$USB_METRIC" &&
   route_has_explicit_connected "$WIFI_CONNECTED_PREFIX" "$WIFI_IF" "$WIFI_IP" "$WIFI_METRIC" &&
   ! route_has_metricless_connected "$USB_CONNECTED_PREFIX" "$USB_IF" "$USB_IP" &&
   ! route_has_metricless_connected "$WIFI_CONNECTED_PREFIX" "$WIFI_IF" "$WIFI_IP" &&
   metric_default_exists "$TEST_GW" "$USB_IF" "$USB_METRIC" &&
   metric_default_exists "$WIFI_GW" "$WIFI_IF" "$WIFI_METRIC" &&
   ! metricless_default_exists "$WIFI_GW" "$WIFI_IF" &&
   [ "$ROUTE_CACHE_FLUSH" = "SUPPORTED" ] &&
   [ "$USB_GATEWAY_LOOKUP_AFTER_CONVERSION" = "$USB_IF" ] &&
   [ "$USB_GATEWAY_SRC_AFTER_CONVERSION" = "$USB_IP" ] &&
   [ "$USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION" = "$USB_IF" ] &&
   [ "$ssh_lookup_ok" = "1" ] &&
   [ "$USB_SOURCE_LOOKUP_AFTER_CONVERSION" = "$USB_IF" ]; then
  ROUTE_ONLY_FORWARDING_STATE="YES"
fi

if [ "$DETACHED_VERIFY" = "1" ]; then
  log "detached verification sleeping ${DETACHED_ROLLBACK_DELAY}s before rollback"
  sleep "$DETACHED_ROLLBACK_DELAY"
fi
log "probe complete; no runtime strategy is accepted until this report is reviewed"
finish 0
