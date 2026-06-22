# Draft GitHub Release: v1.0.0

Do not publish until maintainer approval.

## Title

K1C USB Ethernet v1.0.0

## Summary

Validated vendor-native USB Ethernet support for the explicitly supported
Creality K1C firmware/kernel ABI using ASIX `0b95:1790` in CDC-NCM mode.

Final verdict:

`GO -- qualified for public v1.0.0 on the explicitly supported K1C firmware/kernel ABI, with a documented historical non-blocking EVENT_RX_MEMORY warning.`

## Assets To Attach

- `k1c-usb-ethernet-v1.0.0.tar.gz`
- `k1c-usb-ethernet-v1.0.0.zip`
- `SHA256SUMS`

## Compatibility

- Creality K1C only
- Kernel `4.4.94`
- ABI/vermagic `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`
- ASIX `0b95:1790` adapter tested

## Notes

This release does not claim compatibility with unrelated printers, firmware,
kernels, or USB Ethernet adapters.

During development, a bounded `EVENT_RX_MEMORY` warning burst was observed.
The warning did not recur during the final instrumented diagnostic run, which
recorded zero RX skb allocation failures, zero RX URB `-ENOMEM` returns, zero
other RX submission errors, zero `netif_rx()` failures, and zero softnet backlog
drops.

See `RELEASE-QUALIFICATION.md` for the complete qualification record.
