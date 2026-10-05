"""Source daytime wild tables with complete Emerald-compatible area pools.

Never drop an unsupported species slot and redistribute its probability.
An unsupported area is recorded and omitted as a unit; other source areas
on that map can still be imported. Missing time areas fall back to Day,
as in GetTimeOfDayForEncounters; zero-rate areas stay disabled.
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
    tables={};sources={};omitted=[];timed={}
    for sid,entries in sorted(candidates.items()):
        day=[e for e in entries if e["base_label"].endswith("_Day")]
        plain=[e for e in entries if not e["base_label"].endswith(("_Day","_Night","_Morning","_Evening"))]
        choices=day or plain
        if len(choices)!=1:
            omitted.append({"map":selected[sid],"reason":"no unique daytime/default header","headers":[e["base_label"] for e in entries]});continue
        entry=choices[0];mid=selected[sid]
        def convert(entry):
            table={}
            for field,(kind,count) in KINDS.items():
                area=entry.get(field)
                if area is None:continue
                reason=None
                if isinstance(area,str):reason="unresolved source table pointer"
                elif area["encounter_rate"]==0:continue
                elif len(area["mons"])!=count:reason="source pool shape differs from native area"
                elif any(m["species"] in ("SPECIES_NONE","SPECIES_EGG") or m["species"].startswith("SPECIES_OLD_UNOWN") for m in area["mons"]):reason="nonplayable source species sentinel"
                elif any(m["species"].removeprefix("SPECIES_") not in names for m in area["mons"]):reason="expanded species mapping required"
                elif any(not(1<=m["min_level"]<=m["max_level"]<=100) for m in area["mons"]):reason="invalid source wild levels"
                if reason:
                    omitted.append({"map":mid,"kind":kind,"source":entry["base_label"],"reason":reason});continue
                table[kind]={"rate":area["encounter_rate"],"slots":[{"species":m["species"].removeprefix("SPECIES_"),"minLevel":m["min_level"],"maxLevel":m["max_level"]} for m in area["mons"]]}
            return table
        table=convert(entry)
        if table:tables[mid]=table;sources[mid]=entry["base_label"]
        pools={"Day":table}
        for period in ("Morning","Evening","Night"):
            matches=[e for e in entries if e["base_label"].endswith("_"+period)]
            if len(matches)>1:raise ValueError("ambiguous timed header: "+sid+period)
            if matches:
                extra=matches[0];pool=convert(extra)
                # NULL area pointers use the default header. A zero rate is
                # deliberately absent from pool and must not fall back.
                for field,(kind,_) in KINDS.items():
                    if extra.get(field) is None and kind in table:pool[kind]=table[kind]
                pools[period]=pool
        if len(pools)>1:timed[mid]=pools
    return {"tables":tables,"timed":timed,"sources":sources,"omitted":omitted,"limits":"Exact source time pools and rates with native species; unsupported areas omitted intact. Swarms and expanded species remain unported."}
