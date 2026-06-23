#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ -d "$ROOT/.git" ]; then
  git -C "$ROOT" fsck --full --strict
fi
echo "git object scan=pass"

