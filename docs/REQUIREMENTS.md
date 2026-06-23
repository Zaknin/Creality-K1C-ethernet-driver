# Requirements

Host requirements:

- POSIX shell.
- `make`, `find`, `sed`, `awk`, `grep`, `sort`, `sha256sum`, `file`, `tar`, and `gzip`.
- Python 3 for release archive tooling and tests.
- A user-supplied MIPS Linux cross compiler.
- A user-supplied, prepared vendor kernel tree matching the printer kernel.

Optional but recommended:

- `modinfo`
- `readelf`
- `shellcheck`
- `ssh`
- `scp`

The scripts do not silently prepare the kernel tree. If the tree lacks generated headers, `Module.symvers`, or module build support, `scripts/check-environment.sh` fails and reports the missing condition.

