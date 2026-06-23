#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

python3 - "$ROOT" <<'PY'
import os
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])

host_scripts = [
    "scripts/check-environment.sh",
    "scripts/inspect-kernel-tree.sh",
    "scripts/prepare-kernel.sh",
    "scripts/build-modules.sh",
    "scripts/verify-modules.sh",
    "scripts/package-local-build.sh",
    "scripts/deploy-to-printer.sh",
    "scripts/install-on-printer.sh",
    "scripts/test-connectivity.sh",
    "scripts/enable-boot.sh",
    "scripts/disable-boot.sh",
    "scripts/collect-diagnostics.sh",
    "scripts/uninstall-from-printer.sh",
]

runtime_scripts = [
    "runtime/start-usb-ethernet.sh",
    "runtime/start-primary-ethernet.sh",
    "runtime/status-usb-ethernet.sh",
    "runtime/stop-usb-ethernet.sh",
    "runtime/enable-boot.sh",
    "runtime/disable-boot.sh",
    "runtime/uninstall.sh",
]

docs = [
    "docs/SOURCE-ACQUISITION.md",
    "docs/BUILD.md",
    "docs/VERIFY.md",
    "docs/PACKAGE.md",
    "docs/INSTALL.md",
    "docs/CONFIGURATION.md",
    "docs/TROUBLESHOOTING.md",
    "docs/UNINSTALL.md",
]

for rel in host_scripts + runtime_scripts + docs:
    if not (root / rel).is_file():
        raise SystemExit(f"referenced path missing: {rel}")

for rel in host_scripts:
    subprocess.run(["sh", str(root / rel), "--help"], check=True, stdout=subprocess.DEVNULL)

readme = (root / "README.md").read_text(encoding="utf-8")
for rel in host_scripts:
    if rel not in readme:
        raise SystemExit(f"README does not mention {rel}")

required_readme = [
    "git clone https://github.com/Zaknin/Creality-K1C-ethernet-driver.git",
    "scripts/check-environment.sh --env ../k1c-build.env",
    "scripts/inspect-kernel-tree.sh --kernel-dir \"$KERNEL_DIR\"",
    "scripts/build-modules.sh --env ../k1c-build.env",
    "scripts/verify-modules.sh",
    "scripts/package-local-build.sh",
    "output/package/k1c-usb-ethernet-local.tar.gz",
    "scripts/deploy-to-printer.sh",
    "scripts/install-on-printer.sh --host \"$PRINTER_HOST\"",
    "/usr/data/k1c-usb-ethernet-local/runtime/",
    "scripts/test-connectivity.sh --host \"$PRINTER_HOST\"",
    "scripts/enable-boot.sh --host \"$PRINTER_HOST\"",
    "scripts/disable-boot.sh --host \"$PRINTER_HOST\"",
    "scripts/uninstall-from-printer.sh --host \"$PRINTER_HOST\"",
    "output/diagnostics/printer-diagnostics.txt",
    "mii.ko",
    "usbnet.ko",
    "cdc_ncm.ko",
]
for text in required_readme:
    if text not in readme:
        raise SystemExit(f"README missing workflow text: {text}")

bad_claims = [
    r"prebuilt modules are included",
    r"prebuilt kernel modules are included",
    r"official Creality",
    r"endorsed by Creality",
    r"supported by Creality",
]
for path in [root / "README.md"] + [root / d for d in docs]:
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        if len(line) > 600:
            raise SystemExit(f"very long Markdown line in {path.relative_to(root)}")
    lowered = text.lower()
    for claim in bad_claims:
        if re.search(claim, lowered):
            raise SystemExit(f"bad public claim in {path.relative_to(root)}: {claim}")

link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
for path in [root / "README.md"] + [root / d for d in docs]:
    for link in link_re.findall(path.read_text(encoding="utf-8")):
        if "://" in link or link.startswith("#") or link.startswith("mailto:"):
            continue
        target = link.split("#", 1)[0]
        if not target:
            continue
        target_path = (path.parent / target).resolve()
        try:
            target_path.relative_to(root.resolve())
        except ValueError as exc:
            raise SystemExit(f"Markdown link escapes repository: {path.relative_to(root)} -> {link}") from exc
        if not target_path.exists():
            raise SystemExit(f"broken Markdown link: {path.relative_to(root)} -> {link}")

print("documentation=pass")
PY

