# RX drops from EtherType 0x8899 — experimental filter

Scope: CDC-NCM receive path only. Based on v1.0.2; this is **not**
the notification-spam patch and **not** a stable release.

## Evidence from 2023 K1C

The directly attached switch at 192.0.2.13 has
MAC `02:00:00:00:00:01`. The K1C's Ethernet capture saw broadcast
EtherType `0x8899` from that MAC at ~0.5 frames/second.

On the original driver, a 30s window produced +16 `rx_dropped`;
registering an AF_PACKET listener for only `0x8899` produced +1
while capturing 15 such frames. Other no-listener windows produced
+16 and +29 drops. RX errors, FIFO/CRC counters, and softnet drops
were zero.

This strongly indicates unsupported L2 traffic being counted as
drops on this particular network. It does not prove every RX drop
has the same cause, nor does it prove the original issue reporter's
network sends `0x8899`.

## Patch

- After CDC-NCM frame bounds checks, discard **only EtherType 0x8899**
  before allocating an skb or invoking `usbnet_skb_return()`.
- Quietly ignore the frame; no kernel log messages and no synthetic
  modification of `rx_dropped`.
- Include filtered frame bytes in NCM payload bookkeeping so
  `rx_overhead` retains its intended meaning.
- Leave IPv4, ARP, IPv6 and all other EtherTypes untouched.
- Runtime module parameter `drop_l2_8899` defaults to on in this
  **experimental** branch. It can be switched without reloading:

  ```sh
  cat /sys/module/cdc_ncm/parameters/drop_l2_8899
  echo 0 > /sys/module/cdc_ncm/parameters/drop_l2_8899
  echo 1 > /sys/module/cdc_ncm/parameters/drop_l2_8899
  ```

## Native regression (on Ubuntu build host)

```sh
python3 tests/test_cdc_ncm_8899_filter.py
```

This compiles **the RX function extracted from the current
`source/cdc_ncm.c`** against native stubs. It checks the 0x8899
filter on/off, near-match 0x8898, IPv4, ARP, IPv6, NTB payload
accounting, and minimum frame length. The test is not a substitute
for a MIPS cross-build or a printer test.

## Cross-build on the previously used Ubuntu K1C build VM

```sh
set -e
ROOT="$HOME/k1c-build"
SDK="$ROOT/sdk/ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125"
mkdir -p "$ROOT/rx8899"
cd "$ROOT/rx8899"
git clone --branch fix/rx-filter-ethertype-8899 --single-branch \
  https://github.com/Zaknin/Creality-K1C-ethernet-driver.git repo

cat > k1c-build.env <<EOF
ARCH=mips
KERNEL_RELEASE=4.4.94
KERNEL_DIR=$SDK/kernel/kernel-4.4.94
CROSS_COMPILE=$SDK/prebuilts/toolchains/mips-gcc720-glibc229/bin/mips-linux-gnu-
SOURCE_DIR=source
OUTPUT_DIR=output/modules
BUILD_LOG_DIR=output/logs
BUILD_WORK_DIR=output/build-work/source
EOF

cd repo
python3 tests/test_cdc_ncm_8899_filter.py
scripts/check-environment.sh --env ../k1c-build.env
scripts/build-modules.sh --env ../k1c-build.env
scripts/verify-modules.sh --modules-dir output/modules --kernel-release 4.4.94
modinfo -F vermagic output/modules/cdc_ncm.ko
sha256sum output/modules/cdc_ncm.ko
```

**Stop after the build.** Do not overwrite the installed modules
or modify the printer boot hook. Printer-side A/B testing should
be done with Wi-Fi SSH available, a separate watchdog, and a
known-good v1.0.2 rollback path.

For hardware verification, compare 30s intervals with
`drop_l2_8899=0`, then `1`, then `0`, then `1`;
read `/sys/class/net/usb0/statistics/rx_dropped`,
`rx_errors`, and link state after each.
No change to normal connectivity is expected, but must be tested.
