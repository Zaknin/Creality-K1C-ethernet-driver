# Release Qualification

Version: 0.1.0

Status: prepared by local validation for public scripts-only release.

Commit: authoritative value is the local `v0.1.0` annotated tag target. The exact commit hash is not embedded in this file because a commit cannot contain its own final object ID.

Archive hashes: recorded in root `RELEASE-FILES.sha256` and `dist/SHA256SUMS`. The hash files are generated after archive creation to avoid self-referential archive contents.

This project ships no prebuilt kernel modules. Users supply their own vendor kernel source and MIPS toolchain.

Observed qualification checks:

- Shell syntax: pass.
- ShellCheck: pass with official `shellcheck-v0.10.0.linux.x86_64.tar.xz` temporary binary; computed asset SHA-256 `6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87`.
- no binary files: pass, excluding the intended release tar/zip archives.
- no SDK/source/toolchain/sysroot/firmware files: pass.
- privacy scan: pass.
- deterministic tar and zip archives: pass.
- tar/zip parity and no embedded `dist/`: pass.
- executable modes: pass in generated tar/zip archives.
- public tests: pass.
- Git object scan: pass.
- clean worktree: required after final commit and tag.

Known limitation: source compatibility is heuristic unless the user can prove that the source tree matches the printer.
