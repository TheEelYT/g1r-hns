"""Source daytime wild tables with complete Emerald-compatible area pools.

Never drop an unsupported species slot and redistribute its probability.
An unsupported area is recorded and omitted as a unit; other source areas
on that map can still be imported. Time-of-day switching remains later work.
"""
import json
import re

KINDS={"land_mons":("land",12),"water_mons":("water",5),"rock_smash_mons":("rocks",5),"fishing_mons":("fishing",10)}


def build(source,engine,maps):
    names=set(re.findall(r'"SPECIES_(\w+)"',(engine/"src/core/game3/constants/emerald/species.lua").read_text()))
    selected={m["hnsSourceId"]:mid for mid,m in maps.items()}
    data=json.loads((source/"src/data/wild_encounters.json").read_text())
    candidates={}
    for group in data["wild_encounter_groups"]:
        if not group.get("for_maps"):continue
        for entry in group.get("encounters",[]):
            if entry.get("map") in selected:
                candidates.setdefault(entry["map"],[]).append(entry)
    tables={};sources={};omitted=[]
    for sid,entries in sorted(candidates.items()):
        day=[e for e in entries if e["base_label"].endswith("_Day")]
        plain=[e for e in entries if not e["base_label"].endswith(("_Day","_Night","_Morning"))]
        choices=day or plain
        if len(choices)!=1:
            omitted.append({"map":selected[sid],"reason":"no unique daytime/default header","headers":[e["base_label"] for e in entries]});continue
        entry=choices[0];mid=selected[sid];table={}
        for field,(kind,count) in KINDS.items():
            area=entry.get(field)
            if not area:continue
            if isinstance(area,str):
                omitted.append({"map":mid,"kind":kind,"reason":"unresolved source table pointer","source":area});continue
            if area["encounter_rate"]==0:
                omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":"source area disabled by zero encounter rate"});continue
            mons=area["mons"]
            if len(mons)!=count:
                omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":"source pool shape differs from native area","slots":len(mons),"nativeSlots":count});continue
            missing=sorted({m["species"] for m in mons if m["species"].removeprefix("SPECIES_") not in names})
            if any(m["species"] in ("SPECIES_NONE","SPECIES_EGG") or m["species"].startswith("SPECIES_OLD_UNOWN") for m in mons):
                omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":"nonplayable source species sentinel"});continue
            if missing:
                omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":"expanded species mapping required","species":missing});continue
            if any(not(1<=m["min_level"]<=m["max_level"]<=100) for m in mons):
                omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":"invalid source wild levels"});continue
            table[kind]={"rate":area["encounter_rate"],"slots":[{"species":m["species"].removeprefix("SPECIES_"),"minLevel":m["min_level"],"maxLevel":m["max_level"]} for m in mons]}
        if table:tables[mid]=table;sources[mid]=entry["base_label"]
    return {"tables":tables,"sources":sources,"omitted":omitted,"limits":"Exact daytime/default source slots and rates with Emerald species; unsupported areas omitted intact. Night switching, swarms and expanded species remain unported."}
