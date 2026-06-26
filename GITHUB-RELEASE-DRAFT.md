# Draft GitHub Release: v1.0.0

Do not publish until maintainer approval and completion of the immutable draft
release procedure.

## Title

K1C USB Ethernet v1.0.0

## Summary

USB Ethernet support for the explicitly supported Creality K1C firmware/kernel
ABI using the tested ASIX `0b95:1790` adapter in CDC-NCM mode.

Current verdict:

`GO -- automated and physical qualification complete.`

The corrected runtime provides USB-primary routing with metric `50`, preserves
Wi-Fi fallback with metric `300`, repairs firmware-recreated route drift,
recovers from physical USB recreation, and performs verified uninstall cleanup.

## Qualified Candidate

- Uninstall source fix:
  `25ec035f53ceb778c40da90069190bdadca17faf`
- Physically tested rebuilt candidate:
  `0e188c2`
- Tested TAR SHA-256:
  `523d51dfa4ff159abeb977f2349584a7417e5a151507bd974418395992b731a9`
- Tested ZIP SHA-256:
  `81ed343420812342183bceba5492f13bc34a1cae6090614c761e9ff32cbea502`

The final release archives are rebuilt after qualification-document updates.
That rebuild changes documentation and archive hashes only; the qualified
`package/` runtime payload remains unchanged.

## Assets To Attach

- `k1c-usb-ethernet-v1.0.0.tar.gz`
- `k1c-usb-ethernet-v1.0.0.zip`
- `SHA256SUMS`

## Compatibility

- Creality K1C only
- Kernel `4.4.94`
- ABI/vermagic `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- ASIX `0b95:1790` adapter tested

## Qualification Highlights

- production modules and embedded package checksums verified;
- unattended boot integration passed;
- exact USB-primary and Wi-Fi-fallback routes verified;
- three physical USB removal/reconnect cycles passed;
- Ethernet-cable-only fallback and recovery passed;
- one monitor and one USB DHCP process maintained;
- corrected uninstall removed the hook, runtime directory, processes, modules,
  interface, and USB routes;
- Wi-Fi connectivity remained available after uninstall.

## Historical Warning Disclosure

A bounded `EVENT_RX_MEMORY` warning burst was observed during development.

It did not recur during the final instrumented diagnostic transfer, which
recorded zero RX skb allocation failures, zero RX URB `-ENOMEM` returns, zero
other RX submission errors, zero `netif_rx()` failures, and zero softnet backlog
drops.

See `RELEASE-QUALIFICATION.md` for the complete qualification record.

## Publication Control

Enable GitHub release immutability before publication. Create the release as a
draft, attach all final assets, verify the release and assets, and only then
publish the draft.
