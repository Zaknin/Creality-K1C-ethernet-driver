#!/usr/bin/env python3
import gzip
import hashlib
import io
import os
import tarfile
import zipfile
from pathlib import Path

PROJECT = "creality-k1c-ethernet-driver"
VERSION = (Path(__file__).resolve().parents[1] / "VERSION").read_text(encoding="utf-8").strip()
PREFIX = f"{PROJECT}-v{VERSION}"
EPOCH = 1704067200
ZIP_DT = (2024, 1, 1, 0, 0, 0)
EXCLUDE_DIRS = {
    ".git",
    ".github",
    "dist",
    "output",
    "build",
    "package-work",
    "downloads",
    "vendor",
    "sdk",
    "toolchain",
    "kernel",
    "sysroot",
    "firmware",
    "private",
    "evidence",
}
EXCLUDE_FILES = {"RELEASE-FILES.sha256"}


def project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def files(root: Path) -> list[Path]:
    out = []
    for path in root.rglob("*"):
        rel = path.relative_to(root)
        if path.is_dir():
            continue
        if any(part in EXCLUDE_DIRS for part in rel.parts):
            continue
        if path.name in EXCLUDE_FILES:
            continue
        out.append(rel)
    return sorted(out, key=lambda p: p.as_posix())


def mode_for(rel: Path) -> int:
    if rel.parts and rel.parts[0] in {"scripts", "runtime", "tests", "tools"} and rel.suffix in {".sh", ".py"}:
        return 0o755
    return 0o644


def make_tar(root: Path, rels: list[Path], out: Path) -> None:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tf:
        for rel in rels:
            data = (root / rel).read_bytes()
            info = tarfile.TarInfo(f"{PREFIX}/{rel.as_posix()}")
            info.size = len(data)
            info.mtime = EPOCH
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            info.mode = mode_for(rel)
            tf.addfile(info, io.BytesIO(data))
    with out.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=EPOCH) as gz:
            gz.write(buf.getvalue())


def make_zip(root: Path, rels: list[Path], out: Path) -> None:
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for rel in rels:
            zi = zipfile.ZipInfo(f"{PREFIX}/{rel.as_posix()}", ZIP_DT)
            zi.external_attr = (mode_for(rel) & 0xFFFF) << 16
            zf.writestr(zi, (root / rel).read_bytes(), compress_type=zipfile.ZIP_DEFLATED)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    root = project_root()
    dist = root / "dist"
    dist.mkdir(exist_ok=True)
    rels = files(root)
    tar_path = dist / f"{PREFIX}.tar.gz"
    zip_path = dist / f"{PREFIX}.zip"
    make_tar(root, rels, tar_path)
    make_zip(root, rels, zip_path)
    lines = [
        f"{sha256(tar_path)}  {tar_path.name}",
        f"{sha256(zip_path)}  {zip_path.name}",
    ]
    (dist / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    (root / "RELEASE-FILES.sha256").write_text(
        "\n".join(f"{sha256(dist / name)}  dist/{name}" for name in [tar_path.name, zip_path.name]) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
