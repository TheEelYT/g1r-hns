"""Inventory source-world assets and references before building a full import."""
from pathlib import Path
import argparse
import collections
import json
import build_port as port


def audit(source):
    source=source.resolve()
    all_maps={m["id"]:m for f in sorted((source/"data/maps").glob("*/map.json")) for m in [json.loads(f.read_text())]}
    maps={k:v for k,v in all_maps.items() if v.get("game_version")=="hns"}
    layouts={l["id"]:l for l in json.loads((source/"data/layouts/layouts.json").read_text())["layouts"]}
    specs=port.symbols(source)
    names=port.enum_names(source/"include/constants/metatile_behaviors.h","MB_")
    pairs={};sets={};asset_errors={}
    for m in maps.values():
        l=layouts[m["layout"]]
        n,np=port.layout_profile(l)
        key=(l["primary_tileset"],l["secondary_tileset"],n,np)
        pair=pairs.setdefault(key,{"maps":[],"mids":set()})
        pair["maps"].append(m["name"])
        pair["mids"].update(w&1023 for w in port.u16s(source/l["blockdata_filepath"])+port.u16s(source/l["border_filepath"]))
    for key in pairs:
        for name in key[:2]:
            if name not in sets and name not in asset_errors:
                try: sets[name]=port.Tileset(specs[name])
                except Exception as error: asset_errors[name]=str(error)
    report={"maps":len(maps),"layouts":len({m["layout"] for m in maps.values()}),"tilesets":len(sets)+len(asset_errors),
            "pairs":len(pairs),"asset_errors":asset_errors,"pair_errors":[],"render_errors":[],"used_behaviors":set(),
            "outside_destinations":collections.Counter(),"invalid_warps":[],"map_types":dict(collections.Counter(m["map_type"] for m in maps.values()))}
    for key,info in pairs.items():
        if any(name in asset_errors for name in key[:2]): continue
        try: pair=port.Pair(sets[key[0]],sets[key[1]],key[2],key[3],names)
        except Exception as error:
            report["pair_errors"].append({"pair":key,"maps":info["maps"],"errors":{str(error):1}});continue
        errors=collections.Counter();bad_mids={}
        for mid in sorted(info["mids"]):
            try:
                entries,behavior,_=pair.definition(mid)
                report["used_behaviors"].add(behavior)
                try: pair.layers(mid)
                except ValueError as error: report["render_errors"].append({"pair":key,"mid":mid,"error":str(error)})
                for entry in entries:
                    tid=entry&1023;ts=pair.primary if tid<pair.n_primary else pair.secondary
                    local=tid if tid<pair.n_primary else tid-pair.n_primary
                    if local>=ts.count and local not in ts.blank_placeholders:
                        error=f'{ts.spec["dir"].relative_to(source)}: tile {local} >= {ts.count}'
                        errors[error]+=1;bad_mids.setdefault(str(mid),[]).append(local)
            except Exception as error: errors[str(error)]+=1
        if errors: report["pair_errors"].append({"pair":key,"maps":info["maps"],"errors":dict(errors),"bad_mids":bad_mids})
    for m in maps.values():
        for i,w in enumerate(m.get("warp_events",[])):
            if w["dest_map"] not in maps: report["outside_destinations"][w["dest_map"]]+=1
            else:
                try: index=int(w["dest_warp_id"],0)
                except ValueError: index=-1
                if not 0<=index<len(maps[w["dest_map"]].get("warp_events",[])):
                    report["invalid_warps"].append({"map":m["name"],"index":i,"dest":w})
    report["used_behaviors"]=sorted(report["used_behaviors"])
    report["outside_destinations"]=dict(report["outside_destinations"])
    return report


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,required=True)
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args()
    report=audit(args.source)
    port.write_json(args.out,report)
    print(json.dumps({k:v for k,v in report.items() if k not in ("used_behaviors","pair_errors","invalid_warps")},indent=2))
    for error in report["pair_errors"]:
        print(json.dumps({"pair":error["pair"],"map_count":len(error["maps"]),"examples":error["maps"][:3],
                          "error_types":len(error["errors"]),"errors":list(error["errors"])[:6]}))
    print("Invalid/dynamic static-destination warps:",len(report["invalid_warps"]))
