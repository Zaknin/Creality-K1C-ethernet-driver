# Verify

Run:

```sh
scripts/verify-modules.sh --modules-dir output/modules --kernel-release 4.4.94
```

Verification records:

- SHA-256 hashes
- `file` output
- `modinfo` output when available
- `readelf -h` output when available
- license, vermagic, dependencies, and aliases where available
- expected dependency order: `mii`, `usbnet`, `cdc_ncm`

The verifier rejects missing modules, unexpected `.ko` files, bad architecture markers when visible, mismatched vermagic when visible, and private path fragments.

