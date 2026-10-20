#!/bin/sh
# v1.0.6: volatile, package-scoped log files (never silently fall back to flash).
# Persistent logging requires explicitly setting K1C_ALLOW_PERSISTENT_LOGS=1.
K1C_LOG_DIR="${K1C_LOG_DIR:-/run/k1c-usb-ethernet}"
K1C_LOG_MAX_BYTES="${K1C_LOG_MAX_BYTES:-262144}"

k1c_setup_log() {
  k1c_log_name="$1"
  LOG_FILE="${LOG_FILE:-$K1C_LOG_DIR/$k1c_log_name}"
  case "$LOG_FILE" in
    /*) ;;
    *) echo "k1c: refusing non-absolute log path" >&2; return 1 ;;
  esac
  if [ "${K1C_ALLOW_PERSISTENT_LOGS:-0}" != 1 ]; then
    case "$LOG_FILE" in
      /run/*|/tmp/*|/var/run/*) ;;
      *) echo "k1c: persistent logging requires K1C_ALLOW_PERSISTENT_LOGS=1" >&2; return 1 ;;
    esac
  fi
  k1c_log_parent="${LOG_FILE%/*}"
  [ ! -L "$k1c_log_parent" ] || {
    echo "k1c: refusing symlink log directory $k1c_log_parent" >&2
    return 1
  }
  (umask 077; mkdir -p "$k1c_log_parent") || return 1
  [ -d "$k1c_log_parent" ] || return 1
  (umask 077; : >> "$LOG_FILE") || return 1
}

# Soft cap: truncates the SAME inode; background appenders can retain it.
# Several simultaneous writers might briefly exceed this value.
k1c_trim_log() {
  [ -f "$LOG_FILE" ] || return 0
  case "$K1C_LOG_MAX_BYTES" in
    ''|*[!0-9]*) return 0 ;;
  esac
  k1c_log_length="$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)"
  [ "$k1c_log_length" -le "$K1C_LOG_MAX_BYTES" ] || : > "$LOG_FILE"
}
