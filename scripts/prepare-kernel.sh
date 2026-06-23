#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

cat <<'EOF'
This project does not prepare or fetch a kernel tree automatically.

Prepare your legally obtained vendor kernel tree outside this repository using
that vendor tree's documented commands, then re-run:

  scripts/check-environment.sh --env /path/to/build.env

This refusal is intentional: silent preparation can hide source identity,
configuration, and provenance problems.
EOF
exit 1

