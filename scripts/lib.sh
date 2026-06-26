#!/bin/sh
set -eu

die() {
  printf '%s\n' "error: $*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

load_env_file() {
  env_file=$1
  [ -f "$env_file" ] || die "env file not found: $env_file"
  # shellcheck disable=SC1090
  . "$env_file"
}

expected_modules() {
  printf '%s\n' mii.ko usbnet.ko cdc_ncm.ko
}

project_root() {
  script_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
  printf '%s\n' "$script_dir"
}
