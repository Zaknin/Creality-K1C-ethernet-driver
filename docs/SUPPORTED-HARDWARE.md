# Supported Hardware

Support is intentionally narrow.

- Tested only on a 2023-generation Creality K1C.
- Tested kernel: `4.4.94`.
- Module ABI/vermagic: `4.4.94 SMP preempt mod_unload MIPS32_R2 32BIT`.
- Tested ASIX USB adapter ID: `0b95:1790`.
- The 2025 K1C revision has not been tested.
- Compatibility with the 2025 revision is unknown and is not claimed.

Do not use this package on unrelated printers, unrelated firmware builds,
different kernels, or different module ABIs.

Before installing the runtime package, check the printer kernel:

```sh
ssh root@PRINTER_IP 'uname -r'
```

Expected:

```text
4.4.94
```

The installer refuses other kernel releases. That refusal is intentional.
