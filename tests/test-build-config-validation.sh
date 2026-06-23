#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if "$ROOT/scripts/check-environment.sh" --env "$ROOT/config/build.env.example" >/tmp/k1c-check-env.out 2>&1; then
  echo "example env unexpectedly passed without user source/toolchain"
  exit 1
fi
grep -E 'KERNEL_DIR|cross compiler|does not exist|required' /tmp/k1c-check-env.out >/dev/null

mkdir -p "$tmp/kernel"
cat >"$tmp/build.env" <<EOF
ARCH=mips
KERNEL_RELEASE=4.4.94
KERNEL_DIR=$tmp/kernel
CROSS_COMPILE=/missing/mips-linux-gnu-
EOF
if "$ROOT/scripts/check-environment.sh" --env "$tmp/build.env" >/tmp/k1c-check-env-2.out 2>&1; then
  echo "invalid env unexpectedly passed"
  exit 1
fi
grep -E 'missing required command|cross compiler|KERNEL_DIR|does not exist|required' /tmp/k1c-check-env-2.out >/dev/null
echo "build config validation=pass"
