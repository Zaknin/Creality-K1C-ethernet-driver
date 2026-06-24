#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-boot-stop-test-$$"
SH="${SH:-/usr/bin/sh}"

cleanup() {
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
  PATH="$TMP/bin:$PATH" BOOT_HOOK="$TMP/init.d/S46usb_ethernet_primary" \
    "$SH" install.sh --enable-boot --dest "$TMP/install" > "$TMP/install.out"
)

[ -f "$TMP/install/.package-owned" ] || { echo "FAIL: install marker missing" >&2; exit 1; }
[ -x "$TMP/install/primary-routing-lib.sh" ] || { echo "FAIL: helper not executable after install" >&2; exit 1; }
[ -x "$TMP/install/usb0-route-monitor.sh" ] || { echo "FAIL: monitor not executable after install" >&2; exit 1; }
[ -x "$TMP/init.d/S46usb_ethernet_primary" ] || { echo "FAIL: boot hook not installed" >&2; exit 1; }
grep '^PACKAGE_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good$' "$TMP/init.d/S46usb_ethernet_primary" >/dev/null || {
  echo "FAIL: boot hook package path changed" >&2
  exit 1
}
grep 'start-primary-ethernet.sh' "$TMP/init.d/S46usb_ethernet_primary" >/dev/null || {
  echo "FAIL: boot hook does not call expected runtime path" >&2
  exit 1
}

mkdir -p "$TMP/no-marker"
cp "$ROOT/package/uninstall-usb-ethernet.sh" "$TMP/no-marker/"
cp "$ROOT/package/stop-usb-ethernet.sh" "$TMP/no-marker/"
if PACKAGE_DIR="$TMP/no-marker" "$SH" "$TMP/no-marker/uninstall-usb-ethernet.sh" --yes >/dev/null 2>&1; then
  echo "FAIL: uninstall succeeded without marker" >&2
  exit 1
fi
[ -d "$TMP/no-marker" ] || { echo "FAIL: unmarked tree was removed" >&2; exit 1; }

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
chmod 755 "$TMP/bin/ip" "$TMP/bin/rmmod"
: > "$TMP/mock.log"

PATH="$TMP/bin:$PATH" MOCK_LOG="$TMP/mock.log" PACKAGE_DIR="$TMP/install" \
  "$SH" "$TMP/install/uninstall-usb-ethernet.sh" --yes > "$TMP/uninstall.out"
[ ! -d "$TMP/install" ] || { echo "FAIL: marked install tree was not removed" >&2; exit 1; }

echo "boot stop uninstall regression checks passed"
