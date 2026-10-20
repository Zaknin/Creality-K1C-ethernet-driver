#!/usr/bin/env python3
"""v1.0.6 draft: host-side installer and logging simulations, no physical printer."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / 'package'


class V106Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='k1c-v106-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.runtime = self.work / 'runtime'
        self.runtime.mkdir()
        shutil.copytree(PKG, self.runtime / 'package')
        self.dest = self.work / 'usrdata' / 'owned-package'
        self.dest.parent.mkdir()
        self.overlay = self.work / 'overlay' / 'etc' / 'init.d'
        self.overlay.mkdir(parents=True)
        self.hook = self.overlay / 'S46usb_ethernet_primary'
        self.fakebin = self.work / 'bin'
        self.fakebin.mkdir()
        u = self.fakebin / 'uname'
        u.write_text('#!/bin/sh\nif [ "$1" = -r ]; then echo 4.4.94; else /usr/bin/uname "$@"; fi\n')
        u.chmod(0o755)
        installer = (ROOT / 'install.sh').read_text()
        needle='DEFAULT_INSTALL_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good'
        self.assertEqual(installer.count(needle),1)
        (self.runtime / 'install.sh').write_text(installer.replace(needle,'DEFAULT_INSTALL_DIR='+str(self.dest)))

    def run_installer(self, *opts, stub=None):
        env=os.environ.copy()
        env.update(BOOT_HOOK=str(self.hook), PATH=str(self.fakebin)+os.pathsep+env.get('PATH',''))
        if stub == 'ln':
            cmd=self.fakebin/'ln'
            cmd.write_text('#!/bin/sh\necho "simulated ENOSPC" >&2\nexit 1\n')
            cmd.chmod(0o755)
        elif stub == 'package_cp':
            cmd=self.fakebin/'cp'
            cmd.write_text('#!/bin/sh\nif [ "$1" = -R ]; then echo "simulated failed copy" >&2; exit 1; fi\nexec /bin/cp "$@"\n')
            cmd.chmod(0o755)
        elif stub == 'boot_cp':
            cmd=self.fakebin/'cp'
            cmd.write_text('#!/bin/sh\ncase "$2" in *.k1c-pending-*) echo "simulated ENOSPC" >&2; exit 1;; esac\nexec /bin/cp "$@"\n')
            cmd.chmod(0o755)
        return subprocess.run(['sh',str(self.runtime/'install.sh'),*opts],env=env,capture_output=True,text=True,timeout=20)

    def test_manual_no_boot(self):
        result=self.run_installer()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((self.dest/'.package-owned').is_file())
        self.assertFalse(self.hook.exists())

    def test_legacy_copy_mode(self):
        result=self.run_installer('--enable-boot')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(self.hook.is_symlink())
        self.assertEqual(self.hook.read_bytes(),(PKG/'S46usb_ethernet_primary').read_bytes())

    def test_symlink_mode_owned(self):
        result=self.run_installer('--enable-boot','--boot-hook','symlink')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue(self.hook.is_symlink())
        self.assertEqual(os.readlink(self.hook),str(self.dest/'S46usb_ethernet_primary'))
        self.assertEqual(self.hook.resolve().read_bytes(),(PKG/'S46usb_ethernet_primary').read_bytes())

    def test_symlink_refuses_existing_hook(self):
        self.hook.write_text('foreign owner\n')
        result=self.run_installer('--enable-boot','--boot-hook','symlink')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.hook.read_text(),'foreign owner\n')
        self.assertFalse(self.dest.exists())

    def test_symlink_creation_enospc_is_safe(self):
        result=self.run_installer('--enable-boot','--boot-hook','symlink',stub='ln')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.dest.exists())
        self.assertFalse(self.hook.exists())
        self.assertEqual(list(self.overlay.iterdir()),[])

    def test_legacy_copy_enospc_is_safe(self):
        result=self.run_installer('--enable-boot',stub='boot_cp')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.dest.exists())
        self.assertFalse(self.hook.exists())

    def test_symlink_midcopy_failure_rolls_back(self):
        result=self.run_installer('--enable-boot','--boot-hook','symlink',stub='package_cp')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.dest.exists())
        self.assertFalse(self.hook.exists())
        self.assertEqual(list(self.overlay.iterdir()),[])

    def test_bad_mode_and_missing_enable_boot_fail_closed(self):
        for opts in [('--enable-boot','--boot-hook','nonsense'),('--boot-hook','symlink')]:
            with self.subTest(opts=opts):
                result=self.run_installer(*opts)
                self.assertNotEqual(result.returncode,0)
                self.assertFalse(self.dest.exists())

    def test_disable_owned_symlink(self):
        result=self.run_installer('--enable-boot','--boot-hook','symlink')
        self.assertEqual(result.returncode,0,result.stderr)
        stop=self.dest/'stop-primary-ethernet.sh'
        stop.write_text('#!/bin/sh\nexit 0\n')
        stop.chmod(0o755)
        env=os.environ.copy()
        env.update(BOOT_HOOK=str(self.hook),PACKAGE_DIR=str(self.dest))
        d=subprocess.run(['sh',str(self.dest/'disable-primary-ethernet-boot.sh')],env=env,capture_output=True,text=True)
        self.assertEqual(d.returncode,0,d.stderr)
        self.assertFalse(self.hook.is_symlink())
        self.assertFalse(self.hook.exists())

    def test_disable_refuses_foreign_broken_symlink(self):
        target=self.work/'foreign'
        self.hook.symlink_to(target)
        env=os.environ.copy()
        env.update(BOOT_HOOK=str(self.hook),PACKAGE_DIR=str(PKG))
        d=subprocess.run(['sh',str(PKG/'disable-primary-ethernet-boot.sh')],env=env,capture_output=True,text=True)
        self.assertNotEqual(d.returncode,0)
        self.assertTrue(self.hook.is_symlink())

    def test_disable_refuses_foreign_regular_file(self):
        self.hook.write_text('other owner\n')
        env=os.environ.copy()
        env.update(BOOT_HOOK=str(self.hook),PACKAGE_DIR=str(PKG))
        d=subprocess.run(['sh',str(PKG/'disable-primary-ethernet-boot.sh')],env=env,capture_output=True,text=True)
        self.assertNotEqual(d.returncode,0)
        self.assertEqual(self.hook.read_text(),'other owner\n')

    def test_volatile_logging_default(self):
        helper=PKG/'runtime-logging.sh'
        logdir=self.work/'run'/'k1c-usb-ethernet'
        sh=f'. "{helper}"; K1C_LOG_DIR="{logdir}"; k1c_setup_log primary-ethernet.log || exit 7; printf "ok\\n" >> "$LOG_FILE"; k1c_trim_log; printf "%s\\n" "$LOG_FILE"'
        r=subprocess.run(['sh','-c',sh],env={**os.environ,'LOG_FILE':''},text=True,capture_output=True)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(r.stdout.strip(),str(logdir/'primary-ethernet.log'))
        self.assertEqual((logdir/'primary-ethernet.log').read_text(),'ok\n')

    def test_volatile_soft_cap(self):
        helper=PKG/'runtime-logging.sh'
        logdir=self.work/'run'/'k1c-usb-ethernet'
        sh=f'. "{helper}"; K1C_LOG_DIR="{logdir}"; K1C_LOG_MAX_BYTES=32; k1c_setup_log t.log || exit 7; printf "%080d" 0 >> "$LOG_FILE"; k1c_trim_log; wc -c < "$LOG_FILE"'
        r=subprocess.run(['sh','-c',sh],env={**os.environ,'LOG_FILE':''},text=True,capture_output=True)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(r.stdout.strip(),'0')

    def test_flash_logging_requires_explicit_override(self):
        helper=PKG/'runtime-logging.sh'
        with tempfile.TemporaryDirectory(prefix='k1c-flash-log-test-', dir=Path.home()) as dirname:
            fake_flash=Path(dirname)/'persistent.log'
            command=f'. "{helper}"; LOG_FILE="{fake_flash}"; k1c_setup_log something.log'
            r=subprocess.run(['sh','-c',command],capture_output=True,text=True)
            self.assertNotEqual(r.returncode,0)
            self.assertFalse(fake_flash.exists())
            r=subprocess.run(['sh','-c',command],env={**os.environ,'K1C_ALLOW_PERSISTENT_LOGS':'1'},capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertTrue(fake_flash.exists())

    def test_no_default_logs_in_package(self):
        for p in PKG.iterdir():
            if p.is_file() and p.suffix == '.sh':
                t=p.read_text()
                self.assertNotIn('$PACKAGE_DIR/primary-ethernet.log',t,p.name)
                self.assertNotIn('$PACKAGE_DIR/usb-ethernet.log',t,p.name)
        self.assertNotIn('$PACKAGE_DIR/primary-ethernet-boot.log',(PKG/'S46usb_ethernet_primary').read_text())

if __name__=='__main__':
    unittest.main(verbosity=2)
