# Issue #1 — AX88179B notification test build

**Test-only build. Not a v1.0.2 replacement or a stable release.**

This candidate suppresses repeated unchanged CDC-NCM connection/speed notifications.
It does **not** attempt to fix RX drops or USB receive errors.

The patch is based on the v1.0.2 source. It passed native notification
regression tests and hardware smoke tests on a 2023 K1C (Linux 4.4.94,
ASIX 0b95:1790 rev 0200, CDC-NCM config 2) at 100 and 1000 Mbps,
including physical Ethernet unplug/replug and Wi-Fi fallback. The original
notification flood did **not** reproduce on that unit even under v1.0.2;
the reporter's AX88179B is needed to confirm the fix.

## Before starting

- This procedure requires the **installed v1.0.2 package** at
  /usr/data/k1c-usb-ethernet/vendor-native-known-good, an active boot hook,
  and the exact K1C 4.4.94 module ABI. Do not use on a different printer/kernel.
- The printer must be **idle, not printing**, and have Wi-Fi enabled.
- Verify a **working independent Wi-Fi SSH connection**: unplug the Ethernet
  cable while leaving the USB adapter connected, reconnect to the Wi-Fi IP,
  then plug Ethernet back in. Existing SSH sessions can drop during failover,
  particularly with Wi-Fi and Ethernet in the same subnet.
- The test loads ONLY a temporary cdc_ncm.ko into RAM. The original
  v1.0.2 modules, installer and boot hook remain unchanged.
- A background watchdog **reboots the printer 10 minutes after switching**,
  restoring the stock module through the existing boot setup.
  If the automatic reboot fails, reboot the printer manually when safe.

## Get the test files

On the printer, logged in over **Wi-Fi SSH**:

\`\`\`sh
T=/usr/data/k1c-usb-ethernet/issue1-eval
mkdir -p "$T"
cd "$T" || exit 1

BASE=https://raw.githubusercontent.com/Zaknin/Creality-K1C-ethernet-driver/test/issue-1-candidate/test/issue-1
wget -O cdc_ncm.ko "$BASE/cdc_ncm.ko"
wget -O run-test.sh "$BASE/run-test.sh"

echo '5cb1573d71fd1c3df6878e544dade7ef52f132a46bbc8bd238ed124d56104d8c  cdc_ncm.ko' | sha256sum -c -
sh run-test.sh preflight
\`\`\`

Both checks must pass. If the printer cannot fetch HTTPS, download the
two files on your computer and upload them over your existing SSH connection.
Do **not** proceed if either download or hash verification fails.

## Compare stock and candidate

1. Record 120 seconds using stock v1.0.2:

   \`\`\`sh
   cd /usr/data/k1c-usb-ethernet/issue1-eval || exit 1
   sh run-test.sh baseline > baseline.log 2>&1
   \`\`\`

2. Switch to the test module and arm the independent reboot watchdog.
   Start this command **only once**. Running it detached is deliberate:
   it can continue if SSH disconnects during network reconfiguration.

   \`\`\`sh
   nohup sh run-test.sh start </dev/null > switch.log 2>&1 &
   sleep 20
   cat switch.log
   \`\`\`

   Expect cdc_ncm size **17180** in the module listing and DHCP on usb0.
   The original loaded module is size **17148**. If switching fails, **do not
   rerun it**; allow the watchdog to reboot the printer.

3. While the test module is active, record the same 120-second sample:

   \`\`\`sh
   sh run-test.sh sample > candidate.log 2>&1
   \`\`\`

4. Optional but useful: test one real link transition while the
   candidate is active. Start the background recorder, unplug **only the
   Ethernet cable** for ~15 seconds, reconnect it, then wait ~45 seconds.

   \`\`\`sh
   nohup sh run-test.sh monitor </dev/null > physical.log 2>&1 &
   \`\`\`

   Check physical.log and run \`sh run-test.sh status\`. Expect the carrier
   to transition 1 -> 0 -> 1, Wi-Fi fallback during the outage, and USB
   routing to return after reconnection.

## Rollback and results

Allow the timed reboot to complete. If necessary, reconnect to the Wi-Fi IP.

\`\`\`sh
cd /usr/data/k1c-usb-ethernet/issue1-eval || exit 1
cat watchdog.log
sh run-test.sh status
(cd /usr/data/k1c-usb-ethernet/vendor-native-known-good &&
 sha256sum -c module-hashes.sha256)
\`\`\`

Expect the original cdc_ncm size **17148** and all original module
checksums to pass. The test files/logs stay under issue1-eval; nothing
replaces the v1.0.2 installation.

Please attach baseline.log, candidate.log, switch.log, and (if collected)
physical.log to issue #1. Also report whether the repetitive
\`network connection: connected\` / \`1000 mbit/s\` lines stopped and
whether connectivity remained stable.

**Note:** dmesg and syslog can be circular/rotated; a count that stays
constant by itself is not proof that no messages were generated. Include
the raw log excerpts. Record rx_dropped too, but it is deliberately
**outside the scope of this notification patch**.
