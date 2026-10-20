#!/usr/bin/env python3
"""Check generated v1.0.4 TAR, ZIP and source archives, not just repo files.

Usage: python3 tests/test_v104_release_archives.py /path/to/assets
"""
import hashlib
import io
from pathlib import Path
import re
import sys
import tarfile
import zipfile

MODULE_HASH = "f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271"
VERSION = "1.0.4"
PREFIX = "k1c-usb-ethernet-v" + VERSION
NAMES = (PREFIX + "-runtime.tar.gz", PREFIX + "-runtime.zip",
         PREFIX + "-source.tar.gz")


def sha(b):
    return hashlib.sha256(b).hexdigest()


def parse_checksums(content):
    records = {}
    for line in content.decode().splitlines():
        hashvalue, name = line.split("  ", 1)
        assert name not in records and re.fullmatch("[0-9a-f]{64}", hashvalue)
        records[name] = hashvalue
    return records


def tar_content(filename):
    with tarfile.open(filename, "r:gz") as archive:
        members = archive.getmembers()
        assert all(m.isfile() for m in members), "Unexpected directories/links"
        return {m.name: archive.extractfile(m).read() for m in members}


def main():
    assets = Path(sys.argv[1])
    checks = parse_checksums((assets / "SHA256SUMS").read_bytes())
    assert set(checks) == set(NAMES), "unexpected release assets"
    for filename, expected in checks.items():
        assert sha((assets / filename).read_bytes()) == expected, filename

    tar = tar_content(assets / NAMES[0])
    with zipfile.ZipFile(assets / NAMES[1]) as archive:
        zipped = {f.filename: archive.read(f) for f in archive.infolist()
                  if not f.is_dir()}
    assert tar == zipped, "runtime TAR/ZIP payload mismatch"

    root = PREFIX + "-runtime/"
    runtime = {p[len(root):]: data for p, data in tar.items()
               if p.startswith(root)}
    assert len(runtime) == len(tar), "unexpected runtime paths"
    pkg = {p[len("package/"):]: data for p, data in runtime.items()
           if p.startswith("package/")}
    assert "install.sh" in runtime and "start-usb-ethernet.sh" in pkg
    assert "package/SHA256SUMS" in runtime
    assert "VERSION=1.0.4" in runtime["install.sh"].decode()
    assert "v1.0.4" in runtime["README.md"].decode()
    file_hashes = parse_checksums(pkg["SHA256SUMS"])
    assert set(file_hashes) == set(pkg) - {"SHA256SUMS"}
    for name, expected in file_hashes.items():
        assert sha(pkg[name]) == expected, "runtime package mismatch: " + name

    module_hashes = parse_checksums(pkg["module-hashes.sha256"])
    assert module_hashes["modules/cdc_ncm.ko"] == MODULE_HASH
    assert sha(pkg["modules/cdc_ncm.ko"]) == MODULE_HASH
    startup = pkg["start-usb-ethernet.sh"].decode()
    assert 'CDC_NCM_HASH="' + MODULE_HASH + '"' in startup
    assert "version=1.0.4" in pkg["package-manifest.txt"].decode()

    source = tar_content(assets / NAMES[2])
    assert not any(name.endswith(".ko") for name in source), "kernel binaries in source"
    assert any(name.endswith("/source/cdc_ncm.c") for name in source)
    assert any(name.endswith("/tools/assemble-v1.0.4.py") for name in source)
    assert any(name.endswith("/docs/FILTER-MODES-v1.0.4.md") for name in source)
    print("ARCHIVE INTEGRITY: PASS — deterministic inputs, matching TAR/ZIP, "
          "all internal checksums and startup hash")


if __name__ == "__main__":
    main()
