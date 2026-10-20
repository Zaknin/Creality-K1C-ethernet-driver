# v1.0.4 published asset verification

The published GitHub Release v1.0.4 contains exactly four downloadable
assets: runtime TAR, runtime ZIP, source TAR, and SHA256SUMS.

GitHub Actions independently downloaded all four public assets, verified
the three SHA-256 checksums, and matched the exact prepublication
acceptance checksums. This is a publication/asset integrity check,
not an additional physical hardware test.
