#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-route-capability-probe-test-$$"
SH="${SH:-/usr/bin/sh}"

cleanup() {
  [ "${KEEP_TMP:-0}" = "1" ] && {
    echo "keeping $TMP" >&2
    return
  }
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/package"

cat > "$TMP/package/start-usb-ethernet.sh" <<'EOS'
#!/bin/sh
exit 0
EOS
cat > "$TMP/package/stop-usb-ethernet.sh" <<'EOS'
#!/bin/sh
echo stop-usb >> "$MOCK_ROOT/mutations"
exit 0
EOS
chmod 755 "$TMP/package/start-usb-ethernet.sh" "$TMP/package/stop-usb-ethernet.sh"

cat > "$TMP/bin/busybox" <<'EOS'
#!/bin/sh
echo "BusyBox v1.31.1"
EOS
chmod 755 "$TMP/bin/busybox"

cat > "$TMP/bin/ip" <<'EOS'
#!/bin/sh
set -eu

R="$MOCK_ROOT"
ROUTES="$R/routes"
ADDRS="$R/addrs"
MUT="$R/mutations"

touch "$ROUTES" "$ADDRS" "$MUT"

metric_of_line() {
  awk '{
    m=0
    for (i = 1; i <= NF; i++) if ($i == "metric") m=$(i + 1)
    print m
    exit
  }'
}

line_dev() {
  awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

line_src() {
  awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

show_route() {
  if [ "$#" -eq 0 ]; then
    cat "$ROUTES"
    return 0
  fi
  prefix="$1"
  dev=""
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  awk -v p="$prefix" -v d="$dev" -v omit="${MOCK_OMIT_FILTERED_DEV:-0}" '{
    has_dev=0
    for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) has_dev=1
    if ($1 == p && (d == "" || has_dev)) {
      if (d != "" && omit == "1") {
        out=""
        for (i = 1; i <= NF; i++) {
          if ($i == "dev" && $(i + 1) == d) { i++; continue }
          out = out (out == "" ? "" : " ") $i
        }
        print out
      } else {
        print
      }
    }
  }' "$ROUTES"
}

addr_show() {
  dev="$1"
  awk -v d="$dev" '$1 == d { print "    inet " $2 "/" $3 " brd + scope global " d }' "$ADDRS"
}

replace_line() {
  new_line="$1"
  prefix="$2"
  dev="$3"
  metric="$4"
  tmp="$R/routes.$$"
  awk -v p="$prefix" -v d="$dev" -v m="$metric" '
    {
      has_dev=0; has_metric=(m == "")
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == d) has_dev=1
        if ($i == "metric" && $(i + 1) == m) has_metric=1
      }
      if ($1 == p && has_dev && has_metric) next
      print
    }' "$ROUTES" > "$tmp"
  printf '%s\n' "$new_line" >> "$tmp"
  mv "$tmp" "$ROUTES"
}

route_add() {
  prefix="$1"
  shift
  dev=""
  src=""
  metric=""
  via=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      src) src="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      via) via="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ "$prefix" = "default" ]; then
    line="default via $via dev $dev"
    [ -n "$metric" ] && line="$line metric $metric"
  else
    line="$prefix dev $dev"
    [ -n "$src" ] && line="$line src $src"
    [ -n "$metric" ] && line="$line metric $metric"
  fi
  printf '%s\n' "$line" >> "$ROUTES"
  echo "route add $line" >> "$MUT"
}

route_replace() {
  prefix="$1"
  shift
  dev=""
  src=""
  metric=""
  via=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      src) src="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      via) via="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ "$prefix" = "default" ]; then
    line="default via $via dev $dev"
    [ -n "$metric" ] && line="$line metric $metric"
  else
    line="$prefix dev $dev"
    [ -n "$src" ] && line="$line src $src"
    [ -n "$metric" ] && line="$line metric $metric"
  fi
  replace_line "$line" "$prefix" "$dev" "$metric"
  echo "route replace $line" >> "$MUT"
}

route_del() {
  prefix="$1"
  shift
  dev=""
  via=""
  metric=""
  proto=0
  scope=0
  src=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      via) via="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      proto) proto=1; shift 2 ;;
      scope) scope=1; shift 2 ;;
      src) src="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  tmp="$R/routes.$$"
  if [ "$prefix" = "default" ]; then
    mode="${MOCK_DEFAULT_DELETE:-only_metricless}"
    awk -v d="$dev" -v v="$via" -v m="$metric" -v mode="$mode" '
      BEGIN { removed=0 }
      {
        has_dev=0; has_via=0; has_metric=0; metric_val=""
        for (i = 1; i <= NF; i++) {
          if ($i == "dev" && $(i + 1) == d) has_dev=1
          if ($i == "via" && $(i + 1) == v) has_via=1
          if ($i == "metric") { has_metric=1; metric_val=$(i + 1) }
        }
        match_metric=(m == "" ? !has_metric : metric_val == m)
        if ($1 == "default" && has_dev && has_via) {
          if (mode == "fail") { print; next }
          if (mode == "both" && m == "") { removed=1; next }
          if (match_metric) { removed=1; next }
        }
        print
      }
      END { if (!removed) exit 7 }
    ' "$ROUTES" > "$tmp" || { rm -f "$tmp"; echo "RTNETLINK answers: No such process" >&2; exit 2; }
    mv "$tmp" "$ROUTES"
    echo "route del default dev=$dev via=$via metric=$metric" >> "$MUT"
    return 0
  fi

  case "$prefix" in
    */32)
      awk -v p="$prefix" -v d="$dev" '
        BEGIN { removed=0 }
        {
          has_dev=0
          for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) has_dev=1
          if ($1 == p && has_dev) { removed=1; next }
          print
        }
        END { if (!removed) exit 7 }
      ' "$ROUTES" > "$tmp" || { rm -f "$tmp"; echo "RTNETLINK answers: No such process" >&2; exit 2; }
      mv "$tmp" "$ROUTES"
      echo "route del $prefix dev=$dev" >> "$MUT"
      return 0
      ;;
  esac

  mode="${MOCK_CONNECTED_DELETE:-exact}"
  form="dev_only"
  [ "$proto" = "1" ] && form="proto"
  [ "$proto" = "1" ] && [ "$scope" = "1" ] && form="proto_scope"
  [ "$proto" = "1" ] && [ "$scope" = "1" ] && [ -n "$src" ] && form="exact"
  awk -v p="$prefix" -v d="$dev" -v s="$src" -v form="$form" -v mode="$mode" '
    BEGIN { removed=0 }
    {
      has_dev=0; has_src=(s == ""); has_metric=0
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == d) has_dev=1
        if ($i == "src" && $(i + 1) == s) has_src=1
        if ($i == "metric") has_metric=1
      }
      if ($1 == p && has_dev) {
        if (mode == "wrong_explicit" && has_metric) { removed=1; next }
        if (!has_metric && (mode == form || (mode == "exact" && form == "exact"))) { removed=1; next }
      }
      print
    }
    END { if (!removed) exit 7 }
  ' "$ROUTES" > "$tmp" || { rm -f "$tmp"; echo "RTNETLINK answers: No such file or directory" >&2; exit 2; }
  mv "$tmp" "$ROUTES"
  echo "route del $prefix dev=$dev src=$src form=$form" >> "$MUT"
}

prefix_match() {
  dst="$1"
  prefix="$2"
  case "$prefix" in
    default) return 0 ;;
    */24)
      net="${prefix%.*}.0/24"
      dnet="$(printf '%s\n' "$dst" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }')"
      [ "$net" = "$dnet" ]
      ;;
    */32) [ "${prefix%/32}" = "$dst" ] ;;
    *) return 1 ;;
  esac
}

route_get() {
  dst="$1"
  src=""
  if [ "${2:-}" = "from" ]; then
    src="$3"
  fi
  best=""
  best_metric=999999
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    set -- $line
    prefix="$1"
    if prefix_match "$dst" "$prefix"; then
      metric="$(printf '%s\n' "$line" | metric_of_line)"
      if [ "$metric" -lt "$best_metric" ]; then
        best="$line"
        best_metric="$metric"
      fi
    fi
  done < "$ROUTES"
  [ -n "$best" ] || exit 1
  dev="$(printf '%s\n' "$best" | line_dev)"
  route_src="$(printf '%s\n' "$best" | line_src)"
  [ -n "$route_src" ] || route_src="$src"
  [ -n "$route_src" ] || route_src="0.0.0.0"
  echo "$dst from $src dev $dev src $route_src"
}

case "${1:-}" in
  -V) echo "iproute2-ss200127" ;;
  -4)
    shift
    [ "$1" = "addr" ] && [ "$2" = "show" ] && [ "$3" = "dev" ] && addr_show "$4"
    ;;
  addr)
    shift
    case "$1" in
      flush) echo "addr flush $3" >> "$MUT"; awk -v d="$3" '$1 != d' "$ADDRS" > "$R/addrs.$$"; mv "$R/addrs.$$" "$ADDRS" ;;
      show) [ "$2" = "dev" ] && addr_show "$3" ;;
    esac
    ;;
  link)
    shift
    [ "$1" = "set" ] && echo "link set $4" >> "$MUT"
    ;;
  route)
    shift
    case "$1" in
      show) shift; show_route "$@" ;;
      add) shift; route_add "$@" ;;
      replace) shift; route_replace "$@" ;;
      del) shift; route_del "$@" ;;
      flush) [ "${2:-}" = "cache" ] && echo "route flush cache" >> "$MUT" ;;
      get) shift; route_get "$@" ;;
    esac
    ;;
  *) exit 2 ;;
esac
EOS
chmod 755 "$TMP/bin/ip"

case_id=0

new_case() {
  case_id=$((case_id + 1))
  C="$TMP/case-$case_id"
  mkdir -p "$C"
  cat > "$C/routes" <<'EOS'
default via 192.0.2.1 dev wlan0
192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20
192.0.2.0/24 dev usb0 proto kernel scope link src 192.0.2.10
EOS
  cat > "$C/addrs" <<'EOS'
wlan0 192.0.2.20 24
usb0 192.0.2.10 24
EOS
  : > "$C/mutations"
}

run_probe() {
  report="$C/report.txt"
  PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" PACKAGE_DIR="$TMP/package" REPORT="$report" \
    DETACHED_VERIFY="${DETACHED_VERIFY:-0}" DETACHED_ROLLBACK_DELAY=0 \
    SSH_CLIENT="192.0.2.50 55555 22" SSH_CONNECTION="192.0.2.50 55555 192.0.2.20 22" \
    TIMEOUT_SECONDS=20 "$SH" "$ROOT/development/k1c-route-capability-probe.sh" >/dev/null
}

assert_grep() {
  pattern="$1"
  file="$2"
  grep -E "$pattern" "$file" >/dev/null || {
    echo "FAIL: expected $pattern in $file" >&2
    cat "$file" >&2
    exit 1
  }
}

assert_not_grep() {
  pattern="$1"
  file="$2"
  if grep -E "$pattern" "$file" >/dev/null; then
    echo "FAIL: unexpected $pattern in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

new_case
MOCK_CONNECTED_DELETE=exact MOCK_DEFAULT_DELETE=only_metricless run_probe
assert_grep '^USB_KERNEL_CONNECTED_EXACT_DELETE=SUPPORTED$' "$C/report.txt"
assert_grep '^WIFI_KERNEL_CONNECTED_EXACT_DELETE=SUPPORTED$' "$C/report.txt"
assert_grep '^WIFI_METRICLESS_DEFAULT_DELETE=SUPPORTED$' "$C/report.txt"
assert_grep '^EXPLICIT_CONNECTED_ROUTE_ADD=SUPPORTED$' "$C/report.txt"
assert_grep '^ROUTE_CACHE_FLUSH=SUPPORTED$' "$C/report.txt"
assert_grep '^USB_SOURCE_LOOKUP_AFTER_CONVERSION=usb0$' "$C/report.txt"
assert_grep '^PROBE_SSH_PRESERVATION_ROUTE_ACTIVE=YES$' "$C/report.txt"
assert_grep '^PROBE_SSH_PRESERVATION_LOOKUP=wlan0$' "$C/report.txt"
assert_grep '^USB_GATEWAY_LOOKUP_AFTER_CONVERSION=usb0$' "$C/report.txt"
assert_grep '^USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION=usb0$' "$C/report.txt"
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=YES$' "$C/report.txt"
assert_grep 'boot hook absent: /etc/init.d/S46usb_ethernet_primary' "$C/report.txt"
assert_grep 'route add 192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50' "$C/mutations"
assert_grep 'route del 192\.0\.2\.0/24 dev=usb0 src=192\.0\.2\.10 form=exact' "$C/mutations"
echo "PASS: probe exact route-only conversion supported"

new_case
MOCK_CONNECTED_DELETE=proto MOCK_DEFAULT_DELETE=only_metricless run_probe
assert_grep '^USB_KERNEL_CONNECTED_EXACT_DELETE=UNSUPPORTED$' "$C/report.txt"
assert_grep '^WIFI_KERNEL_CONNECTED_EXACT_DELETE=UNSUPPORTED$' "$C/report.txt"
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=YES$' "$C/report.txt"
assert_grep 'route del 192\.0\.2\.0/24 dev=usb0 src= form=proto' "$C/mutations"
echo "PASS: probe progressive connected deletion reaches less-specific form"

new_case
MOCK_CONNECTED_DELETE=exact MOCK_DEFAULT_DELETE=both run_probe
assert_grep '^WIFI_METRICLESS_DEFAULT_DELETE=UNSUPPORTED$' "$C/report.txt"
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=NO$' "$C/report.txt"
assert_grep '^default via 192\.0\.2\.1 dev wlan0$' "$C/routes"
echo "PASS: probe detects unsafe default deletion and rolls back"

new_case
MOCK_CONNECTED_DELETE=wrong_explicit MOCK_DEFAULT_DELETE=only_metricless run_probe
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=NO$' "$C/report.txt"
assert_grep '^192\.0\.2\.0/24 dev wlan0 proto kernel scope link src 192\.0\.2\.20$' "$C/routes"
assert_grep '^default via 192\.0\.2\.1 dev wlan0$' "$C/routes"
assert_not_grep '^192\.0\.2\.50/32' "$C/routes"
echo "PASS: probe rolls back after connected-route partial failure"

new_case
MOCK_CONNECTED_DELETE=exact MOCK_DEFAULT_DELETE=only_metricless MOCK_OMIT_FILTERED_DEV=1 run_probe
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=YES$' "$C/report.txt"
assert_not_grep 'cmd=.* dev  metric' "$C/report.txt"
echo "PASS: probe uses caller-supplied interface when filtered output omits dev"

new_case
DETACHED_VERIFY=1 MOCK_CONNECTED_DELETE=exact MOCK_DEFAULT_DELETE=only_metricless run_probe
assert_grep '^PROBE_SSH_PRESERVATION_ROUTE_ACTIVE=NO$' "$C/report.txt"
assert_grep '^PROBE_SSH_PRESERVATION_LOOKUP=usb0$' "$C/report.txt"
assert_grep '^USB_GATEWAY_LOOKUP_AFTER_CONVERSION=usb0$' "$C/report.txt"
assert_grep '^USB_GENERAL_LAN_LOOKUP_AFTER_CONVERSION=usb0$' "$C/report.txt"
assert_grep '^SAFE_ROUTE_ONLY_STRATEGY=YES$' "$C/report.txt"
assert_grep 'detached verification sleeping 0s before rollback' "$C/report.txt"
assert_not_grep '^192\.0\.2\.50/32' "$C/routes"
echo "PASS: detached probe verification omits ssh preservation route"

echo "route capability probe regression checks passed"
