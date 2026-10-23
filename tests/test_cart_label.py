"""Render real XCF labels and exercise packaging with the native cart importer."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from cart_label import render_label
from release import package


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--luajit', type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / 'release/gbalabels.xcf'
    before = source.read_bytes()
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    version = manifest['version']
    parts = version.split('.')
    next_version = '.'.join(parts[:2] + [str(int(parts[2]) + 1)])
    with tempfile.TemporaryDirectory(prefix='hns-cart-label-test-') as temporary:
        stage = Path(temporary)
        first, second, longer = [stage / name for name in ('first.png', 'second.png', 'longer.png')]
        a = render_label(version, first)
        b = render_label(next_version, second)
        c = render_label('123.456.789', longer)
        for info in (a, b, c):
            assert info['font'] == 'Cascadia Mono Roman'
            assert info['text'] == 'Ver. ' + info['version']
            assert info['canvas'] == [1774, 887]
            assert info['bytes'] <= 1024 * 1024
            x1, y1, x2, y2 = info['text_bounds']
            assert 1384 <= x1 < x2 == 1714 and 775 <= y1 < y2 == 831
        with Image.open(first) as one, Image.open(second) as two, Image.open(longer) as three:
            for other in (two, three):
                difference = ImageChops.difference(one.convert('RGB'), other.convert('RGB')).getbbox()
                assert difference, 'The visible number must change; wrapped-away text is a regression'
                assert difference[0] >= 1384 and difference[1] >= 775
                assert difference[2] <= 1714 and difference[3] <= 831
        # A fixture mod avoids rebuilding unrelated game assets for a label-only
        # change. package() still calls the actual G1R parser/importer/save tests.
        mod = stage / 'mod'
        mod.mkdir()
        (mod / 'manifest.json').write_text(json.dumps(manifest))
        (mod / 'README.md').write_bytes((ROOT / 'README.md').read_bytes())
        (mod / 'main.lua').write_text('return {}\n')
        out = stage / 'dist'
        result = package(mod, out, args.engine.resolve(), args.luajit.resolve())
        assert result['result'] == 'pass'
        assert (out / 'pokemon-heart-soul.png').read_bytes() == first.read_bytes()
        original_files = {entry['name']: (out / entry['name']).read_bytes() for entry in result['files']}
        # Both the PNG and cart must stay reproducible when packaged again.
        again = package(mod, out, args.engine.resolve(), args.luajit.resolve())
        assert result == again
        for name, data in original_files.items():
            assert (out / name).read_bytes() == data
        release = json.loads((out / 'release.json').read_text())
        assert release['label'] == a
        zip_path = out / (manifest['id'] + '-' + version + '.zip')
        with zipfile.ZipFile(zip_path) as archive:
            assert archive.read(manifest['id'] + '/main.lua') == b'return {}\n'
            assert not any(name.endswith(('.xcf', '.ttf')) for name in archive.namelist())
        assert hashlib.sha256(zip_path.read_bytes()).hexdigest() == result['files'][1]['sha256']
    assert source.read_bytes() == before, 'Rendering must preserve the editable master XCF'
    print('Cart labels: visible version changes, long-version fit, artwork isolation, source preservation, deterministic PNG/cart/ZIP and native import/save/seal checks pass')


if __name__ == '__main__':
    main()
