#!/usr/bin/env python3
"""Assemble v1.0.3 artifacts from the *physically tested* CDC-NCM binary.

This script creates unsigned local release candidates. It never publishes a
GitHub release, replaces printer files, or modifies the checked-out repository.

Usage:
  python3 tools/assemble-v1.0.3.py \
    --candidate /absolute/path/to/verified/cdc_ncm.ko \
    --out /absolute/path/to/v1.0.3-assets
"""
import argparse
import gzip
import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.0.3"
STAMP = 1704067200
ZIP_DATE = (2024, 1, 1, 0, 0, 0)
EXPECTED = {
    "mii.ko": "a66d280aa643319a848260e8ade6373415a61e1e07c73e16dacd33f75ac497d8",
    "usbnet.ko": "8a582cb3f480f86126dacc2b7255b45efcb4fb58d591007e6ba653bee08da85d",
    "cdc_ncm.ko": "f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271",
}


def sha256(p):
    h = hashlib.sha256()
    with Path(p).open("rb") as f:
        for b in iter(lambda: f.read(1048576), b""):
            h.update(b)
    return h.hexdigest()


def copy_path(src, dst):
    if src.is_dir():
        shutil.copytree(src, dst)
    else:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def edit_exact(path, old, new):
    content = path.read_text()
    if content.count(old) == 1:
        path.write_text(content.replace(old, new))
    elif content.count(new) != 1:
        raise RuntimeError("expected exactly one {!r} or {!r} in {}".format(
            old, new, path))


def manifest_hashes(pkg):
    module_lines = []
    for name in ("mii.ko", "usbnet.ko", "cdc_ncm.ko"):
        digest = sha256(pkg / "modules" / name)
        if digest != EXPECTED[name]:
            raise RuntimeError("module hash mismatch: {}: {}".format(name, digest))
        module_lines.append("{}  modules/{}".format(digest, name))
    (pkg / "module-hashes.sha256").write_text("\n".join(module_lines) + "\n")

    # Package SHA256SUMS excludes itself, and includes the changed manifest.
    entries = [
        f for f in pkg.rglob("*")
        if f.is_file() and f.name != "SHA256SUMS"
    ]
    rows = [
        "{}  {}".format(sha256(p), p.relative_to(pkg).as_posix())
        for p in sorted(entries)
    ]
    (pkg / "SHA256SUMS").write_text("\n".join(rows) + "\n")

    for line in rows:
        digest, relative = line.split("  ", 1)
        if sha256(pkg / relative) != digest:
            raise RuntimeError("package SHA256SUMS self-check failed")


def stage_runtime(work, candidate):
    root = work / "k1c-usb-ethernet-v{}-runtime".format(VERSION)
    root.mkdir()
    copy_path(ROOT / "package", root / "package")
    copy_path(ROOT / "install.sh", root / "install.sh")
    copy_path(ROOT / "COPYING", root / "COPYING")
    copy_path(ROOT / "LICENSE.md", root / "LICENSE.md")

    pkg = root / "package"
    shutil.copy2(candidate, pkg / "modules" / "cdc_ncm.ko")
    edit_exact(root / "install.sh", "VERSION=1.0.2", "VERSION=1.0.3")
    edit_exact(pkg / "package-manifest.txt", "version=1.0.2", "version=1.0.3")
    edit_exact(pkg / "package-manifest.txt",
               "module_cdc_ncm_sha256=6ff51a9ec99089245d0cad267ac83d312193bb6818f8cec6519c1983cbe8f2bc",
               "module_cdc_ncm_sha256=" + EXPECTED["cdc_ncm.ko"])
    edit_exact(pkg / "package-manifest.txt",
               "runtime_physical_qualification=PASS",
               "runtime_physical_qualification=RX_FILTER_HW_PASS_FULL_INSTALL_PENDING")
    edit_exact(pkg / "package-manifest.txt",
               "overall_release_verdict=GO_RUNTIME_AND_SOURCE_QUALIFICATION_COMPLETE",
               "overall_release_verdict=V1_0_3_CANDIDATE_ASSET_VERIFICATION_REQUIRED")
    pkg_manifest = pkg / "package-manifest.txt"
    with pkg_manifest.open("a") as out:
        existing = pkg_manifest.read_text()
        for line in (
            "rx_filter_drop_l2_8899_default=Y",
            "rx_filter_ipv4_only_default=N",
            "rx_filter_hardware_ab_validation=PASS_2026-10-13",
        ):
            if line not in existing.splitlines():
                out.write(line + "\n")
    pkg_readme = pkg / "README.md"
    pkg_readme.write_text(pkg_readme.read_text().replace("v1.0.1", "v1.0.3"))

    filter_guide = ROOT / "docs" / "FILTER-MODES-v1.0.3.md"
    if not filter_guide.is_file():
        raise RuntimeError("missing release filter mode guide")
    copy_path(filter_guide, root / "FILTER-MODES.md")
    (root / "README.md").write_text(
        "# K1C USB Ethernet v1.0.3 runtime\n\n"
        "Ready-to-install package for verified 2023 K1C Linux 4.4.94.\n"
        "Check the release SHA256SUMS before installing, and keep Wi-Fi enabled.\n\n"
        "Install: sh ./install.sh --enable-boot (only after stopping and\n"
        "uninstalling an existing package-owned version).\n\n"
        "Two RX options: drop_l2_8899=Y (default), rx_ipv4_only=N (default).\n"
        "See FILTER-MODES.md for live toggles and restrictions.\n"
    )
    manifest_hashes(pkg)
    return root


def stage_source(work):
    root = work / "k1c-usb-ethernet-v{}-source".format(VERSION)
    root.mkdir()
    for name in ("source", "scripts", "build-records", "tests", "docs", "tools"):
        copy_path(ROOT / name, root / name)
    for name in ("COPYING", "LICENSE.md", "README.md", "install.sh"):
        copy_path(ROOT / name, root / name)
    # Never ship binaries, local outputs, or printer-specific runtime payload.
    for p in list(root.rglob("*.ko")) + list(root.rglob("*.pyc")):
        p.unlink()
    for p in root.rglob("__pycache__"):
        if p.is_dir():
            shutil.rmtree(p)
    (root / "install.sh").unlink()  # source-only artifact
    (root / "README.md").write_text(
        "# K1C USB Ethernet v1.0.3 source\n\n"
        "Source corresponding to v1.0.3 runtime CDC-NCM filter binary.\n"
        "External compatible Ingenic K1C SDK/kernel/toolchain required.\n"
        "No prebuilt modules, firmware, SDK or sysroot in this archive.\n"
        "See docs/BUILD-FROM-SOURCE.md and docs/FILTER-MODES-v1.0.3.md.\n"
    )
    doc = root / "docs" / "BUILD-FROM-SOURCE.md"
    if doc.exists():
        doc.write_text(doc.read_text().replace("v1.0.2", "v1.0.3"))
    (root / "build-records" / "reference-module-hashes.sha256").write_text(
        "\n".join("{}  modules/{}".format(EXPECTED[n], n)
                  for n in ("mii.ko", "usbnet.ko", "cdc_ncm.ko")) + "\n"
    )
    return root


def all_files(root):
    return sorted((p for p in root.rglob("*") if p.is_file()),
                  key=lambda p: p.relative_to(root.parent).as_posix())


def unix_mode(path):
    suffix = path.suffix
    if suffix in (".sh", ".py") or path.name == "install.sh":
        return 0o755
    return 0o644


def write_tar(root, out):
    with out.open("wb") as stream:
        with gzip.GzipFile(fileobj=stream, mode="wb", filename="", mtime=STAMP) as gz:
            with tarfile.open(fileobj=gz, mode="w|") as tf:
                for p in all_files(root):
                    info = tarfile.TarInfo(p.relative_to(root.parent).as_posix())
                    info.size = p.stat().st_size
                    info.mtime = STAMP
                    info.uid = info.gid = 0
                    info.uname = info.gname = ""
                    info.mode = unix_mode(p)
                    with p.open("rb") as body:
                        tf.addfile(info, body)


def write_zip(root, out):
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9) as z:
        for p in all_files(root):
            info = zipfile.ZipInfo(p.relative_to(root.parent).as_posix(),
                                   ZIP_DATE)
            info.create_system = 3
            info.external_attr = unix_mode(p) << 16
            z.writestr(info, p.read_bytes(),
                        compress_type=zipfile.ZIP_DEFLATED)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    out = args.out.resolve()

    if not candidate.is_file() or sha256(candidate) != EXPECTED["cdc_ncm.ko"]:
        raise SystemExit("STOP: candidate is not the hardware-tested cdc_ncm.ko")

    source = (ROOT / "source" / "cdc_ncm.c").read_text()
    for token in ("drop_l2_8899", "rx_ipv4_only",
                  "cdc_ncm_should_drop_other_l2"):
        if token not in source:
            raise SystemExit("STOP: release source lacks required policy: " + token)

    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="k1c-v103-") as temp:
        work = Path(temp)
        runtime = stage_runtime(work, candidate)
        source_dir = stage_source(work)
        files = [
            (runtime, out / "k1c-usb-ethernet-v1.0.3-runtime.tar.gz", write_tar),
            (runtime, out / "k1c-usb-ethernet-v1.0.3-runtime.zip", write_zip),
            (source_dir, out / "k1c-usb-ethernet-v1.0.3-source.tar.gz", write_tar),
        ]
        for src, dest, fn in files:
            fn(src, dest)
        (out / "SHA256SUMS").write_text(
            "\n".join("{}  {}".format(sha256(dest), dest.name)
                      for _, dest, _ in files) + "\n"
        )
    for item in sorted(out.iterdir()):
        if item.is_file():
            print("{}  {}".format(sha256(item), item.name))
    print("CANDIDATE ASSETS PREPARED; NOT PUBLISHED.")


if __name__ == "__main__":
    main()
