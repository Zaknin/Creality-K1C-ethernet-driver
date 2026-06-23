#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Explain kernel preparation boundaries.

Usage:
  scripts/prepare-kernel.sh

This script does not prepare or download a kernel tree. Prepare your compatible
K1C kernel tree outside this repository, then run:

  scripts/check-environment.sh --env ../k1c-build.env

Safety:
  The repository cannot safely guess vendor build configuration.
EOF
  exit 0
fi

cat <<'EOF'
This project does not prepare or fetch a kernel tree automatically.

Prepare your legally obtained vendor kernel tree outside this repository using
that vendor tree's documented commands, then re-run:

  scripts/check-environment.sh --env /path/to/build.env

This refusal is intentional: silent preparation can hide source identity,
configuration, and provenance problems.
EOF
exit 1
