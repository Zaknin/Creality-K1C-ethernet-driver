#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

MODULES_DIR=output/modules
OUT_DIR=output/package
usage() {
  cat <<'EOF'
Create the local printer upload package.

Usage:
  scripts/package-local-build.sh --modules-dir output/modules --out output/package

Options:
  --modules-dir DIR    Directory containing the three verified .ko files.
  --out DIR            Output directory. Default: output/package.

Output:
  output/package/k1c-usb-ethernet-local.tar.gz
  output/package/SHA256SUMS

Safety:
  Verifies modules first. The generated package is local output and should not
  be committed to Git.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --modules-dir) MODULES_DIR=${2:-}; shift 2 ;;
    --out) OUT_DIR=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

"$ROOT/scripts/verify-modules.sh" --modules-dir "$MODULES_DIR" --report-dir output/verify
work=package-work/local-package
rm -rf package-work
mkdir -p "$work/modules" "$work/runtime" "$OUT_DIR"

for module in $(expected_modules); do
  cp "$MODULES_DIR/$module" "$work/modules/$module"
done
cp "$ROOT/runtime/"*.sh "$work/runtime/"
cp "$ROOT/config/runtime.conf.example" "$work/runtime/config.conf.example"

cat >"$work/README.txt" <<'EOF'
This locally generated package is not distributed by the project.
It contains modules built by the local user from the user's own source/toolchain.
EOF

sha256sum "$work/modules"/mii.ko "$work/modules"/usbnet.ko "$work/modules"/cdc_ncm.ko >"$work/module-hashes.sha256"
find "$work" -type f | sort | sed "s#^$work/##" >"$work/package-manifest.txt"
reject_private_text "$work"

(cd "$work/.." && tar --sort=name --mtime='UTC 2024-01-01' --owner=0 --group=0 --numeric-owner -czf "$ROOT/$OUT_DIR/k1c-usb-ethernet-local.tar.gz" local-package)
sha256sum "$OUT_DIR/k1c-usb-ethernet-local.tar.gz" >"$OUT_DIR/SHA256SUMS"
note "local package written to $OUT_DIR/k1c-usb-ethernet-local.tar.gz"
