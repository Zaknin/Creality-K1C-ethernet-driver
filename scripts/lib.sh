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

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$(pwd)/$1" ;;
  esac
}

reject_private_text() {
  target=$1
  secret_re='pass(word|wd)=|tok(en)?=|api[_-]?key='
  if grep -RInE "(/home/[^[:space:]]+|/Users/[^[:space:]]+|C:\\\\Users\\\\|ssh-rsa|BEGIN OPENSSH|BEGIN RSA|$secret_re|[0-9]{1,3}(\.[0-9]{1,3}){3})" "$target" >/dev/null 2>&1; then
    die "private-looking data found under $target"
  fi
}

require_host_arg() {
  host=$1
  [ -n "$host" ] || die "missing --host root@PRINTER_ADDRESS"
  case "$host" in
    *@*) : ;;
    *) die "--host must be explicit user@address" ;;
  esac
  case "$host" in
    *PRINTER_ADDRESS*) die "replace PRINTER_ADDRESS with a real target before running" ;;
  esac
}

expected_modules() {
  printf '%s\n' mii.ko usbnet.ko cdc_ncm.ko
}

project_root() {
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  CDPATH='' cd -- "$script_dir/.." && pwd
}
