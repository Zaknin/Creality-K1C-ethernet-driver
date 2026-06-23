# Release Checklist

- Confirm version in `VERSION`.
- Confirm a root license file exists before creating a public release.
- Confirm no prebuilt modules or binaries are present.
- Confirm no vendor SDK, source tree, sysroot, toolchain, firmware, credentials, private paths, private hostnames, or evidence logs are present.
- Run all tests from a clean clone.
- Build deterministic archives with `python3 tools/build-release-archives.py`.
- Re-run archive generation and confirm byte-identical hashes.
- Confirm tar/zip file lists and executable modes.
- Confirm generated release files remain ignored and untracked.
- Confirm release archives do not include `.github/maintainers/`.
- Confirm the previous immutable release tag, release, and assets remain unchanged.
