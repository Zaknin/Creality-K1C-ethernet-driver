#!/usr/bin/env python3
import argparse
import os
import re
import sys
from pathlib import Path

BINARY_SUFFIXES = {
    ".ko", ".o", ".a", ".so", ".elf", ".bin", ".img", ".fw", ".dtb", ".dts.o",
    ".bz2", ".xz", ".tgz", ".tbz2", ".zip",
}
PRIVATE_DIRS = {
    ".git", "vendor", "sdk", "toolchain", "sysroot", "kernel", "firmware",
    "private", "evidence", "downloads", "build", "output", "package-work",
}
GENERATED_DIRS = {"output"}
ARCHIVE_ALLOW = {
    Path("dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz"),
    Path("dist/creality-k1c-ethernet-driver-v0.1.1.zip"),
}
SOURCE_ARCHIVE = "ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2"
WIN_USER_PATH = "C:" + "\\\\" + "Users" + "\\\\"
PRIVATE_KEY_HEADER = "BEGIN " + r"(?:OPENSSH|RSA|DSA|EC)" + " " + "PRIVATE" + " " + "KEY"
CREDENTIAL_WORDS = ["pass" + "word", "pass" + "wd", "tok" + "en", r"api[_-]?key", "sec" + "ret"]
TEXT_PATTERNS = [
    ("windows_user_path", re.compile(re.escape(WIN_USER_PATH), re.IGNORECASE)),
    ("unix_home_path", re.compile(r"/(?:home|Users)/[A-Za-z0-9._-]+")),
    ("ssh_private_key", re.compile(PRIVATE_KEY_HEADER)),
    ("credential", re.compile(r"(?i)(" + "|".join(CREDENTIAL_WORDS) + r")\s*=")),
    ("raw_ipv4", re.compile(r"(?<![A-Za-z0-9_.-])(?:[1-9][0-9]{0,2}\.){3}[0-9]{1,3}(?![A-Za-z0-9_.-])")),
]


def is_binary(path: Path) -> bool:
    data = path.read_bytes()[:4096]
    return b"\0" in data


def rel(path: Path, root: Path) -> Path:
    return path.relative_to(root).as_posix()


def scan(root: Path) -> list[str]:
    errors: list[str] = []
    for path in sorted(root.rglob("*")):
        if path.is_dir():
            continue
        rp = path.relative_to(root)
        parts = set(rp.parts)
        if ".git" in parts:
            continue
        if rp.parts and rp.parts[0] in GENERATED_DIRS:
            continue
        if parts & (PRIVATE_DIRS - {"output"}):
            errors.append(f"private directory present: {rp.as_posix()}")
        if rp in ARCHIVE_ALLOW or rp.as_posix() in {"dist/SHA256SUMS", "RELEASE-FILES.sha256"}:
            continue
        if path.name == SOURCE_ARCHIVE:
            errors.append(f"forbidden vendor source archive: {rp.as_posix()}")
            continue
        if path.suffix in BINARY_SUFFIXES or path.name.endswith(".tar.gz"):
            errors.append(f"forbidden binary/module artifact: {rp.as_posix()}")
            continue
        if is_binary(path):
            errors.append(f"binary-looking file: {rp.as_posix()}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "\r\n" in text:
            errors.append(f"CRLF line endings: {rp.as_posix()}")
        for name, pattern in TEXT_PATTERNS:
            if rp.as_posix() in {"tools/scan-release.py", "scripts/lib.sh"} and name in {"windows_user_path", "unix_home_path"}:
                continue
            if pattern.search(text):
                errors.append(f"{name} in {rp.as_posix()}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    errors = scan(root)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("scan ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
