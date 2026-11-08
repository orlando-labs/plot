#!/usr/bin/env python3
"""Verify every prepared plot variant in an isolated consumer package store."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

# Reuse the release scoping helpers without running prepare's CLI.
helpers = {'__file__': str(Path(__file__).with_name('prepare.py'))}
exec(Path(helpers['__file__']).read_text().split('p=argparse.ArgumentParser')[0], helpers)
rewrite, SDK_ROOT = helpers['rewrite'], helpers['SDK_ROOT']

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--platform', default='macos-aarch64')
p.add_argument('--out', type=Path, default=Path(__file__).parent / 'out')
p.add_argument('--sputnik', type=Path, default=SDK_ROOT / 'build/sputnik')
a = p.parse_args()
repo = Path(__file__).resolve().parents[1]
root = a.out.resolve() / 'plot'
cli = a.sputnik.resolve()
reports = []
archives = sorted(root.glob(a.platform + '-*/*.sputnikpkg'))
if len(archives) != 4:
    raise RuntimeError('expected four source/bytecode × source/prebuilt variants')
for archive in archives:
    info = json.loads((archive.parent / 'inspect.json').read_text())
    assert any(m['path'] == 'THIRD_PARTY_NOTICES.md' for m in info['members'])
    work = root / 'verification' / archive.parent.name
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    (work / 'out').mkdir()
    shutil.copytree(repo / 'test/fixtures', work / 'test/fixtures')
    text = rewrite((repo / 'test/selftest.s').read_text())
    text = text.replace('def main():', 'def _release_main():')
    text += '\ndef main():\n  score = _release_main()\n  raise ValueError("plot conformance score") unless score == EXPECTED\n  print(score)\n  0\n'
    source = work / 'check.s'
    source.write_text(text)
    files = work / 'images.s'
    files.write_text(rewrite((repo / 'test/images.s').read_text()))
    # Give each consumer its own project root, including its lock file.
    (work / 'sputnik.build.yaml').write_text(
        'schema: sputnik.build.v1\nname: plot.release.check\n'
        'root: slowpilot.plot.selftest\nmodules:\n'
        '  - name: slowpilot.plot.selftest\n    path: check.s\n'
        '  - name: slowpilot.plot.images_test\n    path: images.s\n')
    env = dict(os.environ, SPUTNIK_PKG_HOME=str(work / 'home'),
               SPUTNIK_NATIVE_EXT_CACHE=str(work / 'cache'))
    commands = [
        ('install', [cli, 'pkg', 'install', archive, '--allow-native'] +
         (['--build-from-source'] if '-source-' in archive.parent.name else [])),
        ('selftest', [cli, 'run', source, '--grant', 'ffi']),
        ('images', [cli, 'run', files, '--grant', 'ffi', '--grant', 'fs.read', '--grant', 'fs.write']),
        ('lock', [cli, 'pkg', 'lock', source]),
    ]
    for label, command in commands:
        with (work / (label + '.log')).open('w') as output:
            result = subprocess.run(list(map(str, command)), cwd=work, env=env,
                                    stdout=output, stderr=subprocess.STDOUT, timeout=300)
        if result.returncode:
            raise RuntimeError((work / (label + '.log')).read_text()[-8000:])
        print('PASS', archive.parent.name, label, flush=True)
    lock = (work / 'sputnik.lock').read_text()
    assert archive.parent.name in lock and info['sha256'] in lock
    reports.append(dict(variant=archive.parent.name, sha256=info['sha256'],
                        conformance=53, image_files=True, lock=True))
(root / 'verification' / ('result-' + a.platform + '.json')).write_text(
    json.dumps(reports, indent=2) + '\n')
