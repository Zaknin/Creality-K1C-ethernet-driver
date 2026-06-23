#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
PACKAGE=
REMOTE_DIR=/tmp/k1c-usb-ethernet-local-stage
usage() {
  cat <<'EOF'
Upload the local package to the printer over SSH.

Usage:
  scripts/deploy-to-printer.sh --host "$PRINTER_HOST" --package output/package/k1c-usb-ethernet-local.tar.gz

Options:
  --host HOST        SSH target, for example root@PRINTER_IP.
  --package FILE     Local package created by package-local-build.sh.
  --remote-dir DIR   Remote staging directory. Default: /tmp/k1c-usb-ethernet-local-stage.

Safety:
  Uploads and verifies the package checksum only. It does not install anything
  and does not enable boot startup.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    --package) PACKAGE=${2:-}; shift 2 ;;
    --remote-dir) REMOTE_DIR=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_host_arg "$HOST"
[ -f "$PACKAGE" ] || die "package not found: $PACKAGE"
need_cmd ssh
need_cmd scp

sum=$(sha256sum "$PACKAGE" | awk '{print $1}')
# shellcheck disable=SC2029
ssh "$HOST" "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR'"
scp "$PACKAGE" "$HOST:$REMOTE_DIR/package.tar.gz"
# shellcheck disable=SC2029
remote_sum=$(ssh "$HOST" "sha256sum '$REMOTE_DIR/package.tar.gz' | awk '{print \$1}'")
[ "$sum" = "$remote_sum" ] || die "remote checksum mismatch"
note "deployed to $HOST:$REMOTE_DIR/package.tar.gz"
