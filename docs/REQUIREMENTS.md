# Requirements

Host requirements:

- POSIX shell.
- `make`, `find`, `sed`, `awk`, `grep`, `sort`, `sha256sum`, `file`, `tar`, and `gzip`.
- Python 3 for release archive tooling and tests.
- A user-supplied MIPS Linux cross compiler, configured through a prefix such as `CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-`.
- A user-supplied, prepared kernel tree matching the printer ABI closely enough for loadable modules.

Build configuration defaults:

```sh
KERNEL_DIR=/path/to/extracted/kernel/tree
CROSS_COMPILE=/path/to/toolchain/bin/mips-linux-gnu-
ARCH=mips
KERNEL_RELEASE=4.4.94
```

Optional but recommended:

- `modinfo`
- `readelf`
- `shellcheck`
- `ssh`
- `scp`

The scripts do not download the Baidu archive, a kernel source tree, an SDK, a compiler, or a toolchain. They also do not silently prepare the kernel tree. If the tree lacks generated headers, `Module.symvers`, or module build support, `scripts/check-environment.sh` fails and reports the missing condition.
