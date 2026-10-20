#!/bin/sh
set -eu

VERSION=1.0.4
EXPECTED_KERNEL=4.4.94
DEFAULT_INSTALL_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good
BOOT_HOOK="${BOOT_HOOK:-/etc/init.d/S46usb_ethernet_primary}"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"

usage() {
  cat <<EOF
Usage: sh install.sh [--enable-boot] [--dest DIR]

Installs the v$VERSION USB Ethernet runtime for the supported K1C ABI.
Without --enable-boot, boot integration is left unchanged. A successful
--enable-boot installation adds /etc/init.d/S46usb_ethernet_primary.
EOF
}

enable_boot=0
dest="$DEFAULT_INSTALL_DIR"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --enable-boot)
      enable_boot=1
      shift
      ;;
    --dest)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      dest="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "install: ERROR: $*" >&2
  exit 1
}

[ "$(uname -r)" = "$EXPECTED_KERNEL" ] ||
  fail "unsupported kernel $(uname -r), expected $EXPECTED_KERNEL"
[ -d "$PACKAGE_DIR" ] ||
  fail "missing package directory beside install.sh: $PACKAGE_DIR"
[ -f "$PACKAGE_DIR/module-hashes.sha256" ] ||
  fail "missing package/module-hashes.sha256"
( cd "$PACKAGE_DIR" && sha256sum -c module-hashes.sha256 ) ||
  fail "module hash verification failed"

# Never delete or overwrite a preexisting directory, including a
# markerless partial install, as part of automatic recovery.
case "$dest" in
  /*) ;;
  *) fail "installation destination must be an absolute path" ;;
esac
case "$dest" in
  /|*/.|*/..|*/../*|*/./*) fail "unsafe installation destination: $dest" ;;
esac
[ ! -e "$dest" ] && [ ! -L "$dest" ] ||
  fail "destination exists at $dest; preserve any logs, uninstall the old package or inspect an earlier partial install before retrying"

if [ "$enable_boot" -eq 1 ]; then
  [ "$dest" = "$DEFAULT_INSTALL_DIR" ] ||
    fail "--enable-boot requires default install path; the boot hook uses $DEFAULT_INSTALL_DIR"
  [ ! -e "$BOOT_HOOK" ] && [ ! -L "$BOOT_HOOK" ] ||
    fail "boot hook already exists at $BOOT_HOOK; refusing to replace it"
  [ -d "$(dirname "$BOOT_HOOK")" ] ||
    fail "boot directory not present: $(dirname "$BOOT_HOOK")"
fi

# On early failure, remove only resources created by this invocation.
# The boot hook is staged in its target filesystem before touching /usr/data.
boot_stage=""
boot_installed=0
created_dest=0
cleanup() {
  rc="$1"
  trap - 0
  if [ -n "$boot_stage" ]; then
    rm -f "$boot_stage" || :
  fi
  if [ "$rc" -ne 0 ]; then
    if [ "$boot_installed" -eq 1 ]; then
      rm -f "$BOOT_HOOK" || echo "install: WARN: failed to remove new boot hook $BOOT_HOOK" >&2
    fi
    if [ "$created_dest" -eq 1 ]; then
      rm -rf "$dest" || echo "install: WARN: failed to remove partial install $dest" >&2
    fi
  fi
  exit "$rc"
}
trap 'cleanup $?' 0
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "$enable_boot" -eq 1 ]; then
  boot_stage="$BOOT_HOOK.k1c-pending-$$"
  [ ! -e "$boot_stage" ] && [ ! -L "$boot_stage" ] ||
    fail "boot staging path already exists: $boot_stage"
  # Writing the actual hook (not a zero-byte probe) detects a full
  # overlay filesystem. Failure leaves the old installation untouched.
  cp "$PACKAGE_DIR/S46usb_ethernet_primary" "$boot_stage" ||
    fail "cannot stage boot hook in $(dirname "$BOOT_HOOK") (check overlay free space); no package was installed. Free overlay space safely or install without --enable-boot"
  chmod 755 "$boot_stage" ||
    fail "cannot set boot hook permissions on $boot_stage"
fi

mkdir -p "$dest" || fail "cannot create installation directory $dest"
created_dest=1
cp -R "$PACKAGE_DIR"/. "$dest"/ ||
  fail "cannot copy runtime package to $dest"
( cd "$dest" && sha256sum -c module-hashes.sha256 ) ||
  fail "installed module hash verification failed"
( cd "$dest" && sha256sum -c SHA256SUMS ) ||
  fail "installed package integrity verification failed"

chmod 755 \
  "$dest/primary-routing-lib.sh" \
  "$dest/start-usb-ethernet.sh" \
  "$dest/stop-usb-ethernet.sh" \
  "$dest/status-usb-ethernet.sh" \
  "$dest/uninstall-usb-ethernet.sh" \
  "$dest/start-primary-ethernet.sh" \
  "$dest/stop-primary-ethernet.sh" \
  "$dest/usb0-route-monitor.sh" \
  "$dest/usb0-udhcpc-script.sh" \
  "$dest/ethernet-failover-status.sh" \
  "$dest/disable-primary-ethernet-boot.sh" \
  "$dest/S46usb_ethernet_primary" ||
  fail "cannot set runtime script permissions"

if [ "$enable_boot" -eq 1 ]; then
  mv "$boot_stage" "$BOOT_HOOK" ||
    fail "cannot atomically install boot hook at $BOOT_HOOK"
  boot_stage=""
  boot_installed=1
fi

printf 'k1c-usb-ethernet v%s package-owned install tree\n' "$VERSION" > "$dest/.package-owned" ||
  fail "cannot finalize package marker"

trap - 0
if [ "$enable_boot" -eq 1 ]; then
  echo "install: boot integration enabled at $BOOT_HOOK"
else
  echo "install: boot integration not enabled (manual start still supported)"
fi
echo "install: installed v$VERSION to $dest"
echo "install: run $dest/start-primary-ethernet.sh to start Ethernet-primary mode"
