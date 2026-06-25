#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"
STOP_TIMEOUT="${STOP_TIMEOUT:-5}"
KILL_TIMEOUT="${KILL_TIMEOUT:-2}"

log() {
  printf '%s stop-primary[%s] %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$$" \
    "$*" |
    tee -a "$LOG_FILE"
}

pid_is_numeric() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

pid_running() {
  pid="$1"

  kill -0 "$pid" >/dev/null 2>&1 || return 1

  state="$(
    awk '{ print $3 }' "/proc/$pid/stat" 2>/dev/null ||
      true
  )"

  [ "$state" != "Z" ]
}

process_matches() {
  label="$1"
  pid="$2"

  [ -r "/proc/$pid/cmdline" ] || return 1

  cmd="$(
    tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null ||
      true
  )"

  case "$label" in
    monitor)
      case "$cmd" in
        *"$PACKAGE_DIR/usb0-route-monitor.sh"*)
          return 0
          ;;
      esac
      ;;

    udhcpc)
      case "$cmd" in
        *"udhcpc -i usb0 "*"$STATE_DIR/udhcpc-usb0.pid"*"$PACKAGE_DIR/usb0-udhcpc-script.sh"*)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}

wait_for_exit() {
  pid="$1"
  limit="$2"
  elapsed=0

  while pid_running "$pid"; do
    [ "$elapsed" -lt "$limit" ] || return 1
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 0
}

stop_pid() {
  pid="$1"
  label="$2"

  if ! pid_running "$pid"; then
    return 0
  fi

  if ! process_matches "$label" "$pid"; then
    log "refusing to stop unrelated process label=$label pid=$pid"
    return 1
  fi

  log "stopping $label pid=$pid"
  kill "$pid" >/dev/null 2>&1 || true

  if wait_for_exit "$pid" "$STOP_TIMEOUT"; then
    log "$label exited pid=$pid"
    return 0
  fi

  log "$label did not exit after TERM; forcing pid=$pid"
  kill -9 "$pid" >/dev/null 2>&1 || true

  if wait_for_exit "$pid" "$KILL_TIMEOUT"; then
    log "$label force-stopped pid=$pid"
    return 0
  fi

  log "failed to stop $label pid=$pid"
  return 1
}

stop_pid_file() {
  file="$1"
  label="$2"

  [ -s "$file" ] || return 0

  pid="$(cat "$file" 2>/dev/null || true)"

  if ! pid_is_numeric "$pid"; then
    log "invalid $label pid file=$file value=$pid"
    return 1
  fi

  if stop_pid "$pid" "$label"; then
    rm -f "$file"
    return 0
  fi

  return 1
}

stop_discovered_processes() {
  discovered_failed=0

  for proc in /proc/[0-9]*; do
    pid="${proc#/proc/}"

    if process_matches monitor "$pid"; then
      stop_pid "$pid" monitor || discovered_failed=1
    elif process_matches udhcpc "$pid"; then
      stop_pid "$pid" udhcpc || discovered_failed=1
    fi
  done

  [ "$discovered_failed" -eq 0 ]
}

verify_no_package_processes() {
  process_found=0

  for proc in /proc/[0-9]*; do
    pid="${proc#/proc/}"

    if process_matches monitor "$pid"; then
      log "monitor process remains pid=$pid"
      process_found=1
    elif process_matches udhcpc "$pid"; then
      log "DHCP process remains pid=$pid"
      process_found=1
    fi
  done

  [ "$process_found" -eq 0 ]
}

mkdir -p "$STATE_DIR"
failed=0

log "requested"

stop_pid_file "$STATE_DIR/usb0-monitor.pid" monitor ||
  failed=1

stop_pid_file "$STATE_DIR/udhcpc-usb0.pid" udhcpc ||
  failed=1

stop_discovered_processes ||
  failed=1

STATE_DIR="$STATE_DIR" \
LOG_FILE="$LOG_FILE" \
PACKAGE_DIR="$PACKAGE_DIR" \
  "$PACKAGE_DIR/usb0-udhcpc-script.sh" leasefail ||
  failed=1

"$PACKAGE_DIR/stop-usb-ethernet.sh" ||
  failed=1

verify_no_package_processes ||
  failed=1

if [ "$failed" -eq 0 ]; then
  log "complete"
else
  log "incomplete"
fi

exit "$failed"
