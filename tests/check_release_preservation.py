"""Guard the testing-tools release against unintended changes to source content."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
from urllib.request import urlopen
import zipfile

BASELINE = 'https://github.com/TheEelYT/g1r-hns/releases/download/v0.7.21/hns_exploration-0.7.21.zip'
BASELINE_SHA256 = '21b689fa96639ad35065ca9bb75b34fcb214bcd5ed3e04f65565d379837b9bd7'


def check(mod, engine, luajit):
    with urlopen(BASELINE, timeout=120) as response:
        baseline = response.read()
    assert hashlib.sha256(baseline).hexdigest() == BASELINE_SHA256
    identical = 0
    with zipfile.ZipFile(io.BytesIO(baseline)) as archive:
        prefix = 'hns_exploration/'
        previous = {name[len(prefix):]: archive.read(name) for name in archive.namelist() if name.startswith(prefix) and not name.endswith('/')}
    missing = [name for name in previous if not (mod / name).is_file()]
    assert not missing, missing
    changed = []
    for name, data in previous.items():
        if Path(name).suffix.lower() in ('.lua', '.json', '.md'):
            continue
        if (mod / name).read_bytes() != data:
            changed.append(name)
        else:
            identical += 1
    assert not changed, changed
    with tempfile.TemporaryDirectory(prefix='hns-preservation-') as tmp:
        old_world = Path(tmp) / 'world.lua'
        old_world.write_bytes(previous['world.lua'])
        def read_world(path):
            return json.loads(subprocess.check_output([str(luajit), str(engine / 'tools/lua_to_json.lua'), str(path)], text=True))
        before, after = read_world(old_world), read_world(mod / 'world.lua')
    changes = [key for key in before if before[key] != after.get(key)]
    assert not changes, changes
    assert set(after) - set(before) == {'practice'}
    return {'result': 'pass', 'previous_release': 'v0.7.21', 'previous_zip_sha256': BASELINE_SHA256,
            'previous_non_code_assets_identical': identical, 'missing_previous_files': missing,
            'changed_previous_non_code_assets': changed, 'world_datasets_unchanged': len(before),
            'changed_world_datasets': changes, 'added_world_datasets': ['practice'],
            'maps_preserved': len(before['maps']), 'scripts_preserved': len(before['scripts'])}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('mod', 'engine', 'luajit', 'report'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    result = check(args.mod.resolve(), args.engine.resolve(), args.luajit.resolve())
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
