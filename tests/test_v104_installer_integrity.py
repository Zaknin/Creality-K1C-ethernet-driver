#!/usr/bin/env python3
"""Static release-integrity and simulated installer tests, no printer needed.

Run: python3 tests/test_v104_installer_integrity.py
This is NOT physical K1C/overlay/reboot qualification.
"""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "package"
KNOWN_CDC = "f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checksums(file):
    mapping = {}
    for line in file.read_text().splitlines():
        h, rel = line.split("  ", 1)
        assert len(h) == 64 and rel not in mapping
        mapping[rel] = h
    return mapping


class PackageIntegrity(unittest.TestCase):
    def test_all_package_files_are_hashed(self):
        listing = checksums(PKG / "SHA256SUMS")
        expected_files = {
            p.relative_to(PKG).as_posix()
            for p in PKG.rglob("*")
            if p.is_file() and p.name != "SHA256SUMS"
        }
        self.assertEqual(set(listing), expected_files)
        for rel, expected in listing.items():
            with self.subTest(path=rel):
                self.assertEqual(digest(PKG / rel), expected)

    def test_startup_hardcoded_hash_matches_both_manifests(self):
        m = checksums(PKG / "module-hashes.sha256")
        all_files = checksums(PKG / "SHA256SUMS")
        self.assertEqual(m["modules/cdc_ncm.ko"], KNOWN_CDC)
        for name in ("mii.ko", "usbnet.ko", "cdc_ncm.ko"):
            actual = digest(PKG / "modules" / name)
            self.assertEqual(actual, m["modules/" + name])
            self.assertEqual(actual, all_files["modules/" + name])
        startup = (PKG / "start-usb-ethernet.sh").read_text()
        for name, variable in (
            ("mii.ko", "MII_HASH"),
            ("usbnet.ko", "USBNET_HASH"),
            ("cdc_ncm.ko", "CDC_NCM_HASH"),
        ):
            match = re.search(r'^' + variable + r'="([0-9a-f]{64})"$',
                              startup, re.MULTILINE)
            self.assertIsNotNone(match, variable)
            self.assertEqual(match.group(1), m["modules/" + name])
        manifest = (PKG / "package-manifest.txt").read_text()
        self.assertIn("version=1.0.4\n", manifest)
        self.assertIn("module_cdc_ncm_sha256=" + KNOWN_CDC + "\n", manifest)
        self.assertIn("VERSION=1.0.4\n", (ROOT / "install.sh").read_text())

    def test_shell_syntax(self):
        for path in (ROOT / "install.sh", PKG / "start-usb-ethernet.sh"):
            subprocess.run(["sh", "-n", str(path)], check=True)


class InstallerSimulation(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="k1c-v104-test-")
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name)
        self.runtime = self.work / "runtime"
        self.runtime.mkdir()
        shutil.copytree(PKG, self.runtime / "package")
        self.target = self.work / "userdata" / "vendor-native-known-good"
        self.target.parent.mkdir(parents=True)
        # Only change the install destination in an isolated TEST COPY
        # so actual /usr/data and /etc/init.d are never accessed.
        installer = (ROOT / "install.sh").read_text()
        original = "DEFAULT_INSTALL_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good"
        self.assertEqual(installer.count(original), 1)
        installer = installer.replace(original, "DEFAULT_INSTALL_DIR=" + str(self.target))
        (self.runtime / "install.sh").write_text(installer)
        self.boot_dir = self.work / "overlay" / "etc" / "init.d"
        self.boot_dir.mkdir(parents=True)
        self.hook = self.boot_dir / "S46usb_ethernet_primary"
        self.bin = self.work / "fakebin"
        self.bin.mkdir()
        uname = self.bin / "uname"
        uname.write_text('#!/bin/sh\nif [ "$1" = "-r" ]; then echo 4.4.94; else exec /usr/bin/uname "$@"; fi\n')
        uname.chmod(0o755)

    def run_install(self, args=(), cp_fail=None):
        env = os.environ.copy()
        env["BOOT_HOOK"] = str(self.hook)
        env["PATH"] = str(self.bin) + os.pathsep + env.get("PATH", "")
        cp = self.bin / "cp"
        if cp_fail is not None:
            fail_on = "*.k1c-pending-*" if cp_fail == "boot" else "-R"
            cp.write_text(
                "#!/bin/sh\n"
                "case \"$2\" in\n"
                "  " + fail_on + ") if [ \"$K1C_FAIL_PHASE\" = boot ]; then "
                "echo 'cp: write error: No space left on device' >&2; exit 1; fi;;\n"
                "esac\n"
                "if [ \"$1\" = -R ] && [ \"$K1C_FAIL_PHASE\" = package ]; then "
                "echo 'cp: simulated package failure' >&2; exit 1; fi\n"
                "exec /bin/cp \"$@\"\n"
            )
            cp.chmod(0o755)
            env["K1C_FAIL_PHASE"] = cp_fail
        return subprocess.run(["sh", str(self.runtime / "install.sh"), *args],
                              env=env, capture_output=True, text=True,
                              timeout=30)

    def test_manual_install_succeeds_even_with_no_boot_hook(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.target / ".package-owned").exists())
        self.assertFalse(self.hook.exists())

    def test_normal_boot_install_succeeds(self):
        result = self.run_install(["--enable-boot"])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.target / ".package-owned").exists())
        self.assertEqual(self.hook.read_bytes(),
                         (PKG / "S46usb_ethernet_primary").read_bytes())
        self.assertEqual(self.hook.stat().st_mode & 0o777, 0o755)

    def test_overlay_enospc_fails_before_package_copy(self):
        result = self.run_install(["--enable-boot"], cp_fail="boot")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("check overlay free space", result.stderr)
        self.assertFalse(self.target.exists(), "partial package must not be installed")
        self.assertFalse(self.hook.exists())
        self.assertEqual(list(self.boot_dir.iterdir()), [])

    def test_mid_install_failure_rolls_back(self):
        result = self.run_install(["--enable-boot"], cp_fail="package")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.hook.exists())
        self.assertEqual(list(self.boot_dir.iterdir()), [])

    def test_existing_boot_hook_is_not_overwritten(self):
        self.hook.write_text("owned by something else\n")
        result = self.run_install(["--enable-boot"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.hook.read_text(), "owned by something else\n")
        self.assertFalse(self.target.exists())

    def test_existing_install_is_preserved(self):
        self.target.mkdir()
        (self.target / "existing-user-file").write_text("do not remove")
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.target / "existing-user-file").read_text(), "do not remove")

    def test_tampered_cdc_module_is_rejected_before_writes(self):
        with (self.runtime / "package/modules/cdc_ncm.ko").open("ab") as stream:
            stream.write(b"tamper")
        result = self.run_install(["--enable-boot"])
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.hook.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
