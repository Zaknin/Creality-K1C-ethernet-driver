#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
README=$ROOT/README.md

first_line=$(sed -n '1p' "$README")
[ "$first_line" = "# Creality K1C USB Ethernet Driver" ] || {
  echo "README title mismatch: $first_line"
  exit 1
}

bad_unpublished="unpublished"
bad_internal="internal"
bad_draft="draft"
if grep -qi "This $bad_unpublished project\\|$bad_unpublished project\\|$bad_unpublished repository\\|$bad_internal project\\|$bad_draft project" "$README"; then
  echo "README contains non-public project wording"
  exit 1
fi

python3 - "$README" <<'PY'
import pathlib
import sys

readme = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    "## Latest ready-to-install release: v1.0.3",
    "releases/tag/v1.0.3",
    "This branch is the older v0.1.1",
    "docs/LATEST-RUNTIME.md",
    "drop_l2_8899",
    "rx_ipv4_only",
    "The 2025 K1C revision",
    "unofficial community project",
]
for text in required:
    if text not in readme:
        raise SystemExit(f"missing required README text: {text!r}")
print("public docs=pass")
PY
