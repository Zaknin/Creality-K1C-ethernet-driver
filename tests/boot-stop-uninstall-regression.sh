#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-boot-stop-test-$$"
SH="${SH:-/usr/bin/sh}"
MONITOR_PID=""
DHCP_PID=""

cleanup() {
  if [ -n "$MONITOR_PID" ]; then
    kill -9 "$MONITOR_PID" >/dev/null 2>&1 || true
    wait "$MONITOR_PID" >/dev/null 2>&1 || true
  fi

  if [ -n "$DHCP_PID" ]; then
    kill -9 "$DHCP_PID" >/dev/null 2>&1 || true
    wait "$DHCP_PID" >/dev/null 2>&1 || true
  fi

  rm -rf "$TMP"
}

trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/work" "$TMP/init.d"
cp -R "$ROOT"/. "$TMP/work/"

cat > "$TMP/bin/uname" <<'EOS'
#!/bin/sh
case "${1:-}" in
  -r) echo 4.4.94 ;;
  *) /usr/bin/uname "$@" ;;
esac
EOS

chmod 755 "$TMP/bin/uname"

(
  cd "$TMP/work"

  PATH="$TMP/bin:$PATH" \
  BOOT_HOOK="$TMP/init.d/S46usb_ethernet_primary" \
    "$SH" install.sh \
      --enable-boot \
      --dest "$TMP/install" \
      > "$TMP/install.out"
)

[ -f "$TMP/install/.package-owned" ] || {
  echo "FAIL: install marker missing" >&2
  exit 1
}

[ -x "$TMP/install/primary-routing-lib.sh" ] || {
  echo "FAIL: helper not executable after install" >&2
  exit 1
}

[ -x "$TMP/install/usb0-route-monitor.sh" ] || {
  echo "FAIL: monitor not executable after install" >&2
  exit 1
}

[ -x "$TMP/init.d/S46usb_ethernet_primary" ] || {
  echo "FAIL: boot hook not installed" >&2
  exit 1
}

grep '^PACKAGE_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good$' \
  "$TMP/init.d/S46usb_ethernet_primary" >/dev/null || {
    echo "FAIL: boot hook package path changed" >&2
    exit 1
  }

grep 'start-primary-ethernet.sh' \
  "$TMP/init.d/S46usb_ethernet_primary" >/dev/null || {
    echo "FAIL: boot hook does not call expected runtime path" >&2
    exit 1
  }

mkdir -p "$TMP/no-marker"
cp "$ROOT/package/uninstall-usb-ethernet.sh" "$TMP/no-marker/"

if PACKAGE_DIR="$TMP/no-marker" \
  "$SH" "$TMP/no-marker/uninstall-usb-ethernet.sh" \
    --yes >/dev/null 2>&1
then
  echo "FAIL: uninstall succeeded without marker" >&2
  exit 1
fi

[ -d "$TMP/no-marker" ] || {
  echo "FAIL: unmarked tree was removed" >&2
  exit 1
}

cat > "$TMP/bin/ip" <<'EOS'
#!/bin/sh
echo "ip $*" >> "$MOCK_LOG"
exit 0
EOS

cat > "$TMP/bin/rmmod" <<'EOS'
#!/bin/sh
echo "rmmod $*" >> "$MOCK_LOG"
exit 0
EOS

cat > "$TMP/install/usb0-route-monitor.sh" <<'EOS'
#!/bin/sh
trap '' TERM
while :; do
  sleep 1
done
EOS

cat > "$TMP/bin/udhcpc" <<'EOS'
#!/bin/sh
trap '' TERM
while :; do
  sleep 1
done
EOS

cat > "$TMP/install/usb0-udhcpc-script.sh" <<'EOS'
#!/bin/sh
echo "usb0-udhcpc-script $*" >> "$MOCK_LOG"
exit 0
EOS

chmod 755 \
  "$TMP/bin/ip" \
  "$TMP/bin/rmmod" \
  "$TMP/bin/udhcpc" \
  "$TMP/install/usb0-route-monitor.sh" \
  "$TMP/install/usb0-udhcpc-script.sh"

mkdir -p "$TMP/install/state"
: > "$TMP/mock.log"

"$TMP/install/usb0-route-monitor.sh" &
MONITOR_PID="$!"
echo "$MONITOR_PID" > "$TMP/install/state/usb0-monitor.pid"

PATH="$TMP/bin:$PATH" \
  "$TMP/bin/udhcpc" \
    -i usb0 \
    -f \
    -t 3 \
    -T 4 \
    -p "$TMP/install/state/udhcpc-usb0.pid" \
    -s "$TMP/install/usb0-udhcpc-script.sh" &
DHCP_PID="$!"

echo "$DHCP_PID" > "$TMP/install/state/udhcpc-usb0.pid"

sleep 1
kill -0 "$MONITOR_PID"
kill -0 "$DHCP_PID"

PATH="$TMP/bin:$PATH" \
MOCK_LOG="$TMP/mock.log" \
PACKAGE_DIR="$TMP/install" \
BOOT_HOOK="$TMP/init.d/S46usb_ethernet_primary" \
STOP_TIMEOUT=1 \
KILL_TIMEOUT=1 \
  "$SH" "$TMP/install/uninstall-usb-ethernet.sh" \
    --yes > "$TMP/uninstall.out"

wait "$MONITOR_PID" >/dev/null 2>&1 || true
wait "$DHCP_PID" >/dev/null 2>&1 || true
MONITOR_PID=""
DHCP_PID=""

[ ! -d "$TMP/install" ] || {
  echo "FAIL: marked install tree was not removed" >&2
  exit 1
}

[ ! -e "$TMP/init.d/S46usb_ethernet_primary" ] || {
  echo "FAIL: boot hook remained after uninstall" >&2
  exit 1
}

grep 'monitor force-stopped' "$TMP/uninstall.out" >/dev/null || {
  echo "FAIL: monitor TERM-to-KILL path was not exercised" >&2
  exit 1
}

grep 'udhcpc force-stopped' "$TMP/uninstall.out" >/dev/null || {
  echo "FAIL: DHCP TERM-to-KILL path was not exercised" >&2
  exit 1
}

grep 'Uninstall complete' "$TMP/uninstall.out" >/dev/null || {
  echo "FAIL: uninstall did not report completion" >&2
  exit 1
}

echo "boot stop uninstall regression checks passed"
