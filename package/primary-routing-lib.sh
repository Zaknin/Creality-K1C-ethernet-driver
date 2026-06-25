#!/bin/sh

USB_IF="${USB_IF:-usb0}"
WIFI_IF="${WIFI_IF:-wlan0}"
USB_METRIC="${USB_METRIC:-50}"
WIFI_METRIC="${WIFI_METRIC:-300}"
WIFI_RESTORE_METRIC="${WIFI_RESTORE_METRIC:-100}"
ROUTE_DELETE_MAX="${ROUTE_DELETE_MAX:-12}"
ROUTE_LOCK_WAIT="${ROUTE_LOCK_WAIT:-8}"
ROUTE_LOCK_STALE="${ROUTE_LOCK_STALE:-60}"
SYS_CLASS_NET="${SYS_CLASS_NET:-/sys/class/net}"
RESOLV_CONF="${RESOLV_CONF:-/etc/resolv.conf}"
LOG_CONTEXT="${LOG_CONTEXT:-routing}"
STATE_DIR="${STATE_DIR:-${PACKAGE_DIR:-.}/state}"
LOG_FILE="${LOG_FILE:-${PACKAGE_DIR:-.}/primary-ethernet.log}"
ROUTE_LOCK_DIR="${ROUTE_LOCK_DIR:-$STATE_DIR/route.lock}"

route_log() {
  printf '%s %s[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LOG_CONTEXT" "$$" "$*" >> "$LOG_FILE"
}

file_value() {
  [ -f "$1" ] || return 1
  sed -n '1p' "$1" 2>/dev/null
}

carrier_value() {
  cat "$SYS_CLASS_NET/$1/carrier" 2>/dev/null || echo absent
}

operstate_value() {
  cat "$SYS_CLASS_NET/$1/operstate" 2>/dev/null || echo unknown
}

link_has_no_carrier() {
  ip link show dev "$1" 2>/dev/null | grep -q 'NO-CARRIER'
}

iface_exists() {
  [ -d "$SYS_CLASS_NET/$1" ] || ip link show dev "$1" >/dev/null 2>&1
}

route_now() {
  date +%s 2>/dev/null || echo 0
}

acquire_route_lock() {
  mkdir -p "$STATE_DIR"
  waited=0
  while [ "$waited" -le "$ROUTE_LOCK_WAIT" ]; do
    if mkdir "$ROUTE_LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" > "$ROUTE_LOCK_DIR/pid"
      route_now > "$ROUTE_LOCK_DIR/time"
      return 0
    fi
    now="$(route_now)"
    then="$(file_value "$ROUTE_LOCK_DIR/time" 2>/dev/null || echo 0)"
    age=$((now - then))
    if [ "$then" != "0" ] && [ "$age" -gt "$ROUTE_LOCK_STALE" ]; then
      route_log "route_lock stale age=${age}s removing"
      rm -rf "$ROUTE_LOCK_DIR"
      continue
    fi
    sleep 1
    waited=$((waited + 1))
  done
  route_log "route_lock timeout wait=${ROUTE_LOCK_WAIT}s owner=$(file_value "$ROUTE_LOCK_DIR/pid" 2>/dev/null || echo unknown)"
  return 1
}

release_route_lock() {
  owner="$(file_value "$ROUTE_LOCK_DIR/pid" 2>/dev/null || true)"
  [ "$owner" = "$$" ] && rm -rf "$ROUTE_LOCK_DIR"
}

mask_to_prefix() {
  case "$1" in
    255.255.255.255) echo 32 ;;
    255.255.255.252) echo 30 ;;
    255.255.255.248) echo 29 ;;
    255.255.255.240) echo 28 ;;
    255.255.255.224) echo 27 ;;
    255.255.255.192) echo 26 ;;
    255.255.255.128) echo 25 ;;
    255.255.255.0) echo 24 ;;
    255.255.254.0) echo 23 ;;
    255.255.252.0) echo 22 ;;
    255.255.248.0) echo 21 ;;
    255.255.240.0) echo 20 ;;
    255.255.224.0) echo 19 ;;
    255.255.192.0) echo 18 ;;
    255.255.128.0) echo 17 ;;
    255.255.0.0) echo 16 ;;
    255.254.0.0) echo 15 ;;
    255.252.0.0) echo 14 ;;
    255.248.0.0) echo 13 ;;
    255.240.0.0) echo 12 ;;
    255.224.0.0) echo 11 ;;
    255.192.0.0) echo 10 ;;
    255.128.0.0) echo 9 ;;
    255.0.0.0) echo 8 ;;
    *) echo "$1" ;;
  esac
}

normalize_prefix() {
  case "$1" in
    *.*.*.*) mask_to_prefix "$1" ;;
    *) echo "$1" ;;
  esac
}

route_for_prefix() {
  addr="$1"
  prefix="$(normalize_prefix "$2")"
  case "$prefix" in
    24) echo "$addr" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }' ;;
    16) echo "$addr" | awk -F. '{ print $1 "." $2 ".0.0/16" }' ;;
    8) echo "$addr" | awk -F. '{ print $1 ".0.0.0/8" }' ;;
    32) printf '%s/32\n' "$addr" ;;
    *) printf '%s/%s\n' "$addr" "$prefix" ;;
  esac
}

first_default_gw() {
  ip route show default dev "$1" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

iface_ipv4() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }'
}

iface_prefix() {
  ip -4 addr show dev "$1" 2>/dev/null | awk '/ inet / { sub(/.*\//, "", $2); print $2; exit }'
}

route_has_metric() {
  awk -v metric="$1" '{
    found=0
    for (i = 1; i <= NF; i++) {
      if ($i == "metric" && $(i + 1) == metric) found=1
    }
    if (found) print
  }'
}

route_without_metric() {
  awk '{
    found=0
    for (i = 1; i <= NF; i++) if ($i == "metric") found=1
    if (!found) print
  }'
}

count_lines() {
  awk 'NF { n++ } END { print n + 0 }'
}

matching_default_count() {
  dev="$1"
  gw="$2"
  metric="$3"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v gw="$gw" -v metric="$metric" '{
      has_gw=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "via" && $(i + 1) == gw) has_gw=1
        if ($i == "metric" && $(i + 1) == metric) has_metric=1
      }
      if (has_gw && has_metric) n++
    } END { print n + 0 }'
}

stale_default_count() {
  dev="$1"
  gw="$2"
  metric="$3"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v gw="$gw" -v metric="$metric" '{
      has_gw=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "via" && $(i + 1) == gw) has_gw=1
        if ($i == "metric" && $(i + 1) == metric) has_metric=1
      }
      if (!has_gw || !has_metric) n++
    } END { print n + 0 }'
}

connected_bad_count() {
  prefix="$1"
  dev="$2"
  metric="$3"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v metric="$metric" '{
      has_metric=0
      for (i = 1; i <= NF; i++) if ($i == "metric" && $(i + 1) == metric) has_metric=1
      if (!has_metric) n++
    } END { print n + 0 }'
}

connected_any_count() {
  prefix="$1"
  dev="$2"
  ip route show "$prefix" dev "$dev" 2>/dev/null | count_lines
}

connected_matching_count() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" -v metric="$metric" '{
      has_src=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "src" && $(i + 1) == src) has_src=1
        if ($i == "metric" && $(i + 1) == metric) has_metric=1
      }
      if (has_src && has_metric) n++
    } END { print n + 0 }'
}

route_has_metricless_connected() {
  prefix="$1"
  dev="$2"
  src="$3"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" '{
      has_src=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "src" && $(i + 1) == src) has_src=1
        if ($i == "metric") has_metric=1
      }
      if (has_src && !has_metric) found=1
    } END { exit found ? 0 : 1 }'
}

metricless_connected_line() {
  prefix="$1"
  dev="$2"
  src="$3"
  ip route show "$prefix" dev "$dev" 2>/dev/null |
    awk -v src="$src" '{
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

route_line_has_kernel_proto() {
  line="$1"
  printf '%s\n' "$line" |
    awk '{
      has_proto=0; has_scope=0
      for (i = 1; i <= NF; i++) {
        if ($i == "proto" && $(i + 1) == "kernel") has_proto=1
        if ($i == "scope" && $(i + 1) == "link") has_scope=1
      }
      exit (has_proto && has_scope) ? 0 : 1
    }'
}

metricless_default_exists() {
  gw="$1"
  dev="$2"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v gw="$gw" '{
      has_gw=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "via" && $(i + 1) == gw) has_gw=1
        if ($i == "metric") has_metric=1
      }
      if (has_gw && !has_metric) found=1
    } END { exit found ? 0 : 1 }'
}

route_one_line() {
  ip route show "$1" dev "$2" 2>/dev/null | sed -n '1p'
}

route_one_stale_default_line() {
  dev="$1"
  gw="$2"
  metric="$3"
  ip route show default dev "$dev" 2>/dev/null |
    awk -v desired_gw="$gw" -v desired_metric="$metric" '
      {
        has_gw=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "via" && $(i + 1) == desired_gw) has_gw=1
          if ($i == "metric" && $(i + 1) == desired_metric) has_metric=1
        }
        if (!has_gw || !has_metric) {
          print
          exit
        }
      }'
}

route_one_deletable_line() {
  prefix="$1"
  dev="$2"
  category="$3"
  if [ "$category" = "connected" ]; then
    ip route show "$prefix" dev "$dev" 2>/dev/null |
      awk -v dev="$dev" '
        {
          has_dev=0; has_proto=0; has_scope=0; has_src=0
          for (i = 1; i <= NF; i++) {
            if ($i == "dev" && $(i + 1) == dev) has_dev=1
            if ($i == "proto" && $(i + 1) == "kernel") has_proto=1
            if ($i == "scope" && $(i + 1) == "link") has_scope=1
            if ($i == "src" && $(i + 1) != "") has_src=1
          }
          if (!(has_dev && has_proto && has_scope && has_src)) {
            print
            exit
          }
        }'
  else
    route_one_line "$prefix" "$dev"
  fi
}

route_stderr_text() {
  file="$1"
  tr '\n' ' ' < "$file" 2>/dev/null | sed 's/[	 ][	 ]*/ /g; s/^ //; s/ $//'
}

is_kernel_connected_route_line() {
  line="$1"
  supplied_dev="$2"
  printf '%s\n' "$line" | awk -v dev="$supplied_dev" '
    {
      has_dev=0; has_proto=0; has_scope=0; has_src=0
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == dev) has_dev=1
        if ($i == "proto" && $(i + 1) == "kernel") has_proto=1
        if ($i == "scope" && $(i + 1) == "link") has_scope=1
        if ($i == "src" && $(i + 1) != "") has_src=1
      }
      exit (has_dev && has_proto && has_scope && has_src) ? 0 : 1
    }'
}

delete_one_route_line() {
  line="$1"
  supplied_dev="$2"
  label="$3"
  category="$4"
  set -- $line
  prefix="$1"
  dev=""
  via=""
  metric=""
  proto=""
  scope=""
  src=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      via) via="$2"; shift 2 ;;
      dev) dev="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      proto) proto="$2"; shift 2 ;;
      scope) scope="$2"; shift 2 ;;
      src) src="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$dev" ] || dev="$supplied_dev"
  [ -n "$prefix" ] || return 1
  [ -n "$dev" ] || return 1
  set -- "$prefix"
  [ -n "$via" ] && set -- "$@" via "$via"
  set -- "$@" dev "$dev"
  [ -n "$proto" ] && set -- "$@" proto "$proto"
  [ -n "$scope" ] && set -- "$@" scope "$scope"
  [ -n "$src" ] && set -- "$@" src "$src"
  [ -n "$metric" ] && set -- "$@" metric "$metric"
  err="$STATE_DIR/ip-route-del.$$"
  ip route del "$@" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_delete ok category=$category label=$label prefix=$prefix supplied_dev=$supplied_dev original=[$line]"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_delete failed category=$category label=$label prefix=$prefix supplied_dev=$supplied_dev original=[$line] rc=$rc error=${err_text:-none}"
  return "$rc"
}

add_connected_route() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  label="$5"
  err="$STATE_DIR/ip-route-add.$$"
  ip route add "$prefix" dev "$dev" src "$src" metric "$metric" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_add ok category=explicit-connected label=$label prefix=$prefix supplied_dev=$dev src=$src metric=$metric"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_add failed category=explicit-connected label=$label prefix=$prefix supplied_dev=$dev src=$src metric=$metric rc=$rc error=${err_text:-none}"
  return "$rc"
}

delete_kernel_connected_route() {
  prefix="$1"
  dev="$2"
  src="$3"
  label="$4"
  err="$STATE_DIR/ip-route-del-kernel.$$"
  ip route del "$prefix" dev "$dev" proto kernel scope link src "$src" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_delete ok category=kernel-connected-exact label=$label prefix=$prefix supplied_dev=$dev src=$src"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_delete failed category=kernel-connected-exact label=$label prefix=$prefix supplied_dev=$dev src=$src rc=$rc error=${err_text:-none}"
  return "$rc"
}

delete_connected_route_form() {
  prefix="$1"
  dev="$2"
  src="$3"
  label="$4"
  form="$5"
  err="$STATE_DIR/ip-route-del-connected.$$"
  case "$form" in
    exact)
      ip route del "$prefix" dev "$dev" proto kernel scope link src "$src" 2>"$err"
      ;;
    proto_scope)
      ip route del "$prefix" dev "$dev" proto kernel scope link 2>"$err"
      ;;
    proto)
      ip route del "$prefix" dev "$dev" proto kernel 2>"$err"
      ;;
    *)
      ip route del "$prefix" dev "$dev" 2>"$err"
      ;;
  esac
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_delete ok category=metricless-connected label=$label prefix=$prefix supplied_dev=$dev src=$src form=$form"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_delete failed category=metricless-connected label=$label prefix=$prefix supplied_dev=$dev src=$src form=$form rc=$rc error=${err_text:-none}"
  return "$rc"
}

replace_connected_route() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  label="$5"
  err="$STATE_DIR/ip-route-replace.$$"
  ip route replace "$prefix" dev "$dev" src "$src" metric "$metric" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_replace ok category=package-connected label=$label prefix=$prefix supplied_dev=$dev src=$src metric=$metric"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_replace failed category=package-connected label=$label prefix=$prefix supplied_dev=$dev src=$src metric=$metric rc=$rc error=${err_text:-none}"
  return "$rc"
}

replace_default_route() {
  dev="$1"
  gw="$2"
  metric="$3"
  label="$4"
  err="$STATE_DIR/ip-route-default.$$"
  ip route replace default via "$gw" dev "$dev" metric "$metric" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_replace ok category=default label=$label prefix=default supplied_dev=$dev gw=$gw metric=$metric"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_replace failed category=default label=$label prefix=default supplied_dev=$dev gw=$gw metric=$metric rc=$rc error=${err_text:-none}"
  return "$rc"
}

replace_metricless_default_route() {
  dev="$1"
  gw="$2"
  label="$3"
  err="$STATE_DIR/ip-route-default-metricless.$$"
  ip route replace default via "$gw" dev "$dev" 2>"$err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_replace ok category=metricless-default label=$label prefix=default supplied_dev=$dev gw=$gw"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_replace failed category=metricless-default label=$label prefix=default supplied_dev=$dev gw=$gw rc=$rc error=${err_text:-none}"
  return "$rc"
}

replace_metricless_connected_route() {
  prefix="$1"
  dev="$2"
  src="$3"
  label="$4"
  form="$5"
  err="$STATE_DIR/ip-route-connected-metricless.$$"
  case "$form" in
    proto_kernel)
      ip route replace "$prefix" dev "$dev" proto kernel scope link src "$src" 2>"$err"
      ;;
    scope_link)
      ip route replace "$prefix" dev "$dev" scope link src "$src" 2>"$err"
      ;;
    *)
      ip route replace "$prefix" dev "$dev" src "$src" 2>"$err"
      ;;
  esac
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -f "$err"
    route_log "route_replace ok category=metricless-connected label=$label prefix=$prefix supplied_dev=$dev src=$src form=$form"
    return 0
  fi
  err_text="$(route_stderr_text "$err")"
  rm -f "$err"
  route_log "route_replace failed category=metricless-connected label=$label prefix=$prefix supplied_dev=$dev src=$src form=$form rc=$rc error=${err_text:-none}"
  return "$rc"
}

connected_route_verified() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  [ "$(connected_matching_count "$prefix" "$dev" "$src" "$metric")" = "1" ] || return 1
  [ "$(connected_bad_count "$prefix" "$dev" "$metric")" = "0" ] || return 1
  return 0
}

explicit_connected_route_exists() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  [ "$(connected_matching_count "$prefix" "$dev" "$src" "$metric")" -ge 1 ] || return 1
  return 0
}

default_route_verified() {
  dev="$1"
  gw="$2"
  metric="$3"
  [ "$(matching_default_count "$dev" "$gw" "$metric")" = "1" ] || return 1
  [ "$(stale_default_count "$dev" "$gw" "$metric")" = "0" ] || return 1
  return 0
}

metricless_connected_verified() {
  prefix="$1"
  dev="$2"
  src="$3"
  route_has_metricless_connected "$prefix" "$dev" "$src"
}

metricless_default_verified() {
  dev="$1"
  gw="$2"
  metricless_default_exists "$gw" "$dev"
}

remove_routes_for_prefix_dev() {
  prefix="$1"
  dev="$2"
  label="$3"
  category="${4:-route}"
  i=0
  while [ "$i" -lt "$ROUTE_DELETE_MAX" ]; do
    line="$(route_one_deletable_line "$prefix" "$dev" "$category")"
    if [ -z "$line" ]; then
      kernel_line="$(route_one_line "$prefix" "$dev")"
      [ -n "$kernel_line" ] && [ "$category" = "connected" ] && route_log "route_delete skipped category=kernel-connected label=$label prefix=$prefix supplied_dev=$dev original=[$kernel_line] disposition=tolerated"
      return 0
    fi
    if ! delete_one_route_line "$line" "$dev" "$label" "$category"; then
      route_log "route_delete incomplete category=$category label=$label prefix=$prefix supplied_dev=$dev original=[$line] disposition=verify-final-state"
      return 1
    fi
    i=$((i + 1))
  done
  route_log "route delete limit reached label=$label prefix=$prefix dev=$dev remaining=$(ip route show "$prefix" dev "$dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

remove_metricless_connected_after_explicit() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  label="$5"
  explicit_connected_route_exists "$prefix" "$dev" "$src" "$metric" || return 1
  line="$(metricless_connected_line "$prefix" "$dev" "$src")"
  [ -n "$line" ] || return 0
  if route_line_has_kernel_proto "$line"; then
    forms="exact proto_scope proto dev_only"
  else
    forms="dev_only"
  fi
  for form in $forms; do
    delete_connected_route_form "$prefix" "$dev" "$src" "$label" "$form" || true
    explicit_connected_route_exists "$prefix" "$dev" "$src" "$metric" || {
      route_log "metricless connected delete removed explicit replacement label=$label prefix=$prefix dev=$dev src=$src metric=$metric form=$form"
      return 1
    }
    if ! route_has_metricless_connected "$prefix" "$dev" "$src"; then
      route_log "metricless connected delete verified label=$label prefix=$prefix dev=$dev src=$src form=$form"
      return 0
    fi
  done
  route_log "metricless connected delete failed label=$label prefix=$prefix dev=$dev src=$src initial=[$line] remaining=$(ip route show "$prefix" dev "$dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

remove_metric_connected_for_src() {
  prefix="$1"
  dev="$2"
  src="$3"
  label="$4"
  i=0
  while [ "$i" -lt "$ROUTE_DELETE_MAX" ]; do
    line="$(ip route show "$prefix" dev "$dev" 2>/dev/null |
      awk -v src="$src" '{
        has_src=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "src" && $(i + 1) == src) has_src=1
          if ($i == "metric") has_metric=1
        }
        if (has_src && has_metric) {
          print
          exit
        }
      }')"
    [ -n "$line" ] || return 0
    delete_one_route_line "$line" "$dev" "$label metric-connected" connected || return 1
    i=$((i + 1))
  done
  route_log "metric connected delete limit reached label=$label prefix=$prefix dev=$dev src=$src remaining=$(ip route show "$prefix" dev "$dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

reconcile_connected_routes_for_dev() {
  prefix="$1"
  dev="$2"
  src="$3"
  metric="$4"
  label="$5"
  tmp="$STATE_DIR/connected-routes.$$"
  ip route show "$prefix" dev "$dev" 2>/dev/null > "$tmp" || : > "$tmp"
  awk -v desired_src="$src" -v desired_metric="$metric" '
    {
      has_src=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "src" && $(i + 1) == desired_src) has_src=1
        if ($i == "metric" && $(i + 1) == desired_metric) has_metric=1
      }
      if (has_src && has_metric && !seen) {
        seen=1
        print "KEEP " $0
      } else {
        print "DEL " $0
      }
    }' "$tmp" > "$tmp.marked"
  while IFS= read -r marked; do
    [ -n "$marked" ] || continue
    action="${marked%% *}"
    line="${marked#* }"
    [ "$action" = "KEEP" ] && continue
    delete_one_route_line "$line" "$dev" "$label connected" connected || true
  done < "$tmp.marked"
  rm -f "$tmp" "$tmp.marked"
  return 0
}

remove_stale_defaults_for_dev() {
  dev="$1"
  gw="$2"
  metric="$3"
  label="$4"
  i=0
  while [ "$i" -lt "$ROUTE_DELETE_MAX" ]; do
    line="$(route_one_stale_default_line "$dev" "$gw" "$metric")"
    [ -n "$line" ] || return 0
    if ! delete_one_route_line "$line" "$dev" "$label default" default; then
      route_log "default delete incomplete label=$label dev=$dev desired_gw=$gw desired_metric=$metric original=[$line] disposition=verify-final-state"
      return 1
    fi
    i=$((i + 1))
  done
  route_log "default delete limit reached label=$label dev=$dev desired_gw=$gw desired_metric=$metric remaining=$(ip route show default dev "$dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

remove_metricless_default_for_dev() {
  dev="$1"
  gw="$2"
  label="$3"
  if metricless_default_exists "$gw" "$dev"; then
    delete_one_route_line "default via $gw dev $dev" "$dev" "$label metricless-default" default || true
  fi
  metricless_default_exists "$gw" "$dev" && {
    route_log "metricless default delete incomplete label=$label dev=$dev gw=$gw remaining=$(ip route show default dev "$dev" 2>/dev/null | tr '\n' ';')"
    return 1
  }
  return 0
}

reconcile_defaults_for_dev() {
  dev="$1"
  gw="$2"
  metric="$3"
  label="$4"
  tmp="$STATE_DIR/default-routes.$$"
  ip route show default dev "$dev" 2>/dev/null > "$tmp" || : > "$tmp"
  awk -v desired_gw="$gw" -v desired_metric="$metric" '
    {
      has_gw=0; has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "via" && $(i + 1) == desired_gw) has_gw=1
        if ($i == "metric" && $(i + 1) == desired_metric) has_metric=1
      }
      if (has_gw && has_metric && !seen) {
        seen=1
        print "KEEP " $0
      } else {
        print "DEL " $0
      }
    }' "$tmp" > "$tmp.marked"
  while IFS= read -r marked; do
    [ -n "$marked" ] || continue
    action="${marked%% *}"
    line="${marked#* }"
    [ "$action" = "KEEP" ] && continue
    delete_one_route_line "$line" "$dev" "$label default" default || true
  done < "$tmp.marked"
  rm -f "$tmp" "$tmp.marked"
  return 0
}

remove_metric_defaults_for_dev() {
  dev="$1"
  label="$2"
  i=0
  while [ "$i" -lt "$ROUTE_DELETE_MAX" ]; do
    line="$(ip route show default dev "$dev" 2>/dev/null | awk '{
      for (i = 1; i <= NF; i++) {
        if ($i == "metric") {
          print
          exit
        }
      }
    }')"
    [ -n "$line" ] || return 0
    if ! delete_one_route_line "$line" "$dev" "$label metric-default" default; then
      route_log "metric default delete incomplete label=$label dev=$dev original=[$line] disposition=verify-final-state"
      return 1
    fi
    i=$((i + 1))
  done
  route_log "metric default delete limit reached label=$label dev=$dev remaining=$(ip route show default dev "$dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

install_default_once() {
  id_dev="$1"
  id_gw="$2"
  id_metric="$3"
  id_label="$4"
  replace_default_route "$id_dev" "$id_gw" "$id_metric" "$id_label" || true
  reconcile_defaults_for_dev "$id_dev" "$id_gw" "$id_metric" "$id_label" || true
  if default_route_verified "$id_dev" "$id_gw" "$id_metric"; then
    route_log "installed $id_label default gw=$id_gw dev=$id_dev metric=$id_metric"
    return 0
  fi
  route_log "default verification failed label=$id_label gw=$id_gw dev=$id_dev metric=$id_metric remaining=$(ip route show default dev "$id_dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

install_connected_once() {
  ic_prefix="$1"
  ic_dev="$2"
  ic_src="$3"
  ic_metric="$4"
  ic_label="$5"
  if ! explicit_connected_route_exists "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric"; then
    add_connected_route "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric" "$ic_label" || true
  fi
  explicit_connected_route_exists "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric" || {
    route_log "explicit connected verification failed label=$ic_label prefix=$ic_prefix dev=$ic_dev src=$ic_src metric=$ic_metric remaining=$(ip route show "$ic_prefix" dev "$ic_dev" 2>/dev/null | tr '\n' ';')"
    return 1
  }
  if route_has_metricless_connected "$ic_prefix" "$ic_dev" "$ic_src"; then
    remove_metricless_connected_after_explicit "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric" "$ic_label" || true
  fi
  reconcile_connected_routes_for_dev "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric" "$ic_label" || true
  if connected_route_verified "$ic_prefix" "$ic_dev" "$ic_src" "$ic_metric"; then
    route_log "installed $ic_label connected prefix=$ic_prefix src=$ic_src metric=$ic_metric"
    return 0
  fi
  route_log "unsupported-target-routing label=$ic_label connected prefix=$ic_prefix dev=$ic_dev src=$ic_src metric=$ic_metric remaining=$(ip route show "$ic_prefix" dev "$ic_dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

restore_connected_metricless_once() {
  rc_prefix="$1"
  rc_dev="$2"
  rc_src="$3"
  rc_label="$4"
  rc_gw="${5:-}"
  remove_metric_connected_for_src "$rc_prefix" "$rc_dev" "$rc_src" "$rc_label" || true
  if metricless_connected_verified "$rc_prefix" "$rc_dev" "$rc_src"; then
    if [ -z "$rc_gw" ] || { [ "$(route_lookup_dev "$rc_gw")" = "$rc_dev" ] && ! route_lookup_has_via "$rc_gw"; }; then
      return 0
    fi
  fi
  for form in scope_link proto_kernel plain; do
    replace_metricless_connected_route "$rc_prefix" "$rc_dev" "$rc_src" "$rc_label" "$form" || true
    if metricless_connected_verified "$rc_prefix" "$rc_dev" "$rc_src" &&
       { [ -z "$rc_gw" ] || { [ "$(route_lookup_dev "$rc_gw")" = "$rc_dev" ] && ! route_lookup_has_via "$rc_gw"; }; }; then
      route_log "restored $rc_label connected prefix=$rc_prefix dev=$rc_dev src=$rc_src form=$form"
      return 0
    fi
    if metricless_connected_verified "$rc_prefix" "$rc_dev" "$rc_src" &&
       [ -n "$rc_gw" ] &&
       ! route_lookup_has_via "$rc_gw"; then
      route_log "restored $rc_label connected pending usb cleanup prefix=$rc_prefix dev=$rc_dev src=$rc_src form=$form route_get_dev=$(route_lookup_dev "$rc_gw")"
      return 0
    fi
    if [ -n "$rc_gw" ]; then
      if route_lookup_has_via "$rc_gw"; then
        via_status=yes
      else
        via_status=no
      fi
      route_log "restore connected verification failed label=$rc_label prefix=$rc_prefix dev=$rc_dev src=$rc_src form=$form route_get_dev=$(route_lookup_dev "$rc_gw") via=$via_status"
    fi
  done
  route_log "wifi restore connected verification failed label=$rc_label prefix=$rc_prefix dev=$rc_dev src=$rc_src remaining=$(ip route show "$rc_prefix" dev "$rc_dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

restore_metricless_default_once() {
  rd_dev="$1"
  rd_gw="$2"
  rd_label="$3"
  replace_metricless_default_route "$rd_dev" "$rd_gw" "$rd_label" || true
  remove_metric_defaults_for_dev "$rd_dev" "$rd_label" || true
  if metricless_default_verified "$rd_dev" "$rd_gw"; then
    route_log "restored $rd_label default gw=$rd_gw dev=$rd_dev"
    return 0
  fi
  route_log "wifi restore default verification failed label=$rd_label gw=$rd_gw dev=$rd_dev remaining=$(ip route show default dev "$rd_dev" 2>/dev/null | tr '\n' ';')"
  return 1
}

flush_route_cache_if_changed() {
  [ "${ROUTES_CHANGED:-0}" = "1" ] || return 0
  if ip route flush cache >/dev/null 2>&1; then
    route_log "route cache flush ok"
  else
    route_log "route cache flush unsupported_or_failed"
  fi
}

route_lookup_dev() {
  dst="$1"
  src="${2:-}"
  if [ -n "$src" ]; then
    ip route get "$dst" from "$src" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
  else
    ip route get "$dst" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
  fi
}

route_lookup_has_via() {
  dst="$1"
  src="${2:-}"
  if [ -n "$src" ]; then
    ip route get "$dst" from "$src" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") found=1 } END { exit found ? 0 : 1 }'
  else
    ip route get "$dst" 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") found=1 } END { exit found ? 0 : 1 }'
  fi
}

usb_primary_needs_reconcile() {
  usb_ip="$(file_value "$STATE_DIR/usb0.ip" 2>/dev/null || true)"
  usb_gw="$(file_value "$STATE_DIR/usb0.router" 2>/dev/null || true)"
  usb_prefix="$(file_value "$STATE_DIR/usb0.prefix" 2>/dev/null || true)"
  wifi_gw="$(file_value "$STATE_DIR/wifi.gateway" 2>/dev/null || first_default_gw "$WIFI_IF")"
  wifi_ip="$(file_value "$STATE_DIR/wifi.ip" 2>/dev/null || iface_ipv4 "$WIFI_IF")"
  wifi_prefix="$(file_value "$STATE_DIR/wifi.prefix" 2>/dev/null || iface_prefix "$WIFI_IF")"
  [ -n "$usb_ip" ] || return 0
  [ -n "$usb_gw" ] || return 0
  [ -n "$usb_prefix" ] || usb_prefix="$(iface_prefix "$USB_IF")"
  [ -n "$usb_prefix" ] || return 0
  usb_route="$(route_for_prefix "$usb_ip" "$usb_prefix")"
  [ "$(matching_default_count "$USB_IF" "$usb_gw" "$USB_METRIC")" = "1" ] || return 0
  [ "$(stale_default_count "$USB_IF" "$usb_gw" "$USB_METRIC")" = "0" ] || return 0
  [ "$(connected_matching_count "$usb_route" "$USB_IF" "$usb_ip" "$USB_METRIC")" = "1" ] || return 0
  [ "$(connected_bad_count "$usb_route" "$USB_IF" "$USB_METRIC")" = "0" ] || return 0
  if [ -n "$wifi_gw" ] && wifi_usable; then
    [ "$(matching_default_count "$WIFI_IF" "$wifi_gw" "$WIFI_METRIC")" = "1" ] || return 0
    [ "$(stale_default_count "$WIFI_IF" "$wifi_gw" "$WIFI_METRIC")" = "0" ] || return 0
  else
    [ "$(ip route show default dev "$WIFI_IF" 2>/dev/null | count_lines)" = "0" ] || return 0
  fi
  if [ -n "$wifi_ip" ] && [ -n "$wifi_prefix" ]; then
    wifi_route="$(route_for_prefix "$wifi_ip" "$wifi_prefix")"
    if [ "$wifi_route" = "$usb_route" ]; then
      if wifi_usable; then
        [ "$(connected_matching_count "$wifi_route" "$WIFI_IF" "$wifi_ip" "$WIFI_METRIC")" = "1" ] || return 0
        [ "$(connected_bad_count "$wifi_route" "$WIFI_IF" "$WIFI_METRIC")" = "0" ] || return 0
      else
        [ "$(connected_any_count "$wifi_route" "$WIFI_IF")" = "0" ] || return 0
      fi
    fi
  fi
  [ "$(route_lookup_dev "$usb_gw" "$usb_ip")" = "$USB_IF" ] || return 0
  return 1
}

wifi_usable() {
  iface_exists "$WIFI_IF" || return 1
  [ "$(operstate_value "$WIFI_IF")" != "down" ] || return 1
  link_has_no_carrier "$WIFI_IF" && return 1
  [ -n "$(iface_ipv4 "$WIFI_IF")" ] || [ -n "$(file_value "$STATE_DIR/wifi.ip" 2>/dev/null || true)" ] || return 1
  return 0
}

save_fallback_state() {
  [ -s "$STATE_DIR/wifi.gateway" ] || first_default_gw "$WIFI_IF" > "$STATE_DIR/wifi.gateway"
  [ -s "$STATE_DIR/wifi.ip" ] || iface_ipv4 "$WIFI_IF" > "$STATE_DIR/wifi.ip"
  [ -s "$STATE_DIR/wifi.prefix" ] || iface_prefix "$WIFI_IF" > "$STATE_DIR/wifi.prefix"
  [ -f "$STATE_DIR/resolv.conf.wifi" ] || save_wifi_resolv_snapshot
}

save_wifi_resolv_snapshot() {
  tmp="$STATE_DIR/resolv.conf.wifi.$$"
  awk -v dev="$WIFI_IF" '
    $1 == "nameserver" && $2 != "" {
      if (!seen[$2]++) print "nameserver " $2 " # " dev
      next
    }
    { print }
  ' "$RESOLV_CONF" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_DIR/resolv.conf.wifi" || rm -f "$tmp"
}

write_usb_dns() {
  tmp="$STATE_DIR/resolv.conf.usb.$$"
  : > "$tmp"
  for ns in ${dns:-}; do
    printf 'nameserver %s # %s\n' "$ns" "$USB_IF" >> "$tmp"
  done
  cp "$tmp" "$RESOLV_CONF" 2>/dev/null || true
  rm -f "$tmp"
}

write_usb_env_state() {
  {
    printf 'interface=%s\n' "${interface:-}"
    printf 'ip=%s\n' "${ip:-}"
    printf 'router=%s\n' "${router:-}"
    printf 'mask=%s\n' "${mask:-}"
    printf 'dns=%s\n' "${dns:-}"
    printf 'lease=%s\n' "${lease:-}"
  } > "$STATE_DIR/usb0.env"
}

usb_primary_fail() {
  reason="$1"
  route_log "usb-primary transaction failed reason=$reason; restoring wifi fallback"
  restore_wifi_fallback_routes
  return 1
}

apply_usb_primary_routes() {
  save_fallback_state
  wifi_gw="$(file_value "$STATE_DIR/wifi.gateway" 2>/dev/null || true)"
  wifi_ip="$(file_value "$STATE_DIR/wifi.ip" 2>/dev/null || true)"
  wifi_prefix="$(file_value "$STATE_DIR/wifi.prefix" 2>/dev/null || true)"
  usb_prefix_value="$(normalize_prefix "${mask:-24}")"
  gw="${router:-}"
  [ -n "${ip:-}" ] || { route_log "bound without ip"; return 1; }
  [ -n "$gw" ] || { route_log "bound without router"; return 1; }
  usb_route="$(route_for_prefix "$ip" "$usb_prefix_value")"

  ip addr flush dev "$USB_IF" 2>/dev/null || true
  ip addr add "$ip/$usb_prefix_value" brd "${broadcast:-+}" dev "$USB_IF" || {
    route_log "failed configuring $USB_IF address $ip/$usb_prefix_value"
    usb_primary_fail configure-address
    return 1
  }
  ip link set dev "$USB_IF" up || {
    route_log "failed setting $USB_IF up"
    usb_primary_fail link-up
    return 1
  }

  ROUTES_CHANGED=0
  install_connected_once "$usb_route" "$USB_IF" "$ip" "$USB_METRIC" usb && ROUTES_CHANGED=1 || {
    usb_primary_fail usb-connected-route
    return 1
  }
  install_default_once "$USB_IF" "$gw" "$USB_METRIC" usb && ROUTES_CHANGED=1 || {
    usb_primary_fail usb-default-route
    return 1
  }

  if [ -n "$wifi_ip" ] && [ -n "$wifi_prefix" ]; then
    wifi_route="$(route_for_prefix "$wifi_ip" "$wifi_prefix")"
    if [ "$wifi_route" = "$usb_route" ]; then
      if wifi_usable; then
        install_connected_once "$wifi_route" "$WIFI_IF" "$wifi_ip" "$WIFI_METRIC" wifi && ROUTES_CHANGED=1 || true
      else
        remove_routes_for_prefix_dev "$wifi_route" "$WIFI_IF" "wifi unusable connected" && ROUTES_CHANGED=1 || true
      fi
    fi
  fi
  if [ -n "$wifi_gw" ]; then
    if wifi_usable; then
      install_default_once "$WIFI_IF" "$wifi_gw" "$WIFI_METRIC" wifi && ROUTES_CHANGED=1 || true
    else
      remove_routes_for_prefix_dev default "$WIFI_IF" "wifi unusable default" && ROUTES_CHANGED=1 || true
    fi
  fi

  flush_route_cache_if_changed
  if [ "$(route_lookup_dev "$gw" "$ip")" != "$USB_IF" ]; then
    route_log "verification failed route_get gw=$gw from=$ip dev=$(route_lookup_dev "$gw" "$ip")"
    usb_primary_fail route-lookup
    return 1
  fi
  [ -n "${dns:-}" ] && write_usb_dns

  write_usb_env_state
  printf '%s\n' "$ip" > "$STATE_DIR/usb0.ip"
  printf '%s\n' "$usb_prefix_value" > "$STATE_DIR/usb0.prefix"
  printf '%s\n' "$gw" > "$STATE_DIR/usb0.router"
  printf '%s\n' "$USB_METRIC" > "$STATE_DIR/usb0.metric"
  printf '%s\n' "$WIFI_METRIC" > "$STATE_DIR/wifi.metric"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$STATE_DIR/ethernet.active"
  route_log "usb primary active ip=$ip/$usb_prefix_value router=$gw dns=${dns:-none} usb_metric=$USB_METRIC wifi_metric=$WIFI_METRIC"
  return 0
}

reconcile_usb_primary_routes() {
  ip="$(file_value "$STATE_DIR/usb0.ip" 2>/dev/null || true)"
  router="$(file_value "$STATE_DIR/usb0.router" 2>/dev/null || true)"
  mask="$(file_value "$STATE_DIR/usb0.prefix" 2>/dev/null || iface_prefix "$USB_IF")"
  [ -n "$ip" ] || { route_log "reconcile skipped: missing usb ip"; return 1; }
  [ -n "$router" ] || { route_log "reconcile skipped: missing usb router"; return 1; }
  if usb_primary_needs_reconcile; then
    route_log "route drift detected; reconciling usb-primary policy"
    apply_usb_primary_routes
  else
    return 0
  fi
}

restore_wifi_fallback_routes() {
  wifi_gw="$(file_value "$STATE_DIR/wifi.gateway" 2>/dev/null || first_default_gw "$WIFI_IF")"
  wifi_ip="$(file_value "$STATE_DIR/wifi.ip" 2>/dev/null || iface_ipv4 "$WIFI_IF")"
  wifi_prefix="$(file_value "$STATE_DIR/wifi.prefix" 2>/dev/null || iface_prefix "$WIFI_IF")"
  usb_ip="$(file_value "$STATE_DIR/usb0.ip" 2>/dev/null || iface_ipv4 "$USB_IF")"
  usb_prefix="$(file_value "$STATE_DIR/usb0.prefix" 2>/dev/null || iface_prefix "$USB_IF")"
  wifi_route=""
  ROUTES_CHANGED=0
  if [ -n "$wifi_ip" ] && [ -n "$wifi_prefix" ]; then
    wifi_route="$(route_for_prefix "$wifi_ip" "$wifi_prefix")"
    restore_connected_metricless_once "$wifi_route" "$WIFI_IF" "$wifi_ip" wifi-restore "$wifi_gw" && ROUTES_CHANGED=1 || true
  fi
  if [ -n "$wifi_gw" ]; then
    restore_metricless_default_once "$WIFI_IF" "$wifi_gw" wifi-restore && ROUTES_CHANGED=1 || true
  fi
  if [ -n "$wifi_route" ] && [ -n "$wifi_gw" ]; then
    if route_lookup_has_via "$wifi_gw"; then
      via_status=yes
    else
      via_status=no
    fi
    if ! metricless_connected_verified "$wifi_route" "$WIFI_IF" "$wifi_ip" ||
       [ "$(route_lookup_dev "$wifi_gw")" != "$WIFI_IF" ] ||
       [ "$via_status" = yes ]; then
      route_log "fallback verification failed stage=pre-usb-cleanup gw=$wifi_gw dev=$(route_lookup_dev "$wifi_gw") via=$via_status expected=$WIFI_IF"
    fi
  fi
  remove_routes_for_prefix_dev default "$USB_IF" "usb fallback default" && ROUTES_CHANGED=1 || true
  if [ -n "$usb_ip" ] && [ -n "$usb_prefix" ]; then
    usb_route="$(route_for_prefix "$usb_ip" "$usb_prefix")"
    remove_routes_for_prefix_dev "$usb_route" "$USB_IF" "usb fallback connected" && ROUTES_CHANGED=1 || true
  fi
  ip addr flush dev "$USB_IF" 2>/dev/null || true
  [ -f "$STATE_DIR/resolv.conf.wifi" ] && cp "$STATE_DIR/resolv.conf.wifi" "$RESOLV_CONF" 2>/dev/null || true
  flush_route_cache_if_changed
  if [ -n "$wifi_route" ] && [ -n "$wifi_gw" ]; then
    if route_lookup_has_via "$wifi_gw"; then
      via_status=yes
    else
      via_status=no
    fi
    if ! metricless_connected_verified "$wifi_route" "$WIFI_IF" "$wifi_ip" ||
       [ "$(route_lookup_dev "$wifi_gw")" != "$WIFI_IF" ] ||
       [ "$via_status" = yes ]; then
      route_log "fallback verification failed stage=post-usb-cleanup gw=$wifi_gw dev=$(route_lookup_dev "$wifi_gw") via=$via_status expected=$WIFI_IF; retrying connected restore"
      restore_connected_metricless_once "$wifi_route" "$WIFI_IF" "$wifi_ip" wifi-restore-post-usb "$wifi_gw" && ROUTES_CHANGED=1 || true
      ip route flush cache >/dev/null 2>&1 || true
      if route_lookup_has_via "$wifi_gw"; then
        via_status=yes
      else
        via_status=no
      fi
      if ! metricless_connected_verified "$wifi_route" "$WIFI_IF" "$wifi_ip" ||
         [ "$(route_lookup_dev "$wifi_gw")" != "$WIFI_IF" ] ||
         [ "$via_status" = yes ]; then
        route_log "fallback verification failed stage=final gw=$wifi_gw dev=$(route_lookup_dev "$wifi_gw") via=$via_status expected=$WIFI_IF"
      else
        route_log "fallback verification ok stage=final gw=$wifi_gw dev=$WIFI_IF via=no"
      fi
    else
      route_log "fallback verification ok stage=post-usb-cleanup gw=$wifi_gw dev=$WIFI_IF via=no"
    fi
  fi
  rm -f "$STATE_DIR/usb0.env" "$STATE_DIR/usb0.ip" "$STATE_DIR/usb0.prefix" "$STATE_DIR/usb0.router" "$STATE_DIR/usb0.metric" "$STATE_DIR/ethernet.active"
  route_log "fallback restored wifi_gw=$wifi_gw wifi_ip=$wifi_ip"
}
