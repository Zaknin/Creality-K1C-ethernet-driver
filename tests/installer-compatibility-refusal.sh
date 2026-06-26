#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-usb-ethernet-install-test-$$"
SH="${SH:-/usr/bin/sh}"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/work"
cp -R "$ROOT"/. "$TMP/work/"

cat > "$TMP/bin/uname" <<'EOS'
#!/bin/sh
case "${1:-}" in
  -r) echo "${FAKE_UNAME_R:-0.0.0}" ;;
  *) /bin/uname "$@" ;;
esac
EOS
chmod 755 "$TMP/bin/uname"

run_expect_fail() {
  label="$1"
  shift
  if "$@" > "$TMP/$label.out" 2> "$TMP/$label.err"; then
    echo "FAIL: $label unexpectedly succeeded" >&2
    exit 1
  fi
  echo "PASS: $label failed as expected"
}

run_expect_success() {
  label="$1"
  shift
  if ! "$@" > "$TMP/$label.out" 2> "$TMP/$label.err"; then
    echo "FAIL: $label unexpectedly failed" >&2
    cat "$TMP/$label.out" >&2
    cat "$TMP/$label.err" >&2
    exit 1
  fi
  echo "PASS: $label succeeded"
}

assert_installed() {
  dest="$1"
  hook="$2"
  [ -f "$dest/.package-owned" ] || {
    echo "FAIL: install marker missing in $dest" >&2
    exit 1
  }
  [ -x "$dest/start-primary-ethernet.sh" ] || {
    echo "FAIL: runtime script not executable in $dest" >&2
    exit 1
  }
  [ -n "$hook" ] || return 0
  [ -x "$hook" ] || {
    echo "FAIL: boot hook missing or not executable: $hook" >&2
    exit 1
  }
}

(
  cd "$TMP/work"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_success extracted_root "$SH" ./install.sh --dest "$TMP/dest-root"
)
assert_installed "$TMP/dest-root" ""

(
  cd "$TMP"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_success absolute_path "$SH" "$TMP/work/install.sh" --dest "$TMP/dest-absolute"
)
assert_installed "$TMP/dest-absolute" ""

(
  cd "$TMP"
  mkdir -p caller
  cd caller
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_success relative_path "$SH" ../work/install.sh --dest "$TMP/dest-relative"
)
assert_installed "$TMP/dest-relative" ""

(
  cd "$TMP"
  cp -R "$TMP/work" "$TMP/work with spaces"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_success spaces_path "$SH" "$TMP/work with spaces/install.sh" --dest "$TMP/dest with spaces"
)
assert_installed "$TMP/dest with spaces" ""

(
  cd "$TMP"
  hook="$TMP/custom init/S46usb_ethernet_primary"
  mkdir -p "$(dirname "$hook")"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 BOOT_HOOK="$hook" \
    run_expect_success custom_boot_hook "$SH" "$TMP/work/install.sh" --enable-boot --dest "$TMP/dest-hook"
)
assert_installed "$TMP/dest-hook" "$TMP/custom init/S46usb_ethernet_primary"

(
  cd "$TMP"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_success custom_dest "$SH" "$TMP/work/install.sh" --dest "$TMP/custom/dest"
)
assert_installed "$TMP/custom/dest" ""

(
  cd "$TMP"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_fail existing_install "$SH" "$TMP/work/install.sh" --dest "$TMP/dest-root"
)

(
  cd "$TMP"
  cp -R "$TMP/work" "$TMP/missing-package"
  rm -rf "$TMP/missing-package/package"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_fail missing_package "$SH" "$TMP/missing-package/install.sh" --dest "$TMP/dest-missing-package"
)

(
  cd "$TMP"
  cp -R "$TMP/work" "$TMP/missing-hashes"
  rm -f "$TMP/missing-hashes/package/module-hashes.sha256"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_fail missing_hashes "$SH" "$TMP/missing-hashes/install.sh" --dest "$TMP/dest-missing-hashes"
)

(
  cd "$TMP/work"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=5.10.0 \
    run_expect_fail unsupported_kernel "$SH" install.sh --dest "$TMP/dest-unsupported"
)

(
  cd "$TMP"
  cp -R "$TMP/work" "$TMP/hash-mismatch"
  printf 'bad  modules/mii.ko\n' > "$TMP/hash-mismatch/package/module-hashes.sha256"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_fail hash_mismatch "$SH" "$TMP/hash-mismatch/install.sh" --dest "$TMP/dest-hash"
)

echo "installer refusal checks passed"
