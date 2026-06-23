# Source Acquisition

Users must supply their own legally obtained vendor kernel source and MIPS toolchain. This project intentionally provides no SDK download URL and no private source hash.

The target runtime observed for this toolset is a Linux `4.4.94` MIPS printer kernel family. That version string alone is not enough to prove compatibility. Kernel configuration, exported symbols, module layout, compiler ABI, endianness, and vendor patches can all affect loadability.

Use `scripts/inspect-kernel-tree.sh` to classify a candidate tree as:

- `LIKELY`: expected version markers and module source paths are present.
- `UNCONFIRMED`: some expected markers are missing; manual vendor provenance review is needed.
- `INCOMPATIBLE`: obvious architecture, version, or layout mismatch.

The script is a heuristic and does not claim exact source identity.

