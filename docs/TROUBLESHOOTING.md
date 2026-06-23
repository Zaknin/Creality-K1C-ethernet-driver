# Troubleshooting

If `check-environment.sh` fails:

- Confirm `KERNEL_DIR` points to the vendor kernel tree.
- Confirm `CROSS_COMPILE` is a MIPS cross-compiler prefix.
- Confirm the kernel tree has already been prepared by the user.
- Confirm `Module.symvers` exists when module symbol versioning is required.

If modules build but fail verification:

- Compare `vermagic` to the printer kernel release.
- Check compiler ABI, endianness, and module dependency output.
- Re-run `scripts/inspect-kernel-tree.sh` and treat `UNCONFIRMED` as a stop for release use.

If printer connectivity is lost after a manual test, use the physical console or the printer's known-good network path and run the disabled boot-hook removal step in `docs/UNINSTALL.md`.

