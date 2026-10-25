"""Independently audit practice destinations against source blockdata/events."""
import json
import struct


def check(source, mod, world):
    layouts = {row['id']: row for row in json.loads((source / 'data/layouts/layouts.json').read_text())['layouts']}
    maps = {row['id']: row for row in (json.loads(p.read_text()) for p in (source / 'data/maps').glob('*/map.json'))}
    checked = 0
    for row in world['practice']['destinations']:
        m = world['maps'][row['map']]
        src = maps[m['hnsSourceId']]
        assert not any(x in src['id'] for x in ('TEST', 'UNUSED', 'DEBUG'))
        layout = layouts[src['layout']]
        raw = (source / layout['blockdata_filepath']).read_bytes()
        words = struct.unpack('<' + str(len(raw) // 2) + 'H', raw)
        data = (mod / m['hnsLayoutFile']).read_bytes()
        assert data[:4] == b'SVML'
        cells = [(row['x'] + dx, row['y'] + dy) for dy in range(3 if row['id'] == 'ice' else 1) for dx in range(-2, 3)]
        for x, y in cells:
            assert 0 < x < layout['width'] - 1 and 0 < y < layout['height'] - 1
            pos = y * layout['width'] + x
            word = words[pos]
            assert word >> 10 & 3 == 0
            assert word >> 12 == row['elevation']
            assert world['pairs'][m['pair']]['behaviors'][str(word & 1023)] == row['behavior']
            # Converted bytes must preserve the independently read source cell.
            assert struct.unpack_from('<HBB', data, 24 + 4 * pos) == (word & 1023, 0, word >> 12)
            checked += 1
        for group in ('objects', 'warps', 'coordEvents', 'bgEvents'):
            assert not any(abs(o['x'] - row['x']) <= 4 and abs(o['y'] - row['y']) <= 2 for o in m.get(group, []))
    assert {'sand', 'short_grass', 'shallow_water', 'ice'} <= {d['id'] for d in world['practice']['destinations']}
    return {'practice_source_walking_cells': checked, 'practice_destinations': len(world['practice']['destinations'])}
