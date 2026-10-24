"""Locate repeatable, unobstructed walking strips in the converted source maps.

These are opt-in development shortcuts in a separate practice save, not new
story warps or edits to any source layout/event.
"""

TARGETS = (
    ('sand', 'Sand', 'MB_SAND'),
    ('deep_sand', 'Deep sand', 'MB_DEEP_SAND'),
    ('puddle', 'Puddles', 'MB_PUDDLE'),
    ('short_grass', 'Short grass', 'MB_SHORT_GRASS'),
    ('shallow_water', 'Shallow water', 'MB_SHALLOW_WATER'),
    ('hot_springs', 'Hot springs', 'MB_HOT_SPRINGS'),
    ('ice', 'Ice', 'MB_ICE'),
)


def build(maps, raw_maps, pairs):
    destinations = []
    for key, label, behavior in TARGETS:
        found = None
        # Prefer a recognisable town over a route, then a stable map/id order.
        for mapid, m in sorted(maps.items(), key=lambda row: (row[1]['kind'] != 'town', row[0])):
            if not m.get('hnsSourceId') or m.get('hnsRegion') not in ('REGION_JOHTO', 'REGION_KANTO'):
                continue
            if any(name in m['hnsSourceId'] for name in ('TEST', 'UNUSED', 'DEBUG')):
                continue
            words, layout = raw_maps[mapid]
            width, height = layout['width'], layout['height']
            blocked = [(o['x'], o['y']) for group in ('objects', 'warps', 'coordEvents', 'bgEvents') for o in m.get(group, [])]
            def at(x, y):
                word = words[y * width + x]
                return word, pairs[m['pair']].definition(word & 1023)[1]
            for y in range(2, height - 2):
                for x in range(3, width - 3):
                    strip = [at(x + dx, y) for dx in range(-2, 3)]
                    elevation = strip[0][0] >> 12
                    if not all(b == behavior and (word >> 10) & 3 == 0 and word >> 12 == elevation for word, b in strip):
                        continue
                    if any(abs(bx - x) <= 4 and abs(by - y) <= 2 for bx, by in blocked):
                        continue
                    found = {'id': key, 'label': label, 'behavior': behavior, 'map': mapid,
                             'name': m['name'].replace('_', ' ').upper(), 'x': x, 'y': y,
                             'facing': 'left', 'elevation': elevation, 'radius': 2}
                    break
                if found:
                    break
            if found:
                break
        if found:
            destinations.append(found)
    return {'destinations': destinations, 'limits': 'Dry, passable five-tile walking strips only. Seaweed, pond/bridge reflections and controlled weather are not supplied.'}
