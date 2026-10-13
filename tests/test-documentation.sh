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
    "docs/LATEST-RUNTIME.md",
    "docs/ISSUE-1-FIELD-TEST.md",
]

for rel in host_scripts + runtime_scripts + docs:
    if not (root / rel).is_file():
        raise SystemExit(f"referenced path missing: {rel}")

for rel in host_scripts:
    subprocess.run(["sh", str(root / rel), "--help"], check=True, stdout=subprocess.DEVNULL)

readme = (root / "README.md").read_text(encoding="utf-8")
legacy_docs = "\n".join((root / d).read_text(encoding="utf-8") for d in docs
                        if d not in ("docs/LATEST-RUNTIME.md",
                                     "docs/ISSUE-1-FIELD-TEST.md"))

# The legacy build-tools branch still needs its entire documented workflow,
# but the root README is now the current prebuilt runtime landing page.
for rel in host_scripts:
    if rel not in legacy_docs:
        raise SystemExit(f"legacy build-tools docs omit {rel}")

required_readme = [
    "v1.0.3",
    "releases/tag/v1.0.3",
    "docs/LATEST-RUNTIME.md",
    "drop_l2_8899",
    "rx_ipv4_only",
    "v0.1.1",
    "not",
    "2023-generation",
    "4.4.94",
]
for text in required_readme:
    if text not in readme:
        raise SystemExit(f"README missing current release text: {text}")

current_guide = (root / "docs/LATEST-RUNTIME.md").read_text(encoding="utf-8")
for text in (
    "k1c-usb-ethernet-v1.0.3-runtime.tar.gz",
    "stop-primary-ethernet.sh",
    "uninstall-usb-ethernet.sh",
    "drop_l2_8899",
    "rx_ipv4_only",
    "Wi-Fi",
    "rx_errors",
):
    if text not in current_guide:
        raise SystemExit(f"latest runtime guide missing {text}")

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

