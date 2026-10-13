#!/bin/sh
# Temporary K1C 4.4.94 CDC-NCM test. Stock v1.0.2 files are never overwritten.
set -eu
P=/usr/data/k1c-usb-ethernet/vendor-native-known-good
T=/usr/data/k1c-usb-ethernet/issue1-eval
SHA=5cb1573d71fd1c3df6878e544dade7ef52f132a46bbc8bd238ed124d56104d8c

die() { echo "ERROR: $*" >&2; exit 1; }
loaded() { grep -q "^$1 " /proc/modules; }
preflight() {
  [ "$(uname -r)" = 4.4.94 ] || die "kernel is not 4.4.94"
  grep -qx "version=1.0.2" "$P/package-manifest.txt" || die "v1.0.2 package missing"
  [ -f /etc/init.d/S46usb_ethernet_primary ] || die "boot hook missing"
  grep -Fq "PACKAGE_DIR=$P" /etc/init.d/S46usb_ethernet_primary || die "unexpected boot hook"
  (cd "$P" && sha256sum -c module-hashes.sha256) || die "stock module hash mismatch"
  echo "$SHA  $T/cdc_ncm.ko" | sha256sum -c - || die "candidate hash mismatch"
  ip -4 addr show wlan0 | grep -q 'inet ' || die "Wi-Fi IPv4 missing"
  ip -4 route | grep -q 'default .* dev wlan0' || die "Wi-Fi fallback route missing"
}
snapshot() {
  echo "=== $1 / $(date -u) ==="
  for k in carrier rx_packets rx_bytes rx_dropped rx_errors tx_packets tx_errors; do
    case "$k" in
      carrier) path=/sys/class/net/usb0/carrier ;;
      *) path=/sys/class/net/usb0/statistics/$k ;;
    esac
    printf '%-14s ' "$k"
    cat "$path" 2>/dev/null || echo unavailable
  done
  echo '=== SOFTNET ==='
  cat /proc/net/softnet_stat
}
notifications() { dmesg | grep -Ec 'cdc_ncm.*(network connection:|mbit/s)' || true; }
sample() {
  echo "=== $1 ==="
  echo '=== NOTIFICATIONS BEFORE ==='
  notifications
  snapshot START
  sleep 120
  snapshot END
  echo '=== NOTIFICATIONS AFTER ==='
  notifications
  echo '=== CDC-NCM LOGS ==='
  dmesg | grep 'cdc_ncm' | tail -n 40 || true
  echo '=== SYSLOG TAIL ==='
  if [ -f /var/log/messages ]; then
    grep 'cdc_ncm' /var/log/messages | tail -n 20 || true
  fi
}
monitor() {
  prev=unknown
  i=0
  while [ "$i" -lt 180 ]; do
    value=$(cat /sys/class/net/usb0/carrier 2>/dev/null || echo absent)
    if [ "$value" != "$prev" ]; then
      echo "=== $(date -u) carrier=$value ==="
      ip -4 route
      for k in rx_packets rx_dropped rx_errors; do
        printf '%s=' "$k"
        cat "/sys/class/net/usb0/statistics/$k" 2>/dev/null || echo unavailable
      done
      prev="$value"
    fi
    sleep 1
    i=$((i + 1))
  done
  echo '=== MONITOR COMPLETE ==='
}
start() {
  preflight
  loaded cdc_ncm || die "stock cdc_ncm not loaded"
  size=$(awk '$1 == "cdc_ncm" {print $2}' /proc/modules)
  [ "$size" = 17148 ] || die "unexpected loaded cdc_ncm size $size"
  if [ -s "$T/watchdog.pid" ]; then
    old=$(cat "$T/watchdog.pid")
    case "$old" in
      ''|*[!0-9]*) ;;
      *) if [ -r "/proc/$old/cmdline" ]; then
        cmd=$(tr '\000' ' ' < "/proc/$old/cmdline")
        case "$cmd" in *"$T/watchdog.sh"*) die "test watchdog already running" ;; esac
      fi ;;
    esac
  fi
  command -v nohup >/dev/null || die "nohup missing"
  command -v reboot >/dev/null || die "reboot missing"
  cat > "$T/watchdog.sh" <<'WATCHDOG'
#!/bin/sh
sleep 600
echo 'AUTO-ROLLBACK: rebooting to stock v1.0.2'
sync
reboot
sleep 15
reboot -f
WATCHDOG
  nohup sh "$T/watchdog.sh" </dev/null >"$T/watchdog.log" 2>&1 &
  pid=$!
  echo "$pid" >"$T/watchdog.pid"
  sleep 2
  kill -0 "$pid" || die "watchdog failed"
  echo "=== WATCHDOG ARMED: PID $pid, 600 seconds ==="
  "$P/stop-primary-ethernet.sh"
  loaded cdc_ncm && die "stock module still loaded"
  loaded mii || insmod "$P/modules/mii.ko"
  loaded usbnet || insmod "$P/modules/usbnet.ko"
  insmod "$T/cdc_ncm.ko"
  loaded cdc_ncm || die "candidate not loaded"
  "$P/start-primary-ethernet.sh"
  echo '=== ACTIVE MODULES ==='
  lsmod | grep -E '^(cdc_ncm|usbnet|mii) '
  size=$(awk '$1 == "cdc_ncm" {print $2}' /proc/modules)
  [ "$size" = 17180 ] || die "unexpected candidate size $size"
  echo '=== ROUTES ==='
  ip -4 route
  echo '=== CANDIDATE ACTIVE; AUTOMATIC REBOOT STILL ARMED ==='
}
status() {
  echo '=== UPTIME ==='
  cat /proc/uptime
  lsmod | grep -E '^(cdc_ncm|usbnet|mii) ' || true
  ip -4 addr show usb0 || true
  ip -4 addr show wlan0 || true
  ip -4 route
  dmesg | grep 'cdc_ncm' | tail -n 20 || true
  echo '=== WATCHDOG ==='
  cat "$T/watchdog.log" 2>/dev/null || true
}
case "$1" in
  preflight) preflight; echo 'PREFLIGHT PASS' ;;
  baseline) sample STOCK_V1.0.2 ;;
  start) start ;;
  sample) sample CANDIDATE ;;
  monitor) monitor ;;
  status) status ;;
  *) echo "Usage: sh run-test.sh {preflight|baseline|start|sample|monitor|status}" >&2; exit 2 ;;
esac
