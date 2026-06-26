#!/usr/bin/env python3
import gzip
import hashlib
import io
import tarfile
import zipfile
from pathlib import Path


VERSION = "1.0.1"
RUNTIME_PREFIX = f"k1c-usb-ethernet-v{VERSION}-runtime"
SOURCE_PREFIX = f"k1c-usb-ethernet-v{VERSION}-source"
EPOCH = 1704067200
ZIP_DT = (2024, 1, 1, 0, 0, 0)

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"

PACKAGE_HASH_FILES = [
    "README.md",
    "S46usb_ethernet_primary",
    "disable-primary-ethernet-boot.sh",
    "ethernet-failover-status.sh",
    "module-hashes.sha256",
    "modules/cdc_ncm.ko",
    "modules/mii.ko",
    "modules/usbnet.ko",
    "package-manifest.txt",
    "primary-routing-lib.sh",
    "start-primary-ethernet.sh",
    "start-usb-ethernet.sh",
    "status-usb-ethernet.sh",
    "stop-primary-ethernet.sh",
    "stop-usb-ethernet.sh",
    "uninstall-usb-ethernet.sh",
    "usb0-route-monitor.sh",
    "usb0-udhcpc-script.sh",
]

RUNTIME_FILES = [
    "README.md",
    "COPYING",
    "LICENSE.md",
    "install.sh",
    "docs/INSTALL-PREBUILT.md",
    "docs/SUPPORTED-HARDWARE.md",
    "docs/VERIFY-RELEASE.md",
    "docs/TROUBLESHOOTING.md",
    "docs/SOURCE-COMPLIANCE.md",
    "docs/RELEASE-HISTORY.md",
    "package/README.md",
    "package/SHA256SUMS",
    "package/module-hashes.sha256",
    "package/modules/mii.ko",
    "package/modules/usbnet.ko",
    "package/modules/cdc_ncm.ko",
    "package/package-manifest.txt",
    "package/primary-routing-lib.sh",
    "package/start-usb-ethernet.sh",
    "package/stop-usb-ethernet.sh",
    "package/status-usb-ethernet.sh",
    "package/start-primary-ethernet.sh",
    "package/stop-primary-ethernet.sh",
    "package/ethernet-failover-status.sh",
    "package/disable-primary-ethernet-boot.sh",
    "package/uninstall-usb-ethernet.sh",
    "package/S46usb_ethernet_primary",
    "package/usb0-route-monitor.sh",
    "package/usb0-udhcpc-script.sh",
]

SOURCE_FILES = [
    "README.md",
    "COPYING",
    "LICENSE.md",
    "docs/INSTALL-PREBUILT.md",
    "docs/BUILD-FROM-SOURCE.md",
    "docs/SOURCE-COMPLIANCE.md",
    "docs/SUPPORTED-HARDWARE.md",
    "docs/VERIFY-RELEASE.md",
    "docs/TROUBLESHOOTING.md",
    "docs/RELEASE-HISTORY.md",
    "source/mii.c",
    "source/usbnet.c",
    "source/cdc_ncm.c",
    "source/Makefile",
    "source/Module.symvers.known-good",
    "build-records/final.config",
    "build-records/config-gates.txt",
    "build-records/toolchain.txt",
    "build-records/source-provenance.txt",
    "build-records/reference-module-hashes.sha256",
    "scripts/lib.sh",
    "scripts/check-environment.sh",
    "scripts/build-modules.sh",
    "scripts/verify-modules.sh",
]

EXECUTABLES = {
    "install.sh",
    "package/S46usb_ethernet_primary",
    "package/disable-primary-ethernet-boot.sh",
    "package/ethernet-failover-status.sh",
    "package/start-primary-ethernet.sh",
    "package/start-usb-ethernet.sh",
    "package/status-usb-ethernet.sh",
    "package/stop-primary-ethernet.sh",
    "package/stop-usb-ethernet.sh",
    "package/uninstall-usb-ethernet.sh",
    "package/usb0-route-monitor.sh",
    "package/usb0-udhcpc-script.sh",
    "scripts/lib.sh",
    "scripts/check-environment.sh",
    "scripts/build-modules.sh",
    "scripts/verify-modules.sh",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def mode_for(rel: str) -> int:
    return 0o755 if rel in EXECUTABLES else 0o644


def write_package_hashes() -> None:
    lines = []
    for rel in PACKAGE_HASH_FILES:
        path = ROOT / "package" / rel
        if not path.is_file():
            raise FileNotFoundError(path)
        lines.append(f"{sha256(path)}  {rel}")
    (ROOT / "package" / "SHA256SUMS").write_text(
        "\n".join(lines) + "\n", encoding="utf-8", newline="\n"
    )


def add_tar_file(tf: tarfile.TarFile, prefix: str, rel: str) -> None:
    path = ROOT / rel
    if not path.is_file():
        raise FileNotFoundError(path)
    data = path.read_bytes()
    info = tarfile.TarInfo(f"{prefix}/{rel}")
    info.size = len(data)
    info.mtime = EPOCH
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mode = mode_for(rel)
    tf.addfile(info, io.BytesIO(data))


def make_tar(prefix: str, rels: list[str], out: Path) -> None:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tf:
        for rel in sorted(rels):
            add_tar_file(tf, prefix, rel)
    with out.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=EPOCH) as gz:
            gz.write(buf.getvalue())


def make_zip(prefix: str, rels: list[str], out: Path) -> None:
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for rel in sorted(rels):
            path = ROOT / rel
            if not path.is_file():
                raise FileNotFoundError(path)
            zi = zipfile.ZipInfo(f"{prefix}/{rel}", ZIP_DT)
            zi.external_attr = (mode_for(rel) & 0xFFFF) << 16
            zf.writestr(zi, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)


def main() -> int:
    DIST.mkdir(exist_ok=True)
    write_package_hashes()

    for old in DIST.glob("*"):
        if old.is_file():
            old.unlink()

    runtime_tar = DIST / f"{RUNTIME_PREFIX}.tar.gz"
    runtime_zip = DIST / f"{RUNTIME_PREFIX}.zip"
    source_tar = DIST / f"{SOURCE_PREFIX}.tar.gz"

    make_tar(RUNTIME_PREFIX, RUNTIME_FILES, runtime_tar)
    make_zip(RUNTIME_PREFIX, RUNTIME_FILES, runtime_zip)
    make_tar(SOURCE_PREFIX, SOURCE_FILES, source_tar)

    assets = [runtime_tar, runtime_zip, source_tar]
    lines = [f"{sha256(path)}  {path.name}" for path in assets]
    (DIST / "SHA256SUMS").write_text(
        "\n".join(lines) + "\n", encoding="utf-8", newline="\n"
    )
    (ROOT / "RELEASE-FILES.sha256").write_text(
        "\n".join(f"{sha256(path)}  dist/{path.name}" for path in assets) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
