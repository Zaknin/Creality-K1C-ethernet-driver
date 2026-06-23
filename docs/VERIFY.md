# Verify The Built Modules

Run verification on the Linux or WSL build machine after `scripts/build-modules.sh` succeeds.

```sh
scripts/verify-modules.sh \
  --modules-dir output/modules \
  --kernel-release 4.4.94
```

The module directory must contain exactly:

```text
output/modules/mii.ko
output/modules/usbnet.ko
output/modules/cdc_ncm.ko
```

Extra `.ko` files are rejected so the package does not accidentally include unrelated modules.

## Reports

Reports are written to `output/verify/`.

Expected files include:

```text
output/verify/mii.ko.file.txt
output/verify/usbnet.ko.file.txt
output/verify/cdc_ncm.ko.file.txt
output/verify/SHA256SUMS
output/verify/dependency-order.txt
```

If `modinfo` is installed, the script also writes:

```text
output/verify/mii.ko.modinfo.txt
output/verify/usbnet.ko.modinfo.txt
output/verify/cdc_ncm.ko.modinfo.txt
```

If `readelf` is installed, it writes:

```text
output/verify/mii.ko.readelf.txt
output/verify/usbnet.ko.readelf.txt
output/verify/cdc_ncm.ko.readelf.txt
```

## What The Checks Mean

`file`
: Confirms the module looks like an ELF/kernel module.

`modinfo`
: Reads kernel-module metadata such as license, dependencies, aliases, and `vermagic`.

`readelf -h`
: Shows ELF header details such as machine type and class.

`vermagic`
: Must include the expected kernel release. If it does not include `4.4.94`, rebuild with the correct tree and configuration.

`SHA256SUMS`
: Records hashes for the three built modules so you can compare them later.

Successful verification does not guarantee the modules will work at runtime. It means the files are shaped like kernel modules and match the checks this repository can perform before installing them.

If verification fails, read the report files and see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
