#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/k1c-usb-ethernet-install-test-$$"

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

(
  cd "$TMP/work"
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=5.10.0 \
    run_expect_fail unsupported_kernel sh install.sh --dest "$TMP/dest-unsupported"
)

(
  cd "$TMP/work"
  printf 'bad  modules/mii.ko\n' > package/module-hashes.sha256
  PATH="$TMP/bin:$PATH" FAKE_UNAME_R=4.4.94 \
    run_expect_fail hash_mismatch sh install.sh --dest "$TMP/dest-hash"
)

echo "installer refusal checks passed"
