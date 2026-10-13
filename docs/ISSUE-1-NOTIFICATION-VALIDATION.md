# Issue #1 — CDC-NCM notification spam: validation plan

**Status:** source-level candidate; **NOT** a released or qualified K1C runtime.

## Reproduction

Report: https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues/1

- K1C 2023, kernel 4.4.94
- UGREEN CM209, ASIX AX88179B (0b95:1790, bcdDevice 2.00), USB configuration 2, CDC-NCM
- v1.0.2: connected/1000 Mbit notifications repeated ~128 ms apart, carrier always 1
- rx_dropped grows slowly; no ICMP packet loss observed by reporter

## Candidate

Source branch: `fix/issue-1-cdc-ncm-notification-spam`, based on frozen tag `v1.0.2`.

Changes only to `source/cdc_ncm.c`:
- Ignore unchanged carrier notifications before logging and scheduling link-change work.
- Cache last RX/TX speed per instance using the vendor usbnet `data[1..3]` scratch
  slots (verified unused in the project's standalone `cdc_ncm.c` and `usbnet.c`).
- Log speed only on the first notification or actual change; rearm after a genuine disconnect.
- No changes to the vendor kernel `usbnet.h` struct layout or to `usbnet.c`.

Background: Linux upstream commit `de658a195ee2` addresses a similar notification flood.
The vendor-tree adaptation also gates the connection **log** itself (not just
`usbnet_link_change()`), because the old K1C source still logs the event unconditionally.

## Gates

1. **Host-native logic regression:** `python3 tests/test_cdc_ncm_notifications.py`.
   Compiles the actual `cdc_ncm_speed_change` and `cdc_ncm_status` functions
   with test-only USB stubs. Must PASS in CI.
2. **MIPS kernel module:** Build fresh `cdc_ncm.ko` against the exact prepared
   K1C Linux 4.4.94 kernel tree using the original Ingenic-compatible toolchain.
   Verify target ELF, vermagic, symbol compatibility and clean build log.
   The old v1.0.2 `package/modules/cdc_ncm.ko` is *unchanged* by source edits.
3. **Physical printer:** Keep Wi-Fi SSH available as independent recovery.
   Deploy only a complete verified candidate with the project's approved
   installer/rollback procedure, in a maintenance window. Do not overwrite the
   v1.0.2 release or try to insert a second `cdc_ncm.ko` over the loaded module.
4. **Steady-state:** `usb0` remains UP, `carrier=1`, expected DHCP/default
   route metrics 50/300; no repeating connected/speed pair during a 2-minute
   capture; sustained ICMP + printing connectivity remains at least baseline.
5. **Real transitions:** One connected/disconnected log per actual transition,
   correct carrier and route failover/recovery, and speed reported after
   reconnection. Test both normal cable/link events and power-cycle/USB rebind.
6. **RX drops:** Record `rx_dropped`, `rx_errors`, `rx_packets`, `rx_bytes`
   and `/proc/net/softnet_stat` over matched quiet/load windows both before
   and after the candidate. Treat any change as diagnostic evidence; do not
   claim the packet-drop counter is fixed from notification suppression alone.

## Non-invasive sampling on K1C (BusyBox shell)

```sh
date -u
uname -r
for key in carrier rx_packets rx_bytes rx_errors rx_dropped tx_packets tx_errors; do
    case "$key" in carrier) p="/sys/class/net/usb0/carrier" ;;
        *) p="/sys/class/net/usb0/statistics/$key" ;;
    esac
    printf '%-14s ' "$key"
    cat "$p"
done
echo '--- softnet ---'
cat /proc/net/softnet_stat
echo '--- latest CDC-NCM logs ---'
dmesg | grep 'cdc_ncm' | tail -n 25
```

Repeat after 120 seconds under the same network load. This is read-only and
does not clear syslog/dmesg, reload modules, change routes or reset counters.

## Publication policy

Keep source candidate isolated from v1.0.2. Do not publish an installable
runtime or acceptance evidence as PASS until physical gates finish.
Publish generated build and diagnostic evidence **regardless of PASS/FAIL**
through the project-native publisher to the canonical TrueNAS
Local workspace reference: [REDACTED_LOCAL_WORKSPACE].
with independent SHA-256 readback and `.sha256` sidecar last. Drive /Codex is
only a downstream mirror. CI logs by themselves are not canonical evidence.
