# Release Checklist

- Confirm version in `VERSION`.
- Confirm no prebuilt modules or binaries are present.
- Confirm no vendor SDK, source tree, sysroot, toolchain, firmware, credentials, private paths, private hostnames, or evidence logs are present.
- Run all tests from a clean clone.
- Build deterministic archives with `python3 tools/build-release-archives.py`.
- Re-run archive generation and confirm byte-identical hashes.
- Confirm tar/zip file lists and executable modes.
- Confirm Git has one root commit, a clean worktree, no remotes, and annotated tag `v0.1.0`.

