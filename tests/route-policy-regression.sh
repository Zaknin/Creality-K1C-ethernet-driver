#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-route-policy-test-$$"
SH="${SH:-/usr/bin/sh}"

cleanup() {
  [ "${KEEP_TMP:-0}" = "1" ] && {
    echo "keeping $TMP" >&2
    return
  }
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/bin"

cat > "$TMP/bin/ip" <<'EOS'
#!/bin/sh
set -eu

R="$MOCK_ROOT"
ROUTES="$R/routes"
ADDRS="$R/addrs"
MUT="$R/mutations"

touch "$ROUTES" "$ADDRS" "$MUT"

metric_of() {
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

has_dev() {
  line="$1"
  dev="$2"
  printf '%s\n' "$line" | awk -v dev="$dev" '{ for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == dev) ok=1 } END { exit ok ? 0 : 1 }'
}

field_after() {
  key="$1"
  shift
  printf '%s\n' "$*" | awk -v key="$key" '{ for (i = 1; i <= NF; i++) if ($i == key) { print $(i + 1); exit } }'
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
  awk -v p="$prefix" -v d="$dev" '{
    line=$0; has_dev=0
    for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) has_dev=1
    if ($1 == p && (d == "" || has_dev)) print line
  }' "$ROUTES"
}

delete_route() {
  [ "${MOCK_FAIL_DEL:-0}" = "1" ] && exit 2
  prefix="$1"
  shift
  dev=""
  via=""
  metric=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      via) via="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  tmp="$R/routes.$$"
  awk -v p="$prefix" -v d="$dev" -v v="$via" -v m="$metric" '
    BEGIN { removed=0 }
    {
      has_dev=(d == ""); has_via=(v == ""); has_metric=(m == "")
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == d) has_dev=1
        if ($i == "via" && $(i + 1) == v) has_via=1
        if ($i == "metric" && $(i + 1) == m) has_metric=1
      }
      if (!removed && $1 == p && has_dev && has_via && has_metric) {
        removed=1
        next
      }
      print
    }
    END { if (!removed) exit 7 }
  ' "$ROUTES" > "$tmp" || { rm -f "$tmp"; exit 2; }
  mv "$tmp" "$ROUTES"
  echo "route del $prefix dev=$dev via=$via metric=$metric" >> "$MUT"
}

replace_route() {
  line="$*"
  echo "$line" >> "$ROUTES"
  echo "route replace $line" >> "$MUT"
}

ip4_addr_show() {
  dev="$1"
  awk -v d="$dev" '$1 == d { print "    inet " $2 "/" $3 " brd + scope global " d }' "$ADDRS"
}

addr_flush() {
  dev="$1"
  awk -v d="$dev" '$1 != d' "$ADDRS" > "$R/addrs.$$"
  mv "$R/addrs.$$" "$ADDRS"
  echo "addr flush $dev" >> "$MUT"
}

addr_add() {
  cidr="$1"
  shift
  dev=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  ip="${cidr%/*}"
  prefix="${cidr#*/}"
  awk -v d="$dev" '$1 != d' "$ADDRS" > "$R/addrs.$$"
  printf '%s %s %s\n' "$dev" "$ip" "$prefix" >> "$R/addrs.$$"
  mv "$R/addrs.$$" "$ADDRS"
  echo "addr add $dev $ip/$prefix" >> "$MUT"
}

link_show() {
  dev="$1"
  flags="BROADCAST,MULTICAST,UP,LOWER_UP"
  if [ -f "$R/sys/$dev/no-carrier" ]; then
    flags="NO-CARRIER,BROADCAST,MULTICAST,UP"
  fi
  echo "2: $dev: <$flags> mtu 1500 state $(cat "$R/sys/$dev/operstate" 2>/dev/null || echo UP)"
}

prefix_match() {
  dst="$1"
  prefix="$2"
  case "$prefix" in
    */24)
      net="${prefix%.*}.0/24"
      dnet="$(printf '%s\n' "$dst" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }')"
      [ "$net" = "$dnet" ]
      ;;
    default) return 0 ;;
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
      metric="$(printf '%s\n' "$line" | metric_of)"
      if [ "$metric" -lt "$best_metric" ]; then
        best="$line"
        best_metric="$metric"
      fi
    fi
  done < "$ROUTES"
  [ -n "$best" ] || exit 1
  dev="$(printf '%s\n' "$best" | line_dev)"
  route_src="$(field_after src "$best")"
  [ -n "$route_src" ] || route_src="$src"
  [ -n "$route_src" ] || route_src="0.0.0.0"
  echo "$dst from $src dev $dev src $route_src"
}

case "${1:-}" in
  -4)
    shift
    [ "$1" = "addr" ] && [ "$2" = "show" ] && [ "$3" = "dev" ] && ip4_addr_show "$4"
    ;;
  addr)
    shift
    case "$1" in
      show) [ "$2" = "dev" ] && ip4_addr_show "$3" ;;
      flush) [ "$2" = "dev" ] && addr_flush "$3" ;;
      add) shift; addr_add "$@" ;;
    esac
    ;;
  link)
    shift
    case "$1" in
      set) echo "link set $4" >> "$MUT" ;;
      show) [ "$2" = "dev" ] && link_show "$3" ;;
    esac
    ;;
  route)
    shift
    case "$1" in
      show) shift; show_route "$@" ;;
      del) shift; delete_route "$@" ;;
      replace) shift; replace_route "$@" ;;
      flush)
        if [ "${2:-}" = "cache" ]; then
          [ "${MOCK_FAIL_CACHE:-0}" = "1" ] && exit 2
          echo "route flush cache" >> "$MUT"
        elif [ "${2:-}" = "dev" ]; then
          dev="$3"
          awk -v d="$dev" '{ keep=1; for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) keep=0; if (keep) print }' "$ROUTES" > "$R/routes.$$"
          mv "$R/routes.$$" "$ROUTES"
          echo "route flush dev $dev" >> "$MUT"
        fi
        ;;
      get) shift; route_get "$@" ;;
      *) cat "$ROUTES" ;;
    esac
    ;;
  -brief)
    echo "mock brief"
    ;;
  *)
    exit 2
    ;;
esac
EOS
chmod 755 "$TMP/bin/ip"

case_id=0

new_case() {
  case_id=$((case_id + 1))
  C="$TMP/case-$case_id"
  mkdir -p "$C/state" "$C/sys/usb0" "$C/sys/wlan0"
  : > "$C/routes"
  : > "$C/addrs"
  : > "$C/mutations"
  echo 1 > "$C/sys/usb0/carrier"
  echo up > "$C/sys/usb0/operstate"
  echo 1 > "$C/sys/wlan0/carrier"
  echo up > "$C/sys/wlan0/operstate"
  echo "nameserver 192.0.2.53" > "$C/resolv.conf"
  printf 'wlan0 192.0.2.20 24\n' > "$C/addrs"
}

run_script() {
  event="$1"
  shift
  PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_DEL="${MOCK_FAIL_DEL:-0}" MOCK_FAIL_CACHE="${MOCK_FAIL_CACHE:-0}" \
    PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" \
    SYS_CLASS_NET="$C/sys" RESOLV_CONF="$C/resolv.conf" LOG_FILE="$C/log" \
    interface=usb0 ip=192.0.2.10 router=192.0.2.1 mask=24 dns="1.1.1.1 9.9.9.9" \
    "$SH" "$ROOT/package/usb0-udhcpc-script.sh" "$event" "$@"
}

run_monitor_once() {
  PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_DEL="${MOCK_FAIL_DEL:-0}" MOCK_FAIL_CACHE="${MOCK_FAIL_CACHE:-0}" \
    PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" \
    SYS_CLASS_NET="$C/sys" RESOLV_CONF="$C/resolv.conf" LOG_FILE="$C/log" MONITOR_ONCE=1 \
    "$SH" "$ROOT/package/usb0-route-monitor.sh"
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

assert_count() {
  expected="$1"
  pattern="$2"
  actual="$(grep -Ec "$pattern" "$C/routes" || true)"
  [ "$actual" = "$expected" ] || {
    echo "FAIL: expected $expected matches for $pattern, got $actual" >&2
    cat "$C/routes" >&2
    exit 1
  }
}

assert_lookup_usb() {
  out="$(PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" ip route get 192.0.2.1 from 192.0.2.10)"
  printf '%s\n' "$out" | grep ' dev usb0 ' >/dev/null || {
    echo "FAIL: lookup did not select usb0: $out" >&2
    cat "$C/routes" >&2
    exit 1
  }
}

seed_active_state() {
  printf '192.0.2.10\n' > "$C/state/usb0.ip"
  printf '24\n' > "$C/state/usb0.prefix"
  printf '192.0.2.1\n' > "$C/state/usb0.router"
  printf '192.0.2.1\n' > "$C/state/wifi.gateway"
  printf '192.0.2.20\n' > "$C/state/wifi.ip"
  printf '24\n' > "$C/state/wifi.prefix"
  echo active > "$C/state/ethernet.active"
  echo "nameserver 192.0.2.53" > "$C/state/resolv.conf.wifi"
}

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_not_grep '^default via 192\.0\.2\.1 dev wlan0$' "$C/routes"
assert_lookup_usb
echo "PASS: firmware metricless default repaired"

new_case
printf 'default via 192.0.2.1 dev wlan0\ndefault via 192.0.2.1 dev wlan0 metric 300\ndefault via 192.0.2.1 dev wlan0 metric 100\ndefault via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev usb0 metric 50\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
echo "PASS: duplicate defaults collapsed"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n192.0.2.0/24 dev usb0 proto kernel scope link src 192.0.2.10\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 100\n' > "$C/routes"
seed_active_state
run_monitor_once
assert_count 1 '^192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50$'
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$'
assert_lookup_usb
echo "PASS: same-subnet connected routes repaired"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
run_script bound
run_script renew
run_script renew
run_monitor_once
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_count 1 '^192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50$'
echo "PASS: bound renew and reconcile idempotent"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
touch "$C/sys/wlan0/no-carrier"
echo dormant > "$C/sys/wlan0/operstate"
seed_active_state
run_monitor_once
assert_grep '^default via 192\.0\.2\.1 dev usb0 metric 50$' "$C/routes"
assert_not_grep '^default via 192\.0\.2\.1 dev wlan0' "$C/routes"
[ -f "$C/state/ethernet.active" ] || { echo "FAIL: active state was cleared during wifi disable" >&2; exit 1; }
: > "$C/mutations"
run_monitor_once
[ ! -s "$C/mutations" ] || { echo "FAIL: wifi-disabled steady state mutated routes" >&2; cat "$C/mutations" >&2; exit 1; }
echo "PASS: wifi disable does not trigger usb leasefail"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
run_monitor_once
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$'
assert_lookup_usb
echo "PASS: wifi route recreation reconciled"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
echo 0 > "$C/sys/usb0/carrier"
run_monitor_once
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 100$'
assert_not_grep 'dev usb0' "$C/routes"
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: active state remained after cable loss" >&2; exit 1; }
assert_grep 'nameserver 192\.0\.2\.53' "$C/resolv.conf"
echo "PASS: usb cable loss restores wifi fallback"

new_case
printf 'default via 192.0.2.1 dev wlan0 metric 100\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 100\n' > "$C/routes"
run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_lookup_usb
echo "PASS: usb reconnection restores primary"

new_case
printf '' > "$C/routes"
run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
echo "PASS: missing routes tolerated"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 100\n' > "$C/routes"
seed_active_state
if MOCK_FAIL_DEL=1 run_monitor_once >/dev/null 2>&1; then
  echo "FAIL: route deletion failure unexpectedly succeeded" >&2
  exit 1
fi
assert_grep 'failed removing' "$C/log"
echo "PASS: command failure is bounded and logged"

new_case
printf 'default via 192.0.2.1 dev wlan0\n' > "$C/routes"
mkdir "$C/state/route.lock"
echo 999999 > "$C/state/route.lock/pid"
echo 1 > "$C/state/route.lock/time"
run_script bound
[ ! -d "$C/state/route.lock" ] || { echo "FAIL: lock was not released" >&2; exit 1; }
assert_grep 'route_lock stale' "$C/log"
echo "PASS: stale lock recovery works"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
: > "$C/mutations"
run_monitor_once
[ ! -s "$C/mutations" ] || { echo "FAIL: no-op reconciliation mutated routes" >&2; cat "$C/mutations" >&2; exit 1; }
echo "PASS: no-op reconciliation is quiet"

echo "route policy regression checks passed"
