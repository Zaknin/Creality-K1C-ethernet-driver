# K1C USB Ethernet v1.0.4 — release notes

**Unofficial prebuilt USB Ethernet runtime** for the 2023-generation Creality K1C running Linux `4.4.94`, MIPS32_R2, with tested ASIX CDC-NCM USB ID `0b95:1790`. No compatibility claim is made for 2025 K1C or other adapters/kernel ABIs.

## Fixes

- Correct the hardcoded `cdc_ncm.ko` SHA-256 in the runtime start script. v1.0.3 included the correct module but used a stale v1.0.2 pin, causing `hash mismatch` on startup.
- Stage the full boot hook in its target filesystem before changing the installed runtime. On full `/overlay`, fail early without leaving a new partial package.
- Refuse to overwrite an existing installation or unrelated boot hook; clean up files created by an unsuccessful installer invocation.
- Support manual installation without boot integration when adding a new hook is impossible.
- Add unit/integration simulations, exact hardcoded-hash verification, package/archive integrity checks, deterministic TAR/ZIP/source archive generation and source-release privacy checks.

## Unchanged kernel modules

The MIPS kernel binaries remain byte-identical to the earlier tested release. The `cdc_ncm.ko` SHA-256 is:

```text
f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271
```

Filter defaults remain `drop_l2_8899=Y` and `rx_ipv4_only=N`. With both interfaces healthy, the runtime uses USB Ethernet as primary (metric 50) and Wi-Fi as fallback (metric 300).

## Validation

On one supported physical printer, a guarded upgrade, reboot autostart, module hash/parameters, USB DHCP, Ethernet link-loss fallback and link-restoration recovery all passed. A post-recovery USB gateway ping returned 20/20 replies with zero lost. See [the hardware acceptance record](HARDWARE-ACCEPTANCE-v1.0.4.md) for details and limitations.

The release candidate's automated installer/integrity/RX tests and deterministic assembly have passed. Final publication requires the same checks on the exact final commit and all four exact release assets.

## Important limits

- A full `/overlay` still prevents **new boot-hook installation**; manual startup does not configure automatic boot.
- This is not an in-place upgrade. Back up, stop and uninstall the existing package-owned runtime before installing.
- A clean first installation, physical ENOSPC injection and deliberate failure-path boot-guard rollback were **not** proven on the physical printer.
- The optional strict RX allowlist can discard IPv6, LLDP, EAPOL and PPPoE traffic; sysfs toggles reset on reboot or module reload.
- The independent duplicate connection/speed-message issue #1 is not fixed.

## Assets (when released)

- `k1c-usb-ethernet-v1.0.4-runtime.tar.gz`
- `k1c-usb-ethernet-v1.0.4-runtime.zip`
- `k1c-usb-ethernet-v1.0.4-source.tar.gz`
- `SHA256SUMS`

Verify the chosen archive against the `SHA256SUMS` distributed in the same release. These names are a release plan, not evidence of publication.
