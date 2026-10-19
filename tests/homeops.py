"""Offline installer fixtures: real isolated Python metadata, stubbed uv/network."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[1]
REVIEWED = 'a' * 40
OLDER = 'b' * 40

FAKE_UV = r'''
import json
import os
import subprocess
import sys
import venv
from pathlib import Path

root = Path(os.environ['HOMEOPS_TEST_ROOT'])
args = sys.argv[1:]
if args == ['tool', 'dir']:
    print(root / 'tools')
    raise SystemExit(0)
if args[:2] != ['tool', 'install']:
    raise SystemExit(2)
calls = root / 'calls.json'
prior = json.loads(calls.read_text()) if calls.exists() else []
calls.write_text(json.dumps(prior + [args]))
if os.environ.get('HOMEOPS_TEST_FAIL') == '1':
    raise SystemExit(44)
reference = args[-1].rsplit('@', 1)[-1]
environment = root / 'tools' / 'homeops'
venv.EnvBuilder(with_pip=False, symlinks=True).create(environment)
python = environment / 'bin' / 'python'
result = subprocess.run([str(python), '-I', '-c',
                         'import sysconfig; print(sysconfig.get_path("purelib"))'],
                        capture_output=True, text=True, check=True)
distribution = Path(result.stdout.strip()) / 'homeops-0.1.0.dist-info'
distribution.mkdir(exist_ok=True)
(distribution / 'METADATA').write_text('Metadata-Version: 2.1\nName: homeops\nVersion: 0.1.0\n')
(distribution / 'direct_url.json').write_text(json.dumps({
    'url': os.environ.get('HOMEOPS_TEST_SOURCE_URL', 'https://github.com/c-luu/homeops.git'),
    'vcs_info': {'vcs': 'git', 'requested_revision': reference,
                 'commit_id': os.environ.get('HOMEOPS_TEST_RESULT_COMMIT', reference)},
}))
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='homeops-installer-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.checkout = self.root / 'checkout'
        (self.checkout / 'scripts').mkdir(parents=True)
        for name in ('install-homeops.sh', 'homeops-installed-revision.py'):
            shutil.copy2(REPOSITORY / 'scripts' / name, self.checkout / 'scripts' / name)
        (self.checkout / 'homeops-version').write_text(REVIEWED + '\n')
        self.state = self.root / 'state'
        self.state.mkdir()
        self.marker = self.state / 'installation-reference'
        self.calls = self.root / 'calls.json'
        self.binary = self.root / 'bin'
        self.binary.mkdir()
        fake_uv = self.binary / 'uv'
        fake_uv.write_text('#!/bin/sh\nexec "$HOMEOPS_TEST_PYTHON" "$HOMEOPS_TEST_UV_SCRIPT" "$@"\n')
        fake_uv.chmod(0o755)
        (self.root / 'fake_uv.py').write_text(FAKE_UV)
        self.env = dict(os.environ, HOMEOPS_UV=str(fake_uv), HOMEOPS_TEST_ROOT=str(self.root),
                        HOMEOPS_INSTALL_STATE_DIR=str(self.state),
                        HOMEOPS_TEST_PYTHON=sys.executable,
                        HOMEOPS_TEST_UV_SCRIPT=str(self.root / 'fake_uv.py'),
                        PATH=str(self.binary) + os.pathsep + '/usr/bin:/bin')

    def run_installer(self, *args, **changes):
        return subprocess.run(['/bin/bash', str(self.checkout / 'scripts' / 'install-homeops.sh'),
                               *args], env=dict(self.env, **changes),
                              text=True, capture_output=True, check=False)

    def seed(self, reference=OLDER, **changes):
        subprocess.run([self.env['HOMEOPS_UV'], 'tool', 'install',
                        'git+https://github.com/c-luu/homeops.git@' + reference],
                       env=dict(self.env, **changes), check=True)
        self.calls.unlink()

    def attempts(self):
        return json.loads(self.calls.read_text()) if self.calls.exists() else []

    def test_fresh_install_uses_exact_reference_and_verified_metadata(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.attempts(), [['tool', 'install',
                         'git+https://github.com/c-luu/homeops.git@' + REVIEWED]])
        self.assertEqual(self.marker.read_text(), REVIEWED + '\n')

    def test_matching_installation_is_not_replaced_even_with_stale_marker(self):
        self.seed(REVIEWED)
        self.marker.write_text(OLDER + '\n')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.attempts(), [])
        self.assertEqual(self.marker.read_text().strip(), REVIEWED)

    def test_matching_marker_never_hides_an_installed_revision_mismatch(self):
        self.seed(OLDER)
        self.marker.write_text(REVIEWED + '\n')
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--upgrade', result.stderr)
        self.assertEqual(self.attempts(), [])
        self.assertEqual(self.marker.read_text().strip(), REVIEWED)

    def test_marker_alone_is_not_an_installation(self):
        self.marker.write_text(REVIEWED + '\n')
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual(len(self.attempts()), 1)

    def test_explicit_upgrade_replaces_and_verifies(self):
        self.seed(OLDER)
        self.marker.write_text(OLDER + '\n')
        result = self.run_installer('--upgrade')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--force', self.attempts()[0])
        self.assertEqual(self.marker.read_text().strip(), REVIEWED)

    def test_unexpected_package_source_needs_explicit_upgrade(self):
        self.seed(REVIEWED, HOMEOPS_TEST_SOURCE_URL='https://example.com/unrelated.git')
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.attempts(), [])
        self.assertEqual(self.run_installer('--upgrade').returncode, 0)

    def test_unmanaged_executable_is_not_overwritten_implicitly(self):
        external = self.binary / 'homeops'
        external.write_text('#!/bin/sh\nexit 0\n')
        external.chmod(0o755)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.attempts(), [])
        self.assertTrue(external.exists())

    def test_failed_install_preserves_previous_marker(self):
        self.seed(OLDER)
        self.marker.write_text(OLDER + '\n')
        result = self.run_installer('--upgrade', HOMEOPS_TEST_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.marker.read_text().strip(), OLDER)

    def test_wrong_installed_commit_is_not_marked_successful(self):
        self.marker.write_text(OLDER + '\n')
        result = self.run_installer(HOMEOPS_TEST_RESULT_COMMIT=OLDER)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not be verified', result.stderr)
        self.assertEqual(self.marker.read_text().strip(), OLDER)

    def test_invalid_reference_and_arguments_do_not_install(self):
        for value in ('main', REVIEWED + '\nextra', REVIEWED + ' '):
            (self.checkout / 'homeops-version').write_text(value)
            self.assertNotEqual(self.run_installer().returncode, 0)
        (self.checkout / 'homeops-version').write_text(REVIEWED + '\n')
        self.assertEqual(self.run_installer('--upgrade', '--extra').returncode, 2)
        self.assertEqual(self.attempts(), [])


if __name__ == '__main__':
    unittest.main()
