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

## Physical K1C results (2026-10-13)

**Status: candidate RX behavior validated on one real K1C; not yet
qualified for a stable release.**

Ubuntu `whisper-vulkan` built the branch using the prepared X2000
Linux 4.4.94 SDK; native RX regression passed and module verification
passed. Built `cdc_ncm.ko` SHA-256:

```text
1733b1f47fb90624b2253bcfd2cad96db7398397bdac1ded5692b23b0492c3d2
```

It loaded on the physical 2023 K1C with module size 17255
(original: 17148); `drop_l2_8899=Y`; Ethernet acquired
`192.0.2.12` with primary default route metric 50.

A/B test on the **same loaded module**, toggling only the runtime
parameter, each interval 25 seconds:

| Interval | Filter | RX packets delta | rx_dropped delta | rx_errors delta |
|---|---|---:|---:|---:|
| A1 | ON | 490 | **0** | 0 |
| B1 | OFF | 411 | **12** | 0 |
| A2 | ON | 415 | **1** | 0 |
| B2 | OFF | 488 | **32** | 0 |

Combined: **1 drop ON vs 44 drops OFF**, for equal total observation
time of 50 seconds each. These are descriptive results, not a
throughput or packet-loss benchmark.

A subsequent `ping -I usb0 -c 10 -W 2 192.0.2.14` passed
10/10 (0% ICMP packet loss), RTT min/avg/max
2.130/2.213/2.376 ms. The filter remained enabled (`Y`) and
link state was `UP,LOWER_UP` after the test. At this later
snapshot, absolute `rx_errors` was **1**, although each of the
four measured intervals had `+0` RX errors. The timing/cause of
the single error is unknown; check for continued growth before
calling it harmless.

The previous eight-minute watchdog run successfully rebooted the
printer back to stock (original module size 17148; IPv4 routes
restored). The second A/B run's scheduled reboot/rollback has
**not yet been independently confirmed**.

Next gate: verify the second watchdog rollback and monitor
`rx_errors` over a further non-printing observation window.
Neither the filter nor the separate notification patch is merged
into the stable v1.0.2 release.
