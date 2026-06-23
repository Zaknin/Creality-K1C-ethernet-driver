# Uninstall

Run:

```sh
scripts/uninstall-from-printer.sh --host root@PRINTER_ADDRESS
```

The printer-side uninstall removes the USB Ethernet install directory and boot hook. It leaves unrelated network configuration untouched.

For local generated artifacts:

```sh
rm -rf output build package-work
```

Generated modules and packages are ignored by Git.

