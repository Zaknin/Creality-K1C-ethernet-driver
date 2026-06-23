#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
README=$ROOT/README.md

first_line=$(sed -n '1p' "$README")
[ "$first_line" = "# Creality K1C Ethernet Driver" ] || {
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
    "This repository does not include prebuilt kernel modules, a vendor SDK,\n"
    "vendor kernel source, firmware, or a cross-toolchain.",
    "This is an unofficial community project and is not affiliated with,\n"
    "endorsed by, or supported by Creality.",
]
for text in required:
    if text not in readme:
        raise SystemExit(f"missing required README text: {text!r}")
print("public docs=pass")
PY
