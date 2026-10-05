#!/usr/bin/env python3
"""Build a private native Gen1Recomp HnS exploration mod from HnS source.

No GBA compiler or ROM is needed for this source-data milestone. The UPS is
inspected separately; this does not pretend to execute the hack's C code.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zlib

PIN_HNS = "167aa6d537b109bb229c231ddce4616974c4da71"
PIN_ENGINE = "20ab97abf8092c37344d108f2136ec4e5d131500"
EARLY_PREFIXES = ("NewBarkTown", "Route29", "CherrygroveCity", "Route30")
OPENING_PREFIXES = EARLY_PREFIXES + (
    "Route31", "VioletCity", "SproutTower", "Route27", "TohjoFalls",
    "Route46", "DarkCave", "Gate_Route31_VioletCity", "Gate_Route29_Route46",
)
OPENING_EXCLUSIONS = {}
# Reviewed source errata: this layout declares Emerald while using the HnS
# 640-tile primary atlas and HnS-indexed metatiles. No other explicit version
# is inferred from a map's game_version.
LAYOUT_VERSION_FIXUPS = {"LAYOUT_UNION_ROOM_HNS": "hns"}
SHARED_MAP_IDS = {"MAP_UNION_ROOM", "MAP_TRADE_CENTER", "MAP_ARTISAN_CAVE_B1F", "MAP_ARTISAN_CAVE_1F"}
# The HnS Frontier's doorway lists differ from the retained Emerald cave exits.
# Match each cave to the actual reciprocal HnS entrance, rather than importing
# vanilla Hoenn or landing at a different building's doorway.
WARP_FIXUPS = {
    ("MAP_ARTISAN_CAVE_B1F", 0): ("MAP_BATTLE_FRONTIER_OUTSIDE_WEST_HNS", 9),
    ("MAP_ARTISAN_CAVE_1F", 0): ("MAP_BATTLE_FRONTIER_OUTSIDE_EAST_HNS", 12),
}
HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0,str(HERE))
import opening
import world_events
import world_encounters
import world_trainers
import quest
import scenes
import pokedex
import residents
import audio
import campaign
import field_pokemon
import field_presentation
import startup
import followers
import boot_assets
import battle_assets
import expanded_moves


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def u16s(path):
    data = path.read_bytes()
    if len(data) % 2:
        raise ValueError(f"odd-sized u16 table: {path}")
    return list(struct.unpack(f"<{len(data)//2}H", data))


def safe_source(root, rel):
    path = (root / rel).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"source path escapes repository: {rel}")
    return path


def lua(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in sorted(value.items(), key=lambda x: str(x[0]))) + "}"
    raise TypeError(type(value))


def symbols(root):
    paths = {}
    for filename in ("graphics.h", "metatiles.h"):
        text = (root / "src/data/tilesets" / filename).read_text()
        for symbol, rel in re.findall(r"\b(g\w+)\[\]\s*=\s*INCBIN_\w+\(\"([^\"]+)\"\)", text):
            paths[symbol] = rel
    headers = (root / "src/data/tilesets/headers.h").read_text()
    result = {}
    for name, block in re.findall(r"const struct Tileset\s+(\w+)\s*=\s*\{(.*?)\};", headers, re.S):
        fields = dict(re.findall(r"\.(\w+)\s*=\s*(\w+)", block))
        mt = safe_source(root, paths[fields["metatiles"]])
        result[name] = {"dir": mt.parent, "mt": mt,
                        "attrs": safe_source(root, paths[fields["metatileAttributes"]]),
                        "callback": fields.get("callback", "NULL")}
    return result


def enum_names(path, prefix):
    """Parse the simple enum in metatile_behaviors.h (reject nonliteral expressions)."""
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(), flags=re.S)
    out, value = {}, -1
    for name, assigned in re.findall(r"\b(" + re.escape(prefix) + r"\w+)\s*(?:=\s*([^,}\n]+))?", text):
        value = int(assigned.strip(), 0) if assigned.strip() else value + 1
        out[value] = name
    return out


def parse_palette(path):
    rows = path.read_text().splitlines()
    if len(rows) < 3 or rows[:2] != ["JASC-PAL", "0100"] or not rows[2].isdigit() or not 1 <= int(rows[2]) <= 16:
        raise ValueError(f"unexpected palette format: {path}")
    count = int(rows[2])
    colors = [tuple(map(int, s.split())) for s in rows[3:3+count]]
    if len(colors) != count or any(len(c) != 3 or any(v < 0 or v > 255 for v in c) for c in colors):
        raise ValueError(f"bad palette: {path}")
    # INCBIN_U16 in a source u16[][16] initializer zero-fills unused colors.
    return [(r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10) for r, g, b in colors] + [0] * (16-count)


def layout_profile(layout):
    version = LAYOUT_VERSION_FIXUPS.get(layout["id"],layout.get("layout_version","emerald"))
    if version not in ("emerald","frlg","hns"):
        raise ValueError(f"unknown layout version {version}: {layout['id']}")
    return (512,6) if version == "emerald" else (640,7)


class Tileset:
    def __init__(self, spec):
        from PIL import Image
        self.spec = spec
        image = Image.open(spec["dir"] / "tiles.png")
        if image.mode != "P" or image.width % 8 or image.height % 8:
            raise ValueError(f"tiles.png must be an indexed 8px grid: {spec['dir']}")
        self.width, self.height = image.size
        self.pixels = image.tobytes()
        if max(self.pixels) > 15:
            raise ValueError(f"tiles.png contains non-4bpp indices: {spec['dir']}")
        self.count = self.width // 8 * (self.height // 8)
        self.blank_placeholders = set()
        # One unfilled foreground placeholder beyond this source PNG. Use
        # transparent tile pixels so its existing source floor remains visible;
        # keep this exception specific and reject all other visible holes.
        if spec["dir"].name == "route38_farmland_hns":
            self.blank_placeholders.add(275)
        self.entries = u16s(spec["mt"])
        attr_bytes = spec["attrs"].read_bytes()
        count = len(self.entries) // 8
        if len(self.entries) % 8 or len(attr_bytes) not in (count * 2, count * 4):
            raise ValueError(f"metatile attribute count mismatch: {spec['dir']}")
        self.attr_width = len(attr_bytes) // count
        self.attrs = list(struct.unpack("<" + ("H" if self.attr_width == 2 else "I") * count, attr_bytes))

    def pixel(self, tid, x, y):
        if tid in self.blank_placeholders:
            return 0
        if not 0 <= tid < self.count:
            raise ValueError(f"tile {tid} is outside {self.count} tiles in {self.spec['dir']}")
        px = tid % (self.width // 8) * 8 + x
        py = tid // (self.width // 8) * 8 + y
        return self.pixels[py * self.width + px]


class Pair:
    def __init__(self, primary, secondary, n_primary, n_pals, names):
        self.primary, self.secondary = primary, secondary
        self.n_primary, self.n_pals, self.names = n_primary, n_pals, names
        self.palettes = []
        self.occluded_source_tiles = set()
        for slot in range(16):
            ts = primary if slot < n_pals else secondary
            p = ts.spec["dir"] / "palettes" / f"{slot:02d}.pal"
            self.palettes.append(parse_palette(p) if p.exists() and slot < 13 else [0] * 16)
        # HnS fieldmap.c:LoadTilesetPalette forces the first primary BG
        # entry to RGB_BLACK after copying the source palettes. It is the
        # backdrop for transparent tile pixels, not a source artwork color.
        # Native Palette.load enforces the same invariant. Keep every other
        # entry intact and leave parse_palette unchanged for NPC sheets.
        self.palettes[0][0] = 0

    def definition(self, mid):
        ts = self.primary if mid < self.n_primary else self.secondary
        local = mid if mid < self.n_primary else mid - self.n_primary
        if not 0 <= local < len(ts.attrs):
            raise ValueError(f"metatile {mid:#x} is outside tileset table")
        attr = ts.attrs[local]
        behavior = attr & (0xFF if ts.attr_width == 2 else 0x1FF)
        layer = attr >> (12 if ts.attr_width == 2 else 29) & (15 if ts.attr_width == 2 else 3)
        if layer not in (0, 1, 2):
            raise ValueError(f"unsupported metatile layer {layer} for {mid:#x}")
        return ts.entries[local * 8:local * 8 + 8], self.names.get(behavior, f"HNS_UNKNOWN_{behavior}"), layer

    def half(self, entries, layer, covered_by=None):
        buf = bytearray(256)
        for slot, e in enumerate(entries[layer*4:layer*4+4]):
            tid, pal = e & 1023, e >> 12
            ts = self.primary if tid < self.n_primary else self.secondary
            local = tid if tid < self.n_primary else tid - self.n_primary
            ox, oy = slot % 2 * 8, slot // 2 * 8
            for y in range(8):
                for x in range(8):
                    position = (oy+y)*16+ox+x
                    # Some source tables reference absent lower-layer padding
                    # tiles. Only skip missing pixels when the exact source
                    # foreground pixel is opaque; an exposed hole still fails.
                    if covered_by is not None and local >= ts.count and local not in ts.blank_placeholders and covered_by[position]:
                        self.occluded_source_tiles.add((str(ts.spec["dir"]),local))
                        continue
                    color = ts.pixel(local, 7-x if e & 1024 else x, 7-y if e & 2048 else y)
                    buf[position] = (pal*16+color) if color else 0
        return buf

    def layers(self, mid):
        entries, _, lt = self.definition(mid)
        top = self.half(entries, 1)
        bottom = self.half(entries, 0, top)
        under = bytearray(bottom)
        if lt == 1:
            for i, b in enumerate(top):
                if b:
                    under[i] = b
        over = bytearray(256) if lt == 1 else top
        middle = bottom if lt == 0 else top if lt == 1 else bytearray(256)
        return under, over, middle

    def palettes_blob(self):
        return b"SVMP" + bytes((1, self.n_pals, 13, 0)) + struct.pack("<256H", *(c for p in self.palettes for c in p))


def idx_blob(mids, pixels):
    return b"SVMI" + struct.pack("<BBHHH", 1, 2, len(mids), 16, math.ceil(len(mids)/16)) + struct.pack(f"<{len(mids)}H", *mids) + b"".join(pixels)


def layout_blob(width, height, words, border):
    if len(words) != width*height or len(border) != 4:
        raise ValueError("layout dimensions/border size disagree with binary files")
    # Keep the source collision bits here. Runtime translates through the engine's
    # RSE collision classifier after it resolves named metatile behaviors.
    cells = b"".join(struct.pack("<HBB", w & 1023, w >> 10 & 3, w >> 12) for w in words)
    return b"SVML" + struct.pack("<BBHHHHBB", 1, 0, width, height, width, height, 2, 2) + struct.pack("<4H", *(w & 1023 for w in border)) + cells


def source_labels(root):
    labels = {}
    for path in sorted((root / "data/maps").glob("*/scripts.inc")) + [root / "data/scripts/movement.inc"]:
        current = None
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.match(r"^(\w+)::?\s*$", line)
            if match:
                current = match[1]
                labels.setdefault(current, [])
            elif current:
                labels[current].append(line.strip())
    return labels


def simple_sign(label, labels):
    rows = [s.split("@", 1)[0].strip() for s in labels.get(label, [])]
    rows = [s for s in rows if s]
    target = None
    allowed = {"msgbox", "end", "closemessage", "release", "releaseall", "lock", "lockall"}
    for s in rows:
        op = s.split()[0]
        if op not in allowed:
            return None
        if op == "msgbox":
            if target is not None:
                return None
            target = s.split(None, 1)[1].split(",")[0].strip()
    if not target or not rows or rows[-1] not in ("end", "releaseall"):
        return None
    chunks = []
    for s in labels.get(target, []):
        m = re.fullmatch(r'\.string\s+"(.*)"', s)
        if m:
            chunks.append(m[1].replace(r'\"', '"'))
        elif s and not s.startswith("@"):  # no guessed text/macro expansion
            return None
    return "".join(chunks).split("$", 1)[0] if chunks else None


def ups_info(path):
    data = path.read_bytes()
    if len(data) < 18 or data[:4] != b"UPS1":
        raise ValueError("not a UPS patch")
    expected = struct.unpack("<I", data[-4:])[0]
    if zlib.crc32(data[:-4]) != expected:
        raise ValueError("UPS patch checksum mismatch")
    offset, sizes = 4, []
    for _ in range(2):
        value, shift = 0, 0
        while True:
            if offset >= len(data)-12 or shift > 56:
                raise ValueError("malformed UPS size")
            b = data[offset]; offset += 1
            value += (b & 127) << shift
            if b & 128:
                break
            shift += 7
            value += 1 << shift
        sizes.append(value)
    source, output, patch = struct.unpack("<III", data[-12:])
    return {"filename": path.name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "source_size": sizes[0], "output_size": sizes[1], "source_crc32": f"{source:08x}",
            "output_crc32": f"{output:08x}", "patch_crc32": f"{patch:08x}", "patch_crc_valid": True,
            "used_for": "identity check only; no ROM reconstruction or execution"}


def revision(root):
    return subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()


def audit(root, maps, engine):
    commands, natives, specials = collections.Counter(), collections.Counter(), collections.Counter()
    for m in maps:
        path = root / "data/maps" / m["name"] / "scripts.inc"
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            s = line.split("@", 1)[0].strip()
            if not s or s.startswith(".") or re.match(r"^\w+::?$", s):
                continue
            op = s.split()[0]
            commands[op] += 1
            if op in ("callnative", "special", "specialvar"):
                target = s.split(None, 1)[1].split(",")[-1].strip()
                (natives if op == "callnative" else specials)[target] += 1
    return {"hns_revision": revision(root), "engine_revision": revision(engine), "hns_map_count": len(maps),
            "script_scan_scope": "HnS map scripts.inc files; shared includes/macros/C transitively referenced are not counted",
            "commands": dict(commands.most_common()), "callnative_targets": dict(natives.most_common()),
            "special_targets": dict(specials.most_common()),
            "campaign_status": "complete map data; source opening, Sprout Tower and Violet Gym bridges; compatible world battles; later campaign in progress"}


def render_map(pair, words, width, height, path):
    from PIL import Image
    image = Image.new("RGB", (width*16, height*16))
    colors = [(round((c & 31)*255/31), round((c >> 5 & 31)*255/31), round((c >> 10 & 31)*255/31)) for p in pair.palettes for c in p]
    cache = {}
    for i, w in enumerate(words):
        mid = w & 1023
        if mid not in cache:
            under, over, _ = pair.layers(mid)
            pix = [over[j] or under[j] for j in range(256)]
            tile = Image.new("RGB", (16,16)); tile.putdata([colors[v] for v in pix]); cache[mid] = tile
        image.paste(cache[mid], (i % width*16, i // width*16))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def build(args):
    source, engine = args.source.resolve(), args.engine.resolve()
    if not args.allow_other_revisions and (revision(source) != PIN_HNS or revision(engine) != PIN_ENGINE):
        raise ValueError("source revisions differ from tested pins; check out the README revisions or use --allow-other-revisions explicitly")
    all_maps = [json.loads(p.read_text()) for p in sorted((source / "data/maps").glob("*/map.json"))]
    hns = [m for m in all_maps if m.get("game_version") == "hns"]
    prefixes = EARLY_PREFIXES if args.scope == "early" else OPENING_PREFIXES
    maps = hns if args.scope == "all" else [m for m in hns if m["name"].startswith(prefixes)]
    if args.scope == "all":
        maps = maps + [m for m in all_maps if m["id"] in SHARED_MAP_IDS]
    source_maps = {m["id"]: m for m in all_maps}
    exclusions = OPENING_EXCLUSIONS if args.scope == "opening" else {}
    maps = [m for m in maps if m["id"] not in exclusions]
    if not maps:
        raise ValueError("no HnS maps selected")
    layouts = {x["id"]: x for x in json.loads((source / "data/layouts/layouts.json").read_text())["layouts"]}
    specs, behavior_names = symbols(source), enum_names(source / "include/constants/metatile_behaviors.h", "MB_")
    selected = {m["id"]: "EM_HNS_" + m["id"].removeprefix("MAP_") for m in maps}
    labels = source_labels(source)
    out = args.out.resolve()
    if out.exists():
        raise ValueError(f"output already exists; choose a fresh --out: {out}")
    stage = out.with_name(out.name + ".building")
    if stage.exists():
        raise ValueError(f"incomplete staging directory exists: {stage}")
    stage.mkdir(parents=True)
    sets, pair_defs, pairs, pair_mids, packed_maps = {}, {}, {}, collections.defaultdict(set), {}
    text, scripts, omitted = {}, {}, []
    raw_maps = {}
    type_values = {"MAP_TYPE_NONE": 0, "MAP_TYPE_TOWN": 1, "MAP_TYPE_CITY": 2, "MAP_TYPE_ROUTE": 3,
                   "MAP_TYPE_UNDERGROUND": 4, "MAP_TYPE_UNDERWATER": 5, "MAP_TYPE_OCEAN_ROUTE": 6,
                   "MAP_TYPE_INDOOR": 8, "MAP_TYPE_SECRET_BASE": 9}
    try:
        shutil.copytree(HERE / "runtime", stage, dirs_exist_ok=True)
        shutil.copy2(HERE / "README.md", stage / "README.md")
        shutil.copy2(source / "CREDITS.md", stage / "HNS_UPSTREAM_CREDITS.md")
        for m in maps:
            mapid = selected[m["id"]]; layout = layouts[m["layout"]]
            n_primary, n_pals = layout_profile(layout)
            names = (layout["primary_tileset"], layout["secondary_tileset"])
            pairid = "hns_" + hashlib.sha256(("|".join(names)+f"|{n_primary}").encode()).hexdigest()[:16]
            if pairid not in pairs:
                for name in names:
                    if name not in sets:
                        sets[name] = Tileset(specs[name])
                pairs[pairid] = Pair(sets[names[0]],sets[names[1]],n_primary,n_pals,behavior_names)
            pair_defs[pairid] = {"primary": names[0], "secondary": names[1], "behaviors": {},
                                     "animations": [specs[name]["callback"] for name in names]}
            words = u16s(safe_source(source, layout["blockdata_filepath"]))
            border = u16s(safe_source(source, layout["border_filepath"]))
            pair_mids[pairid].update(w & 1023 for w in words+border)
            if m["id"] == "MAP_NEW_BARK_TOWN_LAB_HNS":
                # Referenced by the source theft scene, absent from base layout.
                label=re.search(r"#define METATILE_R26_21_Broken_Window\s+(0x[0-9A-Fa-f]+)",(source/"include/constants/metatile_labels.h").read_text())
                pair_mids[pairid].add(int(label[1],16))
            rel = f"native/layouts/{mapid}.mid"
            target = stage / rel; target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(layout_blob(layout["width"],layout["height"],words,border))
            warps = []
            for index,w in enumerate(m.get("warp_events",[])):
                common = {"x":w["x"],"y":w["y"],"elevation":w["elevation"],"sourceIndex":index}
                if not (0 <= w["x"] < layout["width"] and 0 <= w["y"] < layout["height"]):
                    omitted.append({"map":mapid,"kind":"out-of-bounds source warp","index":index}); continue
                if w["dest_map"] == "MAP_DYNAMIC":
                    warps.append(dict(common, mapNum=127, destWarp=0))
                    continue
                dest_id, fixed_index = WARP_FIXUPS.get((m["id"],index),(w["dest_map"],None))
                if dest_id in selected:
                    # Explicit destination coordinates keep original zero-based warp indices
                    # intact even when an unavailable debug warp is omitted in the slice.
                    dest = source_maps[dest_id]
                    dest_index = fixed_index if fixed_index is not None else int(w["dest_warp_id"],0)
                    if not 0 <= dest_index < len(dest.get("warp_events",[])):
                        omitted.append({"map":mapid,"kind":"unresolved source warp","index":index,"target":dest_id,"targetIndex":dest_index}); continue
                    dw = dest["warp_events"][dest_index]
                    destination_layout = layouts[dest["layout"]]
                    if not (0 <= dw["x"] < destination_layout["width"] and 0 <= dw["y"] < destination_layout["height"]):
                        omitted.append({"map":mapid,"kind":"out-of-bounds source arrival","index":index,"target":dest_id,"targetIndex":dest_index}); continue
                    warps.append(dict(common,destMap=selected[dest_id],destWarp=0,destX=dw["x"],destY=dw["y"]))
                else:
                    omitted.append({"map":mapid,"kind":"warp outside slice","index":index,"target":w["dest_map"]})
            conns = []
            for c in m.get("connections") or []:
                if c["map"] in selected:
                    conns.append({"dir":{"up":"north","down":"south","left":"west","right":"east"}.get(c["direction"],c["direction"]),
                                  "map":selected[c["map"]],"offset":c["offset"]})
                else:
                    omitted.append({"map":mapid,"kind":"connection outside slice","target":c["map"]})
            bg = []
            for i,e in enumerate(m.get("bg_events",[])):
                s = simple_sign(e.get("script",""),labels) if e["type"]=="sign" else None
                if s is None:
                    omitted.append({"map":mapid,"kind":"unported background event","index":i}); continue
                sid,tid = f"HNS_PORT_SIGN_{mapid}_{i}",f"HNS_PORT_TEXT_{mapid}_{i}"
                text[tid] = s
                scripts[sid] = [{"op":"lockall"},{"op":"message","ptr":tid},{"op":"waitmessage"},
                                {"op":"waitbuttonpress"},{"op":"closemessage"},{"op":"releaseall"},{"op":"end"}]
                bg.append({"x":e["x"],"y":e["y"],"elevation":e["elevation"],"kind":0,"scriptKey":sid})
            mt = type_values[m["map_type"]]
            packed_maps[mapid] = {"id":mapid,"name":m["name"].removesuffix("_hns"),"width":layout["width"],"height":layout["height"],
                "kind":"indoor" if mt in (4,8,9) else "route" if mt in (3,5,6) else "town",
                "environment":"INDOOR" if mt in (4,8,9) else "ROUTE" if mt in (3,5,6) else "TOWN",
                "native":True,"pair":pairid,"warps":warps,"connections":conns,"objects":[],"bgEvents":bg,
                "coordEvents":[],"mapScripts":{},"music":0,"weather":0,"mapType":mt,
                "allowRunning":int(m["allow_running"]),"allowEscaping":int(m["allow_escaping"]),"bikingAllowed":int(m["allow_cycling"]),
                "showMapName":0,"borderWidth":2,"borderHeight":2,"hnsLayoutFile":rel}
            packed_maps[mapid]["hnsSourceId"] = m["id"]
            packed_maps[mapid]["hnsRegion"] = m.get("region", "REGION_HOENN")
            raw_maps[mapid] = (words,layout)
        for pairid,pair in sorted(pairs.items()):
            mids = sorted(pair_mids[pairid]); pixel_layers = [[],[],[]]
            for mid in mids:
                _,beh,_ = pair.definition(mid)
                pair_defs[pairid]["behaviors"][str(mid)] = beh
                for i,buf in enumerate(pair.layers(mid)):
                    pixel_layers[i].append(bytes(buf))
            d = stage / "native" / pairid; d.mkdir(parents=True)
            for filename,pix in zip(("mids.idx","mids_over.idx","mids_mid.idx"),pixel_layers):
                (d / filename).write_bytes(idx_blob(mids,pix))
            (d / "palettes.bin").write_bytes(pair.palettes_blob())
        import tile_animation
        animation_data=tile_animation.build(source,engine,stage,pairs,pair_mids,pair_defs,lua,parse_palette)
        opening_data = opening.build(source,stage,packed_maps,text,scripts,labels,parse_palette)
        events_data = world_events.build(source,engine,stage,packed_maps,source_maps,text,scripts,labels,opening_data,parse_palette)
        encounter_data = world_encounters.build(source,engine,packed_maps)
        prepared_trainers=world_trainers.prepare(source,engine)
        trainer_data = world_trainers.build(source,engine,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,prepared_trainers)
        quest_data=quest.build(source,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,trainer_data,prepared_trainers,events_data["marts"])
        scenes.build(source,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,quest_data)
        dex_data=pokedex.build(source,stage,prepared_trainers["known"]["species"])
        residents.build(source,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,events_data,quest_data)
        campaign_data=campaign.build(source,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,trainer_data,prepared_trainers,quest_data)
        field_mon_data=field_pokemon.build(source,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,prepared_trainers['known']['species'])
        startup.speech_module(engine,stage)
        startup_data=startup.build(source,engine,stage,packed_maps,source_maps,labels,text,scripts,opening_data,parse_palette,quest_data)
        presentation_data=field_presentation.build(source,stage,packed_maps,source_maps,layouts,parse_palette)
        import service_assets
        services=service_assets.build(source,engine,stage,pairs,packed_maps,source_maps,text,scripts,opening_data,lua,parse_palette)
        expanded_data=expanded_moves.build(source,engine)
        battle_data=battle_assets.build(source,engine,stage,packed_maps,source_maps)
        boot_data=boot_assets.build(source,engine,stage)
        follower_data=followers.build(source,engine,stage,opening_data,scripts,parse_palette)
        audio_data=audio.build(source,engine,stage,packed_maps,source_maps,trainer_data,prepared_trainers,scripts)
        imported_objects={(mid,o["localId"]-1) for mid,m in packed_maps.items() for o in m["objects"]}
        events_data["omittedObjects"]=[o for o in events_data["omittedObjects"] if (o["map"],o["sourceIndex"]) not in imported_objects]
        events_data["spriteCount"]=len(opening_data["sprites"])
        data = {"format":1,"scope":args.scope,"maps":packed_maps,"pairs":pair_defs,"text":text,"scripts":scripts,"opening":opening_data,"worldEvents":events_data,
                "encounters":encounter_data,"trainers":trainer_data,"quest":quest_data,"pokedex":dex_data,"audio":audio_data,"campaign":campaign_data,"fieldPokemon":field_mon_data,"presentation":presentation_data,"startup":startup_data,
                "expandedMoves":expanded_data,"battleVisuals":battle_data,"bootPresentation":boot_data,"followers":follower_data,"animations":animation_data,"services":services,"start":{"map":"EM_HNS_NEW_BARK_TOWN_HNS","x":20,"y":12,"facing":"down"}}
        # LuaJIT limits one function to 65,536 constants. Compile independent
        # top-level datasets in their own functions as this port grows.
        world_lua="-- Private source-converted data. Rebuild with build_port.py.\nlocal world={}\n"
        for key,value in data.items():
            world_lua+="world["+lua(key)+"]=(function() return "+lua(value)+" end)()\n"
        (stage / "world.lua").write_text(world_lua+"return world\n",encoding="utf-8")
        report = audit(source,hns,engine)
        report.update({"scope":args.scope,"built_map_count":len(maps),"built_pair_count":len(pairs),"ported_sign_count":sum(s.startswith("HNS_PORT_SIGN_") for s in scripts),
                       "built_hns_map_count":sum(m.get("game_version")=="hns" for m in maps),"shared_map_ids":sorted(SHARED_MAP_IDS) if args.scope=="all" else [],
                       "warp_count":sum(len(m["warps"]) for m in packed_maps.values()),"dynamic_warp_count":sum(w.get("mapNum")==127 for m in packed_maps.values() for w in m["warps"]),
                       "connection_count":sum(len(m["connections"]) for m in packed_maps.values()),
                       "warp_fixups":[{"map":m,"sourceIndex":i,"destination":d,"destinationIndex":j} for (m,i),(d,j) in sorted(WARP_FIXUPS.items())] if args.scope=="all" else [],
                       "source_asset_repairs":{"layout_versions":LAYOUT_VERSION_FIXUPS,"transparent_placeholders":{"route38_farmland_hns":[275]},
                          "fully_occluded_missing_lower_tiles":[{"tileset":str(Path(path).relative_to(source)),"tile":tile} for path,tile in sorted({v for pair in pairs.values() for v in pair.occluded_source_tiles})]},
                       "opening_npc_count":opening_data["npcCount"],"native_sprite_count":len(opening_data["sprites"]),"opening_limits":opening_data["limits"],
                       "total_object_count":sum(len(m['objects']) for m in packed_maps.values()),
                       "startup":{"settings_pages":len(startup_data['settings']['pages']),"settings_rows":startup_data['settings']['choiceCount'],"extra_objects":startup_data['extraObjectCount'],"center_clocks":startup_data['centerClockCount'],"banner_themes":len(startup_data['popupPalettes']),"limits":startup_data['limits']},
                       "world_dialogue_npc_count":events_data["dialogueNpcCount"],"nurse_count":len(events_data["nurses"]),"heal_checkpoint_count":len(events_data["healCheckpoints"]),
                       "field_pokemon_count":len(field_mon_data['objects']),"field_pokemon_omissions":field_mon_data['omitted'],"field_pokemon_interaction_limits":field_mon_data['unportedInteractions'],
                       "mart_clerk_count":len(events_data["marts"]["clerks"]),"mart_omissions":events_data["marts"]["omitted"],
                       "wild_map_count":len(encounter_data["tables"]),"wild_area_count":sum(map(len,encounter_data["tables"].values())),"wild_omissions":encounter_data["omitted"],
                       "trainer_event_count":len(trainer_data["events"]),"trainer_roster_count":len(trainer_data["records"]),"trainer_omissions":trainer_data["omitted"],
                       "audio":{"song_count":audio_data["songCount"],"sample_bytes":audio_data["sampleBytes"],"source_fingerprint":audio_data["sourceFingerprint"],"sound_mode":audio_data["soundMode"],"format":"native M4A source sequences and instruments"},
                       "campaign":{"battles":campaign_data["battles"],"objects":campaign_data["objects"],"pickups":campaign_data["pickups"],"flags":campaign_data["flags"],"vars":campaign_data["vars"],"roost_item":campaign_data["roostItem"],"roost_move":campaign_data["roostMove"]},
                       "quest_limits":quest_data["limits"],
                       "expansion":{"compatible_expanded_moves":len(expanded_data['moves']),"unsupported_expanded_moves":len(expanded_data['omitted']),"follower_species_forms":len(follower_data['species']),"follower_sheets":len(follower_data['species'])*2,"battle_terrain_configurations":len(battle_data['terrains']),"active_rule_feature_settings":len(startup_data['rules']['implemented']),"timed_encounter_maps":len(encounter_data['timed']),"battle_limits":expanded_data['limits'],"follower_limits":follower_data['limits'],"tint_limits":"Ordinary 5-bit outdoor field tint; source palette-bank light immunity and alternate-light high bits remain pending."},
                       "omitted_world_objects":events_data["omittedObjects"],
                       "excluded_maps":exclusions,"omitted_slice_events":omitted,"ups":ups_info(args.ups) if args.ups else None})
        write_json(stage / "build_report.json",report)
        # Fail atomically on any conversion error: never install a half-built world.
        stage.rename(out)
    except BaseException:
        shutil.rmtree(stage)
        raise
    if args.previews:
        opening.preview_sprites(out,{"sprites":{k:v for k,v in opening_data["sprites"].items() if int(k)<0xE006}},args.previews)
        for mid in ("EM_HNS_NEW_BARK_TOWN_HNS","EM_HNS_ROUTE29_HNS","EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_2F_HNS",
                    "EM_HNS_ROUTE31_HNS","EM_HNS_ROUTE27_HNS","EM_HNS_VIOLET_CITY_HNS",
                    "EM_HNS_GOLDENROD_CITY_HNS","EM_HNS_CIANWOOD_CITY_HNS","EM_HNS_ROUTE38_HNS",
                    "EM_HNS_VIOLET_CITY_TRAINER_SCHOOL_HNS","EM_HNS_MELEMELE_ISLE_HNS",
                    "EM_HNS_FUCHSIA_CITY_SAFARI_ZONE_BEACH_HNS","EM_HNS_SINJOH_RUINS_HNS",
                    "EM_HNS_ARTISAN_CAVE_B1F","EM_HNS_BATTLE_PYRAMID_SQUARE01_HNS"):
            if mid in raw_maps:
                words,lay = raw_maps[mid]
                render_map(pairs[packed_maps[mid]["pair"]],words,lay["width"],lay["height"],args.previews / f"{mid}.png")
    print(json.dumps({"mod_directory":str(out),"maps":len(maps),"tileset_pairs":len(pairs),"signs":sum(s.startswith("HNS_PORT_SIGN_") for s in scripts),
                      "hns_maps_total":len(hns),"campaign":"opening, Sprout Tower and Violet Gym with source music; later campaign in progress"}))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source",required=True,type=Path)
    p.add_argument("--engine",required=True,type=Path)
    p.add_argument("--out",required=True,type=Path)
    p.add_argument("--scope",choices=("early","opening","all"),default="all")
    p.add_argument("--ups",type=Path)
    p.add_argument("--previews",type=Path)
    p.add_argument("--allow-other-revisions",action="store_true")
    args = p.parse_args()
    try:
        build(args)
    except (OSError,ValueError,KeyError,subprocess.CalledProcessError) as e:
        p.exit(1,f"HnS build failed: {e}\n")


if __name__ == "__main__":
    main()
