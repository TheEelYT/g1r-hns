"""Fail-closed source dialogue importer and reviewed basic Center service.

Conditional/story/trainer/gift/shop scripts and objects controlled by source
flags remain omitted. This is not a general script compiler. Source movement
names and ranges resolve through native Emerald movement profiles.
"""
import json
import re
import opening
import world_marts

PREFIX = "HNS_WORLD_"
NURSE_LABELS = {
    "OldaleTown_PokemonCenter_1F_EventScript_Nurse",
    "BattleFrontier_PokemonCenter_1F_EventScript_Nurse_hns",
    "TrainerHill_Entrance_hns_EventScript_Nurse",
}


def needs_walk_frames(movement):
    return any(word in movement for word in ("_WANDER_","_WALK_","_JOG_","_RUN_"))


def movement_fields(event):
    return {"hnsMovementType":event["movement_type"],"rangeX":event["movement_range_x"],"rangeY":event["movement_range_y"]}


def simple_dialogue(label, labels):
    rows = [line.split("@",1)[0].strip() for line in labels.get(label,[])]
    rows = [line for line in rows if line]
    if not rows or rows[-1] != "end": return None
    allowed = {"lock","lockall","faceplayer","msgbox","closemessage","release","releaseall","end"}
    target = None
    for index,line in enumerate(rows):
        op = line.split()[0]
        if op not in allowed: return None
        if op == "end" and index != len(rows)-1: return None
        if op == "msgbox":
            match = re.fullmatch(r"msgbox\s+(\w+),\s*(MSGBOX_DEFAULT|MSGBOX_NPC|MSGBOX_SIGN)",line)
            if not match or target: return None
            target = match[1]
    if not target: return None
    try: return opening.source_text(target,labels)
    except ValueError: return None


def build(source, engine, stage, maps, source_maps, text, scripts, labels, opening_data, palette_parser):
    sprite_by_source = {info["source"]:info for info in opening_data["sprites"].values()}
    omitted = []; dialogue_count = 0; nurses = []; npc_scripts = []
    nurse_text = {}
    current = None
    for line in (source/"data/text/pkmn_center_nurse.inc").read_text().splitlines():
        match = re.match(r"^(\w+)::?\s*$",line)
        if match: current=match[1];nurse_text[current]=[]
        elif current: nurse_text[current].append(line.strip())
    def row(op,**kw): return {"op":op,**kw}
    def message(label,prompt=False):
        tid=PREFIX+label; text[tid]=opening.source_text(label,nurse_text)
        return [row("message",ptr=tid),row("waitmessage"),row("yesnobox" if prompt else "waitbuttonpress"),row("closemessage")]
    finish = [row("releaseall"),row("end")]
    nurse_key=PREFIX+"NURSE"
    scripts[nurse_key]=[row("lockall"),row("faceplayer")]+message("gText_WouldYouLikeToRestYourPkmn",True)+[
        row("compare_var_to_value",var=opening.RESULT,value=1),row("goto_if",cond=1,target=PREFIX+"NURSE_HEAL")]+message("gText_WeHopeToSeeYouAgain")+finish
    scripts[PREFIX+"NURSE_HEAL"]=message("gText_IllTakeYourPkmn")+[
        row("callnative",fn=opening.HEAL_NATIVE),row("waitstate")]+message("gText_RestoredPkmnToFullHealth")+message("gText_WeHopeToSeeYouAgain")+finish
    for mid, dest in sorted(maps.items()):
        src=source_maps[dest["hnsSourceId"]]
        existing={o["localId"] for o in dest["objects"]}
        for index,o in enumerate(src.get("object_events",[])):
            lid=index+1
            if lid in existing: continue
            reason = None; dialogue = None; nurse = o.get("script") in NURSE_LABELS
            if o.get("flag") != "0": reason="source-controlled visibility"
            elif o.get("trainer_type") != "TRAINER_TYPE_NONE": reason="trainer event"
            elif not (0<=o["x"]<dest["width"] and 0<=o["y"]<dest["height"]): reason="out-of-bounds source object"
            elif not nurse:
                dialogue=simple_dialogue(o.get("script",""),labels)
                if dialogue is None: reason="unsupported source event"
            if reason:
                omitted.append({"map":mid,"sourceIndex":index,"script":o.get("script"),"reason":reason});continue
            gfx=o["graphics_id"]
            walking=needs_walk_frames(o["movement_type"])
            if gfx not in sprite_by_source:
                gid=max(int(k) for k in opening_data["sprites"])+1
                info=opening.sprite(source,gfx,gid,stage,palette_parser,standing_only=not walking)
                sprite_by_source[gfx]=info;opening_data["sprites"][str(gid)]=info
            elif walking and sprite_by_source[gfx].get("standingOnly"):
                gid=sprite_by_source[gfx]["graphicsId"]
                info=opening.sprite(source,gfx,gid,stage,palette_parser)
                sprite_by_source[gfx]=info;opening_data["sprites"][str(gid)]=info
            info=sprite_by_source[gfx]
            key=nurse_key if nurse else PREFIX+mid+"_"+str(index)
            if not nurse:
                tid=key+"_TEXT";text[tid]=dialogue
                scripts[key]=[row("lockall"),row("faceplayer"),row("message",ptr=tid),row("waitmessage"),row("waitbuttonpress"),row("closemessage")]+finish
                npc_scripts.append(key);dialogue_count+=1
            else: nurses.append({"map":mid,"localId":lid})
            facing=o["movement_type"].removeprefix("MOVEMENT_TYPE_FACE_").lower()
            obj={"localId":lid,"x":o["x"],"y":o["y"],"elevation":o["elevation"],"graphicsId":info["graphicsId"],
                "hnsGraphicsId":info["graphicsId"],"scriptKey":key,"flag":0,**movement_fields(o)}
            if facing in ("up","down","left","right"):obj["facing"]=facing
            dest["objects"].append(obj)
    marts_data=world_marts.build(source,engine,maps,source_maps,labels,text,scripts,sprite_by_source,movement_fields)
    clerk_indices={(c["map"],c["localId"]-1) for c in marts_data["clerks"]}
    omitted=[o for o in omitted if (o["map"],o["sourceIndex"]) not in clerk_indices]
    # HnS heal rows use respawn_npc=0: whiteout returns to the original outdoor
    # heal coordinates. Preserve those exact map/coordinates on Center entry.
    selected={m["hnsSourceId"]:mid for mid,m in maps.items()}; checkpoints={}
    nurse_maps={n["map"] for n in nurses}
    for heal in json.loads((source/"src/data/heal_locations.json").read_text())["heal_locations"]:
        center=selected.get(heal.get("respawn_map"));outdoor=selected.get(heal["map"])
        if center in nurse_maps and outdoor and heal.get("respawn_npc")=="0":
            checkpoints[center]={"map":outdoor,"x":heal["x"],"y":heal["y"]}
    return {"format":1,"dialogueNpcCount":dialogue_count,"nurses":nurses,"dialogueScripts":npc_scripts,
        "healCheckpoints":checkpoints,"omittedObjects":omitted,"spriteCount":len(opening_data["sprites"]),"marts":marts_data}
