#!/usr/bin/env python3
"""One-shot physical K1C RX allowlist test. Reboots to stock after 8 minutes.

Run as root over Wi-Fi SSH, while printer is idle:
  /opt/bin/python3 -u k1c-rx-allowlist-hw-test.py <candidate-sha256>
"""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import traceback

P = Path("/usr/data/k1c-usb-ethernet/vendor-native-known-good")
T = Path("/usr/data/k1c-usb-ethernet/rx-allowlist-test")
CANDIDATE = T / "cdc_ncm.ko"
PARAM_DIR = Path("/sys/module/cdc_ncm/parameters")
STATS = Path("/sys/class/net/usb0/statistics")
FILTER = PARAM_DIR / "drop_l2_8899"
STRICT = PARAM_DIR / "rx_ipv4_only"
ROUTER = "192.0.2.14"
IP = "/opt/sbin/ip"
CYCLE = [
    ("A1 STOCK-LIKE", 0, 0),
    ("B1 ONLY-8899", 1, 0),
    ("C1 IPV4-ONLY", 1, 1),
    ("A2 STOCK-LIKE", 0, 0),
    ("B2 ONLY-8899", 1, 0),
    ("C2 IPV4-ONLY", 1, 1),
]


def say(msg):
    print(msg, flush=True)


def invoke(args, cwd=None, timeout=75, quiet=False):
    result = subprocess.run(
        args, cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE if quiet else None,
        stderr=subprocess.STDOUT if quiet else None,
        text=True, timeout=timeout,
    )
    if result.returncode:
        if quiet:
            say("COMMAND OUTPUT:\n" + result.stdout)
        raise RuntimeError("command failed rc={} args={!r}".format(
            result.returncode, args))
    return result.stdout if quiet else ""


def readfile(p):
    return p.read_text().strip()


def stats():
    keys = (
        "rx_packets", "rx_dropped", "rx_errors",
        "rx_fifo_errors", "rx_missed_errors",
    )
    return {k: int(readfile(STATS / k)) for k in keys}


def assert_stock_preflight(expected_hash):
    say("=== PRECHECK ===")
    if os.geteuid() != 0 or os.uname().release != "4.4.94":
        raise RuntimeError("must run as root on K1C Linux 4.4.94")
    if not CANDIDATE.is_file():
        raise RuntimeError("candidate module absent: {}".format(CANDIDATE))
    digest = hashlib.sha256(CANDIDATE.read_bytes()).hexdigest()
    if digest != expected_hash:
        raise RuntimeError("candidate SHA-256 mismatch, got " + digest)
    invoke(["sha256sum", "-c", "module-hashes.sha256"], cwd=P)

    hook = Path("/etc/init.d/S46usb_ethernet_primary").read_text()
    if "PACKAGE_DIR={}".format(P) not in hook:
        raise RuntimeError("stock boot hook path mismatch")

    if FILTER.exists() or STRICT.exists():
        raise RuntimeError("experimental module already loaded; STOP")

    modules = Path("/proc/modules").read_text()
    if not re.search(r"^cdc_ncm\s+17148\s", modules, re.M):
        raise RuntimeError("original cdc_ncm module not detected")

    addr = invoke([IP, "-4", "addr", "show", "wlan0"], quiet=True)
    route = invoke([IP, "-4", "route"], quiet=True)
    if "192.0.2.15/" not in addr:
        raise RuntimeError("Wi-Fi 192.0.2.15 is missing")
    if "dev wlan0" not in route:
        raise RuntimeError("Wi-Fi fallback route is missing")

    # The previous run's PID file can remain after reboot. Only an actual
    # still-running rollback.sh process is a reason to refuse re-arming.
    for p in Path("/proc").glob("[0-9]*"):
        try:
            cmdline = (p / "cmdline").read_bytes()
        except (OSError, PermissionError):
            continue
        if b"/rx-allowlist-test/rollback.sh" in cmdline:
            raise RuntimeError("another allowlist rollback watchdog running")

    say("Candidate SHA-256 OK: " + digest)
    say("Stock driver, stock hashes, Wi-Fi fallback: OK")


def arm_watchdog():
    rollback = T / "rollback.sh"
    rollback.write_text(
        "#!/bin/sh\n"
        "sleep 480\n"
        "echo 'WATCHDOG: rebooting to original boot-driver modules'\n"
        "sync\nreboot\nsleep 15\nreboot -f\n"
    )
    with (T / "watchdog.log").open("w") as log:
        proc = subprocess.Popen(
            ["sh", str(rollback)], stdin=subprocess.DEVNULL,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
            close_fds=True,
        )
    (T / "watchdog.pid").write_text("{}\n".format(proc.pid))
    time.sleep(2)
    if proc.poll() is not None:
        raise RuntimeError("watchdog exited unexpectedly")
    say("Watchdog armed: PID={} / reboot in 480 s".format(proc.pid))


def activate():
    say("=== MODULE SWITCH ===")
    invoke(["sh", str(P / "stop-primary-ethernet.sh")], timeout=65)
    if re.search(r"^cdc_ncm\s", Path("/proc/modules").read_text(), re.M):
        raise RuntimeError("old cdc_ncm remained loaded; waiting for watchdog")

    for name in ("mii", "usbnet"):
        if not re.search(r"^{}\s".format(name),
                         Path("/proc/modules").read_text(), re.M):
            invoke(["insmod", str(P / "modules" / (name + ".ko"))])
    invoke(["insmod", str(CANDIDATE)])
    invoke(["sh", str(P / "start-primary-ethernet.sh")], timeout=85)

    if not FILTER.exists() or not STRICT.exists():
        raise RuntimeError("module parameters missing")
    if readfile(FILTER) != "Y" or readfile(STRICT) != "N":
        raise RuntimeError("unexpected module parameter defaults")

    route = invoke([IP, "-4", "route"], quiet=True)
    if ("default via {} dev usb0 metric 50".format(ROUTER)
            not in route):
        raise RuntimeError("primary usb0 default route missing")

    say("Module parameters: drop_l2_8899=Y rx_ipv4_only=N")
    say("USB primary route: OK")


def set_mode(targeted, strict):
    # These are two independent writable module parameters.
    # To minimize momentary exposure: strict off first for relaxed modes,
    # then targeted flag, then strict on for the strict mode.
    STRICT.write_text("0\n")
    FILTER.write_text("{}\n".format(targeted))
    STRICT.write_text("{}\n".format(strict))
    if readfile(FILTER) != ("Y" if targeted else "N"):
        raise RuntimeError("targeted toggle did not apply")
    if readfile(STRICT) != ("Y" if strict else "N"):
        raise RuntimeError("strict toggle did not apply")


def ping_usb():
    result = subprocess.run(
        ["ping", "-I", "usb0", "-c", "3", "-W", "2", ROUTER],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, timeout=15,
    )
    lines = result.stdout.splitlines()
    summary = next((line for line in lines if "packets transmitted" in line),
                   "no ICMP summary")
    if result.returncode:
        say("PING FAIL: {}".format(result.stdout.strip()))
        return False
    say("  USB ping: {}".format(summary.strip()))
    return True


def measure(label, targeted, strict):
    set_mode(targeted, strict)
    time.sleep(2)
    before = stats()
    time.sleep(25)
    after = stats()
    delta = {k: after[k] - before[k] for k in before}
    say(
        "{:<16} target={} strict={} | "
        "RX +{:5d} | DROP +{:4d} | ERR +{:3d} | FIFO +{:3d} | MISSED +{:3d}"
        .format(label, targeted, strict,
                delta["rx_packets"], delta["rx_dropped"],
                delta["rx_errors"], delta["rx_fifo_errors"],
                delta["rx_missed_errors"])
    )
    return delta, ping_usb()


def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"[a-fA-F0-9]{64}",
                                               sys.argv[1]):
        raise SystemExit("usage: script.py <64-char candidate sha256>")
    T.mkdir(parents=True, exist_ok=True)
    assert_stock_preflight(sys.argv[1].lower())
    arm_watchdog()
    # From this point onward, any failure leaves the watchdog armed.
    results = []
    try:
        activate()
        say("=== A/B/C RESULTS: two 25-second cycles ===")
        for label, targeted, strict in CYCLE:
            delta, ping_ok = measure(label, targeted, strict)
            results.append((label, delta, ping_ok))
    finally:
        if FILTER.exists() and STRICT.exists():
            try:
                set_mode(1, 0)
                say("Restored targeted 0x8899 filter; strict mode OFF")
            except Exception:
                say("WARNING: unable to restore toggles; watchdog remains armed")
                traceback.print_exc()

    say("=== RESULT SUMMARY ===")
    for label, delta, ping_ok in results:
        say("{}: drop +{}, errors +{}, ping {}".format(
            label, delta["rx_dropped"], delta["rx_errors"],
            "PASS" if ping_ok else "FAIL"))
    say("=== TEST COMPLETE; WATCHDOG WILL REBOOT TO STOCK ===")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        say("TEST ABORTED: watchdog (if armed) will restore stock by reboot")
        sys.exit(1)
