#!/usr/bin/env python3
"""Stage verified v1.0.3 assets into the Git release tree; does not publish."""
from pathlib import Path
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets"
EXTRACTED = ROOT / "verification/k1c-usb-ethernet-v1.0.3-runtime"
OLD = "6ff51a9ec99089245d0cad267ac83d312193bb6818f8cec6519c1983cbe8f2bc"
NEW = "f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271"
NAMES = [
    "k1c-usb-ethernet-v1.0.3-runtime.tar.gz",
    "k1c-usb-ethernet-v1.0.3-runtime.zip",
    "k1c-usb-ethernet-v1.0.3-source.tar.gz",
]


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def rewrite(name, old, new):
    p = ROOT / name
    text = p.read_text()
    if old in text:
        p.write_text(text.replace(old, new))


def main():
    expected = {}
    for line in (OUT / "SHA256SUMS").read_text().splitlines():
        digest, filename = line.split("  ", 1)
        expected[filename] = digest
    if set(expected) != set(NAMES):
        raise SystemExit("STOP: unexpected asset list")
    for name, digest in expected.items():
        if sha(OUT / name) != digest:
            raise SystemExit("STOP: invalid asset " + name)
    if sha(EXTRACTED / "package/modules/cdc_ncm.ko") != NEW:
        raise SystemExit("STOP: extracted package is NOT hardware-tested cdc_ncm")
    if sha(ROOT / "package/modules/cdc_ncm.ko") not in (OLD, NEW):
        raise SystemExit("STOP: unexpected tracked CDC-NCM binary")

    shutil.copytree(EXTRACTED / "package", ROOT / "package",
                    dirs_exist_ok=True)
    shutil.copy2(EXTRACTED / "install.sh", ROOT / "install.sh")
    (ROOT / "build-records/reference-module-hashes.sha256").write_text(
        (ROOT / "package/module-hashes.sha256").read_text()
    )
    for name in ("docs/INSTALL-PREBUILT.md",
                 "docs/VERIFY-RELEASE.md",
                 "docs/BUILD-FROM-SOURCE.md"):
        rewrite(name, "v1.0.2", "v1.0.3")

    history = ROOT / "docs/RELEASE-HISTORY.md"
    current = history.read_text()
    if "## v1.0.3" not in current:
        history.write_text(
            "# Release History\n\n"
            "## v1.0.3\n\n"
            "Adds two independently switchable CDC-NCM RX policies: "
            "0x8899 filtering ON by default, and opt-in strict IPv4-only "
            "allowlist OFF by default. The boot/DHCP/Wi-Fi scripts remain "
            "unchanged from v1.0.2. See FILTER-MODES-v1.0.3.md and "
            "HARDWARE-VALIDATION-2026-10-13.md.\n\n"
            + current.replace("# Release History\n\n", "", 1)
        )

    (ROOT / "README.md").write_text(
        "# Creality K1C USB Ethernet Driver v1.0.3\n\n"
        "Ready-to-install Ethernet for 2023-generation Creality K1C, "
        "Linux 4.4.94, with ASIX 0b95:1790 USB Ethernet.\n\n"
        "Two independent CDC-NCM RX parameters: drop_l2_8899=Y "
        "(default) and rx_ipv4_only=N (default). The strict mode "
        "is opt-in and can block IPv6, LLDP, EAPOL, PPPoE and other "
        "non-IPv4 Ethernet protocols. Parameter changes via sysfs "
        "reset on reboot.\n\n"
        "See docs/FILTER-MODES-v1.0.3.md for commands and "
        "docs/HARDWARE-VALIDATION-2026-10-13.md for device evidence.\n"
        "Issue #1 notification-spam patch is NOT included.\n"
    )
    (ROOT / "GITHUB-RELEASE-DRAFT.md").write_text(
        "# K1C USB Ethernet v1.0.3\n\n"
        "Two independently selectable CDC-NCM RX filter modes:\n\n"
        "- drop_l2_8899=Y by default: silently discard EtherType 0x8899.\n"
        "- rx_ipv4_only=N by default: optional strict IPv4/ARP/LLC/VLAN "
        "allowlist, dropping other Ethernet-II EtherTypes.\n\n"
        "The Linux 4.4.94 MIPS CDC-NCM module was tested on a "
        "2023-generation Creality K1C with ASIX 0b95:1790. "
        "Three modes were each tested twice over 25 seconds: "
        "RX drops 25 with both OFF, 16 with 0x8899-only, "
        "and zero with strict filtering. "
        "All 18 USB gateway pings passed; RX errors, FIFO and missed "
        "counters did not increase in measured windows. "
        "A watchdog reboot restored the stock module and routes. "
        "Traffic rates varied between windows; no speedup is claimed.\n\n"
        "The v1.0.2 boot DHCP and Wi-Fi fallback scripts are retained. "
        "Strict mode may suppress IPv6 and other L2 protocols. "
        "Sysfs changes are runtime-only and reset after reboot. "
        "The unrelated notification-spam patch is not included.\n\n"
        "Supported: 2023 K1C, kernel 4.4.94, ASIX 0b95:1790. "
        "2025 K1C is not qualified. "
        "Verify SHA256SUMS before installation, and keep Wi-Fi enabled "
        "during upgrade. An existing package-owned install must be "
        "stopped and uninstalled before installing v1.0.3.\n"
    )
    qualification = ROOT / "RELEASE-QUALIFICATION.md"
    current = qualification.read_text()
    if "## v1.0.3 hardware qualification" not in current:
        qualification.write_text(
            "# Release Qualification\n\n"
            "## v1.0.3 hardware qualification\n\n"
            "Candidate CDC-NCM SHA-256 " + NEW +
            ". Two A/B/C cycles, 18/18 USB pings, zero RX error "
            "counter increments and stock watchdog rollback PASS. "
            "Full v1.0.3 installer-upgrade qualification is still "
            "separate from this RX module validation. "
            "See docs/HARDWARE-VALIDATION-2026-10-13.md.\n\n"
            "---\n\n" + current
        )

    dist = ROOT / "dist"
    if dist.exists():
        shutil.rmtree(dist)
    dist.mkdir()
    for name in NAMES + ["SHA256SUMS"]:
        shutil.copy2(OUT / name, dist / name)
    (ROOT / "RELEASE-FILES.sha256").write_text(
        "".join("{}  dist/{}\n".format(sha(dist / name), name)
                for name in NAMES)
    )
    print("STAGED: tested package, version 1.0.3, docs and dist")
    print("Tracked cdc_ncm.ko SHA256:", sha(
        ROOT / "package/modules/cdc_ncm.ko"))
    print("NOT COMMITTED OR PUBLISHED")


if __name__ == "__main__":
    main()
