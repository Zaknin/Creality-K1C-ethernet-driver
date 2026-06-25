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

line_via() {
  awk '{ for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
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
  awk -v p="$prefix" -v d="$dev" -v omit="${MOCK_OMIT_FILTERED_DEV:-0}" '{
    line=$0; has_dev=0
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
        print line
      }
    }
  }' "$ROUTES"
}

delete_route() {
  [ "${MOCK_FAIL_DEL:-0}" = "1" ] && { echo "mock forced delete failure" >&2; exit 2; }
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
  awk -v p="$prefix" -v d="$dev" -v v="$via" -v m="$metric" -v fail_kernel="${MOCK_FAIL_KERNEL_DEL:-0}" '
    BEGIN { removed=0 }
    {
      has_dev=(d == ""); has_via=(v == ""); has_metric=(m == "")
      is_kernel=0; is_link=0
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == d) has_dev=1
        if ($i == "via" && $(i + 1) == v) has_via=1
        if ($i == "metric" && $(i + 1) == m) has_metric=1
        if ($i == "proto" && $(i + 1) == "kernel") is_kernel=1
        if ($i == "scope" && $(i + 1) == "link") is_link=1
      }
      if (!removed && fail_kernel == "1" && $1 == p && has_dev && is_kernel && is_link) {
        print "RTNETLINK answers: No such process" > "/dev/stderr"
        exit 9
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
  prefix="$1"
  shift
  dev=""
  src=""
  metric=""
  via=""
  proto=""
  scope=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      src) src="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      via) via="$2"; shift 2 ;;
      proto) proto="$2"; shift 2 ;;
      scope) scope="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ "$prefix" = "default" ]; then
    line="default via $via dev $dev"
    [ -n "$metric" ] && line="$line metric $metric"
  else
    form=plain
    [ "$scope" = "link" ] && form=scope_link
    [ "$proto" = "kernel" ] && [ "$scope" = "link" ] && form=proto_kernel
    case " ${MOCK_RESTORE_ABSENT_FORMS:-} " in
      *" $form "*) echo "route replace $prefix dev $dev form=$form absent" >> "$MUT"; exit 0 ;;
    esac
    line="$prefix dev $dev"
    [ -n "$proto" ] && line="$line proto $proto"
    [ -n "$scope" ] && line="$line scope $scope"
    [ -n "$src" ] && line="$line src $src"
    [ -n "$metric" ] && line="$line metric $metric"
  fi
  echo "$line" >> "$ROUTES"
  echo "route replace $line" >> "$MUT"
}

add_route() {
  line="$*"
  echo "$line" >> "$ROUTES"
  echo "route add $line" >> "$MUT"
}

change_route() {
  prefix="$1"
  shift
  dev=""
  src=""
  metric=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      dev) dev="$2"; shift 2 ;;
      src) src="$2"; shift 2 ;;
      metric) metric="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ "${MOCK_FAIL_CHANGE:-0}" = "1" ] && { echo "mock route change unsupported" >&2; exit 2; }
  tmp="$R/routes.$$"
  awk -v p="$prefix" -v d="$dev" -v s="$src" -v m="$metric" '
    BEGIN { changed=0 }
    {
      has_dev=0; has_src=(s == ""); is_kernel=0; is_link=0
      for (i = 1; i <= NF; i++) {
        if ($i == "dev" && $(i + 1) == d) has_dev=1
        if ($i == "src" && $(i + 1) == s) has_src=1
        if ($i == "proto" && $(i + 1) == "kernel") is_kernel=1
        if ($i == "scope" && $(i + 1) == "link") is_link=1
      }
      if (!changed && $1 == p && has_dev && has_src && is_kernel && is_link) {
        print p " dev " d " proto kernel scope link src " s " metric " m
        changed=1
        next
      }
      print
    }
    END { if (!changed) exit 7 }
  ' "$ROUTES" > "$tmp" || { rm -f "$tmp"; echo "RTNETLINK answers: No such process" >&2; exit 2; }
  mv "$tmp" "$ROUTES"
  echo "route change $prefix dev=$dev src=$src metric=$metric" >> "$MUT"
}

ip4_addr_show() {
  dev="$1"
  awk -v d="$dev" '$1 == d { print "    inet " $2 "/" $3 " brd + scope global " d }' "$ADDRS"
}

addr_flush() {
  dev="$1"
  awk -v d="$dev" '$1 != d' "$ADDRS" > "$R/addrs.$$"
  mv "$R/addrs.$$" "$ADDRS"
  awk -v d="$dev" '{
    has_dev=0
    for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) has_dev=1
    if (!has_dev) print
  }' "$ROUTES" > "$R/routes.$$"
  mv "$R/routes.$$" "$ROUTES"
  if [ "$dev" = "usb0" ] && [ "${MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH:-0}" = "1" ]; then
    awk '{
      drop=0
      if ($1 == "192.0.2.0/24") {
        has_wlan=0; has_metric=0
        for (i = 1; i <= NF; i++) {
          if ($i == "dev" && $(i + 1) == "wlan0") has_wlan=1
          if ($i == "metric") has_metric=1
        }
        if (has_wlan && !has_metric) drop=1
      }
      if (!drop) print
    }' "$ROUTES" > "$R/routes.$$"
    mv "$R/routes.$$" "$ROUTES"
  fi
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
  if [ "${MOCK_KERNEL_ON_ADDR:-0}" = "1" ] && [ "$prefix" = "24" ]; then
    route_prefix="$(printf '%s\n' "$ip" | awk -F. '{ print $1 "." $2 "." $3 ".0/24" }')"
    awk -v p="$route_prefix" -v d="$dev" '{
      keep=1
      if ($1 == p) {
        for (i = 1; i <= NF; i++) if ($i == "dev" && $(i + 1) == d) keep=0
      }
      if (keep) print
    }' "$ROUTES" > "$R/routes.$$"
    printf '%s dev %s proto kernel scope link src %s\n' "$route_prefix" "$dev" "$ip" >> "$R/routes.$$"
    mv "$R/routes.$$" "$ROUTES"
  fi
  echo "addr add $dev $ip/$prefix" >> "$MUT"
}

link_show() {
  dev="$1"
  [ -d "$R/sys/$dev" ] || exit 1
  flags="BROADCAST,MULTICAST,UP,LOWER_UP"
  if [ -f "$R/sys/$dev/no-carrier" ]; then
    flags="NO-CARRIER,BROADCAST,MULTICAST,UP"
  fi
  echo "2: $dev: <$flags> mtu 1500 state $(cat "$R/sys/$dev/operstate" 2>/dev/null || echo UP)"
}

link_set() {
  if [ "${1:-}" = "dev" ]; then
    dev="$2"
    action="$3"
  else
    dev="$1"
    action="$2"
  fi
  [ -d "$R/sys/$dev" ] || exit 1
  echo "link set $dev $action" >> "$MUT"
  if [ "$action" = "up" ]; then
    echo up > "$R/sys/$dev/operstate"
    if [ "$dev" = "usb0" ] && [ "${MOCK_USB_LINK_UP_SETS_CARRIER:-0}" = "1" ]; then
      echo 1 > "$R/sys/$dev/carrier"
    fi
  fi
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

prefix_rank() {
  case "$1" in
    */32) echo 32 ;;
    */24) echo 24 ;;
    default) echo 0 ;;
    *) echo 0 ;;
  esac
}

route_get() {
  dst="$1"
  src=""
  if [ "${2:-}" = "from" ]; then
    src="$3"
  fi
  best=""
  best_rank=-1
  best_metric=999999
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    set -- $line
    prefix="$1"
    if prefix_match "$dst" "$prefix"; then
      metric="$(printf '%s\n' "$line" | metric_of)"
      rank="$(prefix_rank "$prefix")"
      if [ "$rank" -gt "$best_rank" ] || { [ "$rank" -eq "$best_rank" ] && [ "$metric" -lt "$best_metric" ]; }; then
        best="$line"
        best_rank="$rank"
        best_metric="$metric"
      fi
    fi
  done < "$ROUTES"
  [ -n "$best" ] || exit 1
  dev="$(printf '%s\n' "$best" | line_dev)"
  via="$(printf '%s\n' "$best" | line_via)"
  route_src="$(field_after src "$best")"
  [ -n "$route_src" ] || route_src="$src"
  [ -n "$route_src" ] || route_src="0.0.0.0"
  if [ -n "$via" ]; then
    echo "$dst from $src via $via dev $dev src $route_src"
  else
    echo "$dst from $src dev $dev src $route_src"
  fi
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
      set) shift; link_set "$@" ;;
      show) [ "$2" = "dev" ] && link_show "$3" ;;
    esac
    ;;
  route)
    shift
    case "$1" in
      show) shift; show_route "$@" ;;
      add) shift; add_route "$@" ;;
      del) shift; delete_route "$@" ;;
      replace) shift; replace_route "$@" ;;
      change) shift; change_route "$@" ;;
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

cat > "$TMP/bin/mock-kill" <<'EOS'
#!/bin/sh
set -eu

R="$MOCK_ROOT"
MUT="$R/mutations"

sig=TERM
case "${1:-}" in
  -0)
    pid="$2"
    [ -f "$R/proc/$pid/alive" ]
    exit $?
    ;;
  -*)
    sig="${1#-}"
    shift
    ;;
esac

pid="$1"
echo "kill $sig $pid" >> "$MUT"
[ -f "$R/proc/$pid/ignore-term" ] && exit 0
rm -f "$R/proc/$pid/alive"
exit 0
EOS
chmod 755 "$TMP/bin/mock-kill"

cat > "$TMP/bin/nohup" <<'EOS'
#!/bin/sh
exec "$@"
EOS
chmod 755 "$TMP/bin/nohup"

cat > "$TMP/bin/udhcpc" <<'EOS'
#!/bin/sh
set -eu

R="$MOCK_ROOT"
MUT="$R/mutations"
iface=""
pidfile=""
script=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -i) iface="$2"; shift 2 ;;
    -p) pidfile="$2"; shift 2 ;;
    -s) script="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "udhcpc start iface=$iface pidfile=$pidfile script=$script" >> "$MUT"
if [ "${MOCK_UDHCPC_BOUND_ON_START:-0}" = "1" ]; then
  interface="$iface" ip=192.0.2.10 router=192.0.2.1 mask=24 dns="1.1.1.1 9.9.9.9" \
    "${SH:-/usr/bin/sh}" "$script" bound
fi
exit 0
EOS
chmod 755 "$TMP/bin/udhcpc"

case_id=0

new_case() {
  case_id=$((case_id + 1))
  C="$TMP/case-$case_id"
  mkdir -p "$C/state" "$C/sys/usb0" "$C/sys/wlan0" "$C/proc"
  : > "$C/routes"
  : > "$C/addrs"
  : > "$C/mutations"
  echo 1 > "$C/sys/usb0/carrier"
  echo up > "$C/sys/usb0/operstate"
  echo 1 > "$C/sys/wlan0/carrier"
  echo up > "$C/sys/wlan0/operstate"
  echo "nameserver 192.0.2.53" > "$C/resolv.conf"
  printf 'wlan0 192.0.2.20 24\n' > "$C/addrs"
  unset MOCK_FAIL_DEL MOCK_FAIL_CACHE MOCK_FAIL_KERNEL_DEL MOCK_FAIL_CHANGE MOCK_KERNEL_ON_ADDR MOCK_OMIT_FILTERED_DEV MOCK_RESTORE_ABSENT_FORMS MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH MOCK_USB_LINK_UP_SETS_CARRIER MOCK_UDHCPC_BOUND_ON_START
}

run_script() {
  event="$1"
  shift
  PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_DEL="${MOCK_FAIL_DEL:-0}" MOCK_FAIL_CACHE="${MOCK_FAIL_CACHE:-0}" \
    MOCK_FAIL_KERNEL_DEL="${MOCK_FAIL_KERNEL_DEL:-0}" MOCK_FAIL_CHANGE="${MOCK_FAIL_CHANGE:-0}" \
    MOCK_RESTORE_ABSENT_FORMS="${MOCK_RESTORE_ABSENT_FORMS:-}" \
    MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH="${MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH:-0}" \
    MOCK_USB_LINK_UP_SETS_CARRIER="${MOCK_USB_LINK_UP_SETS_CARRIER:-0}" \
    MOCK_UDHCPC_BOUND_ON_START="${MOCK_UDHCPC_BOUND_ON_START:-0}" \
    MOCK_KERNEL_ON_ADDR="${MOCK_KERNEL_ON_ADDR:-0}" MOCK_OMIT_FILTERED_DEV="${MOCK_OMIT_FILTERED_DEV:-0}" \
    PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" PROC_ROOT="$C/proc" KILL_CMD="$TMP/bin/mock-kill" \
    SYS_CLASS_NET="$C/sys" RESOLV_CONF="$C/resolv.conf" LOG_FILE="$C/log" \
    interface=usb0 ip=192.0.2.10 router=192.0.2.1 mask=24 dns="1.1.1.1 9.9.9.9" \
    "$SH" "$ROOT/package/usb0-udhcpc-script.sh" "$event" "$@"
}

run_monitor_once() {
  PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_DEL="${MOCK_FAIL_DEL:-0}" MOCK_FAIL_CACHE="${MOCK_FAIL_CACHE:-0}" \
    MOCK_FAIL_KERNEL_DEL="${MOCK_FAIL_KERNEL_DEL:-0}" MOCK_FAIL_CHANGE="${MOCK_FAIL_CHANGE:-0}" \
    MOCK_RESTORE_ABSENT_FORMS="${MOCK_RESTORE_ABSENT_FORMS:-}" \
    MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH="${MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH:-0}" \
    MOCK_USB_LINK_UP_SETS_CARRIER="${MOCK_USB_LINK_UP_SETS_CARRIER:-0}" \
    MOCK_UDHCPC_BOUND_ON_START="${MOCK_UDHCPC_BOUND_ON_START:-0}" \
    MOCK_KERNEL_ON_ADDR="${MOCK_KERNEL_ON_ADDR:-0}" MOCK_OMIT_FILTERED_DEV="${MOCK_OMIT_FILTERED_DEV:-0}" \
    PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" PROC_ROOT="$C/proc" KILL_CMD="$TMP/bin/mock-kill" \
    SYS_CLASS_NET="$C/sys" RESOLV_CONF="$C/resolv.conf" LOG_FILE="$C/log" MONITOR_ONCE=1 \
    USB_RECREATE_CARRIER_WAIT=1 DHCP_RECOVERY_GRACE=0 DHCP_STOP_WAIT=1 DHCP_REPLACEMENT_TIMEOUT=30 \
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

assert_lookup_wifi_direct() {
  out="$(PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" ip route get 192.0.2.1)"
  printf '%s\n' "$out" | grep ' dev wlan0 ' >/dev/null || {
    echo "FAIL: lookup did not select wlan0: $out" >&2
    cat "$C/routes" >&2
    exit 1
  }
  if printf '%s\n' "$out" | grep ' via 192.0.2.1 ' >/dev/null; then
    echo "FAIL: lookup used gateway via itself: $out" >&2
    cat "$C/routes" >&2
    exit 1
  fi
}

seed_active_state() {
  awk '$1 != "usb0"' "$C/addrs" > "$C/addrs.$$"
  printf 'usb0 192.0.2.10 24\n' >> "$C/addrs.$$"
  mv "$C/addrs.$$" "$C/addrs"
  printf '192.0.2.10\n' > "$C/state/usb0.ip"
  printf '24\n' > "$C/state/usb0.prefix"
  printf '192.0.2.1\n' > "$C/state/usb0.router"
  printf '192.0.2.1\n' > "$C/state/wifi.gateway"
  printf '192.0.2.20\n' > "$C/state/wifi.ip"
  printf '24\n' > "$C/state/wifi.prefix"
  echo active > "$C/state/ethernet.active"
  echo "nameserver 192.0.2.53" > "$C/state/resolv.conf.wifi"
}

seed_runtime_dhcp_process() {
  pid="$1"
  mkdir -p "$C/proc/$pid"
  : > "$C/proc/$pid/alive"
  printf '%s\n' "$pid" > "$C/state/udhcpc-usb0.pid"
  printf 'udhcpc\000-i\000usb0\000-f\000-t\0003\000-T\0004\000-p\000%s\000-s\000%s\000' \
    "$C/state/udhcpc-usb0.pid" "$ROOT/package/usb0-udhcpc-script.sh" > "$C/proc/$pid/cmdline"
}

seed_unrelated_process() {
  pid="$1"
  mkdir -p "$C/proc/$pid"
  : > "$C/proc/$pid/alive"
  printf '%s\n' "$pid" > "$C/state/udhcpc-usb0.pid"
  printf 'sleep\000999\000' > "$C/proc/$pid/cmdline"
}

wait_for_active_state() {
  i=0
  while [ "$i" -le 5 ]; do
    [ -f "$C/state/ethernet.active" ] && return 0
    sleep 1
    i=$((i + 1))
  done
  echo "FAIL: ethernet.active was not restored" >&2
  cat "$C/log" >&2
  cat "$C/mutations" >&2
  exit 1
}

remove_usb_interface() {
  rm -rf "$C/sys/usb0"
  awk '$1 != "usb0"' "$C/addrs" > "$C/addrs.$$"
  mv "$C/addrs.$$" "$C/addrs"
}

recreate_usb_interface_down() {
  mkdir -p "$C/sys/usb0"
  echo 0 > "$C/sys/usb0/carrier"
  echo down > "$C/sys/usb0/operstate"
}

new_case
printf '192.0.2.0/24 dev usb0 proto kernel scope link src 192.0.2.10\n' > "$C/routes"
if PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_KERNEL_DEL=1 \
  PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" LOG_FILE="$C/log" \
  "$SH" -c '. "$0"; delete_one_route_line "$1" "$2" "$3" "$4"' \
  "$ROOT/package/primary-routing-lib.sh" \
  '192.0.2.0/24 dev usb0 proto kernel scope link src 192.0.2.10' usb0 direct-kernel connected >/dev/null 2>&1; then
  echo "FAIL: direct kernel route deletion unexpectedly succeeded" >&2
  exit 1
fi
assert_grep 'route_delete failed category=connected label=direct-kernel prefix=192\.0\.2\.0/24 supplied_dev=usb0 original=\[192\.0\.2\.0/24 dev usb0 proto kernel scope link src 192\.0\.2\.10\].*RTNETLINK answers' "$C/log"
echo "PASS: kernel connected deletion failure logs original route and stderr"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
MOCK_KERNEL_ON_ADDR=1 run_script bound
assert_count 1 '^192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50$'
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$'
assert_grep '^route add 192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50$' "$C/mutations"
assert_grep '^route del 192\.0\.2\.0/24 dev=usb0 via= metric=$' "$C/mutations"
assert_grep '^route add 192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$' "$C/mutations"
[ -f "$C/state/usb0.ip" ] || { echo "FAIL: usb state was not written after verified add-delete route conversion" >&2; exit 1; }
[ -f "$C/state/ethernet.active" ] || { echo "FAIL: ethernet.active missing after verified add-delete route conversion" >&2; exit 1; }
assert_lookup_usb
echo "PASS: physical kernel connected route is converted by add-delete before active state"

new_case
printf 'default via 192.0.2.1 dev wlan0 metric 100\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
if MOCK_KERNEL_ON_ADDR=1 MOCK_FAIL_KERNEL_DEL=1 run_script bound >/dev/null 2>&1; then
  echo "FAIL: unsupported connected-route capability unexpectedly succeeded" >&2
  exit 1
fi
assert_grep 'unsupported-target-routing label=usb connected prefix=192\.0\.2\.0/24 dev=usb0' "$C/log"
assert_grep 'usb-primary transaction failed reason=usb-connected-route; restoring wifi fallback' "$C/log"
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: ethernet.active written after failed verification" >&2; exit 1; }
[ ! -f "$C/state/usb0.ip" ] || { echo "FAIL: usb state written after failed verification" >&2; exit 1; }
assert_grep '^default via 192\.0\.2\.1 dev wlan0$' "$C/routes"
echo "PASS: unsupported connected-route capability rolls back without active state"

new_case
printf 'default via 192.0.2.1 dev wlan0 metric 100\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
MOCK_OMIT_FILTERED_DEV=1 run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_not_grep '^default via 192\.0\.2\.1 dev wlan0 metric 100$' "$C/routes"
echo "PASS: filtered default output without dev uses caller-supplied interface"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 proto kernel scope link src 192.0.2.20\n' > "$C/routes"
cat > "$C/resolv.conf" <<'EOS'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.8.8 # wlan0
nameserver 1.1.1.1 # wlan0
EOS
run_script bound
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_not_grep '^default via 192\.0\.2\.1 dev wlan0$' "$C/routes"
assert_count_file() {
  expected="$1"
  pattern="$2"
  file="$3"
  actual="$(grep -Ec "$pattern" "$file" || true)"
  [ "$actual" = "$expected" ] || {
    echo "FAIL: expected $expected matches for $pattern in $file, got $actual" >&2
    cat "$file" >&2
    exit 1
  }
}
assert_count_file 1 '^nameserver 8\.8\.8\.8 # wlan0$' "$C/state/resolv.conf.wifi"
assert_count_file 1 '^nameserver 1\.1\.1\.1 # wlan0$' "$C/state/resolv.conf.wifi"
assert_lookup_usb
echo "PASS: firmware metricless default repaired and wifi DNS snapshot deduped"

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
assert_not_grep '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 100$' "$C/routes"
assert_lookup_usb
echo "PASS: same-subnet connected routes repaired"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 scope link src 192.0.2.20\n' > "$C/routes"
MOCK_KERNEL_ON_ADDR=1 run_script bound
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$'
assert_not_grep '^192\.0\.2\.0/24 dev wlan0 scope link src 192\.0\.2\.20$' "$C/routes"
assert_grep 'metricless connected delete verified label=wifi .*form=dev_only' "$C/log"
assert_lookup_usb
echo "PASS: manual metricless Wi-Fi route converted with verified dev-only delete"

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
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
assert_not_grep 'dev usb0' "$C/routes"
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: active state remained after cable loss" >&2; exit 1; }
assert_grep 'nameserver 192\.0\.2\.53' "$C/resolv.conf"
echo "PASS: usb cable loss restores wifi fallback"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
echo 0 > "$C/sys/usb0/carrier"
run_monitor_once
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 scope link src 192\.0\.2\.20$'
assert_lookup_wifi_direct
assert_grep 'fallback verification ok stage=post-usb-cleanup' "$C/log"
echo "PASS: fallback restores verified scope-link Wi-Fi connected route"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
echo 0 > "$C/sys/usb0/carrier"
MOCK_DROP_WIFI_CONNECTED_ON_USB_FLUSH=1 run_monitor_once
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 scope link src 192\.0\.2\.20$'
assert_grep 'fallback verification failed stage=post-usb-cleanup' "$C/log"
assert_grep 'fallback verification ok stage=final' "$C/log"
assert_lookup_wifi_direct
echo "PASS: fallback retries Wi-Fi connected restore after USB cleanup"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
echo 0 > "$C/sys/usb0/carrier"
MOCK_RESTORE_ABSENT_FORMS="scope_link proto_kernel plain" run_monitor_once
assert_not_grep '^192\.0\.2\.0/24 dev wlan0 .*src 192\.0\.2\.20$' "$C/routes"
assert_grep 'fallback verification failed stage=final .*via=yes' "$C/log"
echo "PASS: fallback does not treat ping-capable via-gateway state as restored"

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
if PATH="$TMP/bin:$PATH" MOCK_ROOT="$C" MOCK_FAIL_DEL=1 \
  PACKAGE_DIR="$ROOT/package" STATE_DIR="$C/state" LOG_FILE="$C/log" \
  "$SH" -c '. "$0"; delete_one_route_line "$1" "$2" "$3" "$4"' \
  "$ROOT/package/primary-routing-lib.sh" \
  'default via 192.0.2.1 dev usb0 metric 100' usb0 usb-default default >/dev/null 2>&1; then
  echo "FAIL: route deletion failure unexpectedly succeeded" >&2
  exit 1
fi
assert_grep 'route_delete failed category=default label=usb-default .*error=mock forced delete failure' "$C/log"
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

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
seed_runtime_dhcp_process 1777
remove_usb_interface
run_monitor_once
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: fallback did not clear active state after usb0 disappeared" >&2; exit 1; }
[ -f "$C/proc/1777/alive" ] || { echo "FAIL: old DHCP process should remain alive until recreated carrier recovery" >&2; exit 1; }
recreate_usb_interface_down
: > "$C/mutations"
MOCK_USB_LINK_UP_SETS_CARRIER=1 MOCK_UDHCPC_BOUND_ON_START=1 run_monitor_once
wait_for_active_state
assert_grep 'usb0 interface recreated' "$C/log"
assert_grep '^link set usb0 up$' "$C/mutations"
assert_grep '^kill TERM 1777$' "$C/mutations"
assert_count_file 1 '^udhcpc start iface=usb0 ' "$C/mutations"
[ ! -f "$C/proc/1777/alive" ] || { echo "FAIL: stale runtime DHCP process was not terminated" >&2; exit 1; }
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
assert_count 1 '^192\.0\.2\.0/24 dev usb0 src 192\.0\.2\.10 metric 50$'
assert_count 1 '^192\.0\.2\.0/24 dev wlan0 src 192\.0\.2\.20 metric 300$'
assert_lookup_usb
: > "$C/mutations"
run_monitor_once
assert_not_grep '^udhcpc start iface=usb0 ' "$C/mutations"
echo "PASS: physical usb0 recreation invalidates stale alive DHCP process and starts one replacement"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 scope link src 192.0.2.20\n' > "$C/routes"
printf 'absent\n' > "$C/state/usb0.interface-presence"
seed_unrelated_process 1888
: > "$C/mutations"
MOCK_USB_LINK_UP_SETS_CARRIER=1 run_monitor_once
assert_not_grep '^kill ' "$C/mutations"
assert_count_file 1 '^udhcpc start iface=usb0 ' "$C/mutations"
[ -f "$C/proc/1888/alive" ] || { echo "FAIL: unrelated process was terminated" >&2; exit 1; }
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: inactive unrelated-PID recovery should not mark active without bound" >&2; exit 1; }
echo "PASS: unrelated old PID is not terminated during DHCP recovery"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 scope link src 192.0.2.20\n' > "$C/routes"
printf 'absent\n' > "$C/state/usb0.interface-presence"
rm -f "$C/state/udhcpc-usb0.pid"
: > "$C/mutations"
MOCK_USB_LINK_UP_SETS_CARRIER=1 run_monitor_once
assert_count_file 1 '^udhcpc start iface=usb0 ' "$C/mutations"
assert_not_grep '^kill ' "$C/mutations"
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: missing-PID recovery should not mark active without bound" >&2; exit 1; }
echo "PASS: missing old PID file starts one DHCP replacement without touching fallback"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 scope link src 192.0.2.20\n' > "$C/routes"
printf 'absent\n' > "$C/state/usb0.interface-presence"
recreate_usb_interface_down
: > "$C/mutations"
MOCK_USB_LINK_UP_SETS_CARRIER=0 run_monitor_once
assert_grep '^link set usb0 up$' "$C/mutations"
assert_not_grep '^udhcpc start iface=usb0 ' "$C/mutations"
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: carrier-missing recovery should retain wifi-only fallback" >&2; exit 1; }
echo "PASS: carrier-missing recreation retains Wi-Fi fallback without DHCP restart"

new_case
printf 'default via 192.0.2.1 dev wlan0\n192.0.2.0/24 dev wlan0 scope link src 192.0.2.20\n' > "$C/routes"
printf 'absent\n' > "$C/state/usb0.interface-presence"
seed_runtime_dhcp_process 1999
: > "$C/mutations"
MOCK_USB_LINK_UP_SETS_CARRIER=1 MOCK_UDHCPC_BOUND_ON_START=0 run_monitor_once
assert_grep '^kill TERM 1999$' "$C/mutations"
assert_count_file 1 '^udhcpc start iface=usb0 ' "$C/mutations"
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
[ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: timed-out replacement should not mark active" >&2; exit 1; }
MOCK_USB_LINK_UP_SETS_CARRIER=1 MOCK_UDHCPC_BOUND_ON_START=0 run_monitor_once
assert_count_file 1 '^udhcpc start iface=usb0 ' "$C/mutations"
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0$'
echo "PASS: DHCP replacement timeout path preserves fallback and suppresses duplicate launch while pending"

new_case
printf 'default via 192.0.2.1 dev usb0 metric 50\ndefault via 192.0.2.1 dev wlan0 metric 300\n192.0.2.0/24 dev usb0 src 192.0.2.10 metric 50\n192.0.2.0/24 dev wlan0 src 192.0.2.20 metric 300\n' > "$C/routes"
printf 'usb0 192.0.2.10 24\nwlan0 192.0.2.20 24\n' > "$C/addrs"
seed_active_state
: > "$C/mutations"
cycle=1
while [ "$cycle" -le 3 ]; do
  seed_runtime_dhcp_process "30$cycle"
  remove_usb_interface
  run_monitor_once
  [ ! -f "$C/state/ethernet.active" ] || { echo "FAIL: cycle $cycle did not enter fallback" >&2; exit 1; }
  recreate_usb_interface_down
  MOCK_USB_LINK_UP_SETS_CARRIER=1 MOCK_UDHCPC_BOUND_ON_START=1 run_monitor_once
  wait_for_active_state
  assert_lookup_usb
  cycle=$((cycle + 1))
done
assert_count_file 3 '^udhcpc start iface=usb0 ' "$C/mutations"
assert_count 1 '^default via 192\.0\.2\.1 dev usb0 metric 50$'
assert_count 1 '^default via 192\.0\.2\.1 dev wlan0 metric 300$'
echo "PASS: three physical-style reconnect cycles restore USB-primary operation"

echo "route policy regression checks passed"
