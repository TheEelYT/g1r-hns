"""Restore source ambient Pokémon without inventing later story interactions."""
import re
import opening
import world_trainers

DAY_HIDDEN = 0x6020
NIGHT_HIDDEN = 0x6021

def is_pokemon(gfx):
    return "SPECIES_" in gfx or gfx.startswith("OBJ_EVENT_GFX_SPECIES(") or gfx in {
        "OBJ_EVENT_GFX_NO_TAIL_SLOWPOKE_HNS", "OBJ_EVENT_GFX_NURSE_CHANSEY_HNS",
        "OBJ_EVENT_GFX_SHINY_GYARADOS_HNS", "OBJ_EVENT_GFX_SLEEPING_SNORLAX_HNS",
        "OBJ_EVENT_GFX_SWIMMING_LAPRAS_HNS", "OBJ_EVENT_GFX_MEW", "OBJ_EVENT_GFX_DEOXYS",
        "OBJ_EVENT_GFX_ZIGZAGOON_1"}

def build(source,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,known):
    objects=[];omitted=[];interactions=[]
    def r(op,**kw):return {"op":op,**kw}
    for mid,m in sorted(maps.items()):
        existing={o["localId"] for o in m["objects"]}
        for i,o in enumerate(source_maps[m["hnsSourceId"]].get("object_events",[])):
            if not is_pokemon(o["graphics_id"]) or i+1 in existing:continue
            reason=None
            if not (0<=o["x"]<m["width"] and 0<=o["y"]<m["height"]):reason="out-of-bounds source object"
            elif o["flag"] not in ("0","FLAG_DAY_POKEMON","FLAG_NIGHT_POKEMON"):reason="later source story visibility"
            if reason:
                omitted.append({"map":mid,"localId":i+1,"graphics":o["graphics_id"],"flag":o["flag"],"reason":reason});continue
            key="HNS_FIELD_MON_"+mid+"_"+str(i)
            rows=[v for line in labels.get(o["script"],[]) if (v:=line.split("@",1)[0].strip())]
            converted=[];supported=bool(rows) and rows[-1]=="end"
            for line in rows:
                op=line.split()[0]
                if op in ("lock","lockall"):converted.append(r("lockall"))
                elif op in ("faceplayer","closemessage","waitmoncry","waitse","end"):converted.append(r(op))
                elif op in ("release","releaseall"):converted.append(r("releaseall"))
                elif match:=re.fullmatch(r"playmoncry SPECIES_(\w+), (\d+|CRY_MODE_NORMAL)",line):
                    if match[1] not in known:supported=False;break
                    converted.append(r("playmoncry",speciesName=match[1],mode=0 if match[2]=='CRY_MODE_NORMAL' else int(match[2])))
                elif match:=re.fullmatch(r"msgbox (\w+), MSGBOX_(?:DEFAULT|NPC|SIGN|AUTOCLOSE)",line):
                    tid=key+"_TEXT_"+str(len(converted));text[tid]=opening.source_text(match[1],labels)
                    converted += [r("message",ptr=tid),r("waitmessage"),r("waitbuttonpress"),r("closemessage")]
                else:supported=False;break
            script=None
            if supported:
                scripts[key]=converted;script=key
            elif o["script"] not in ("NULL","0x0","0"):
                interactions.append({"map":mid,"localId":i+1,"sourceScript":o["script"],"reason":"later or expanded source interaction; sprite restored"})
            flag={"0":0,"FLAG_DAY_POKEMON":DAY_HIDDEN,"FLAG_NIGHT_POKEMON":NIGHT_HIDDEN}[o["flag"]]
            obj=world_trainers.add_object(source,stage,maps,mid,o,i,script,opening_data,palette_parser,scripted_movement=True,flag=flag)
            obj["hnsFieldPokemon"]=True
            aliases={'MOVEMENT_TYPE_WANDER_AROUND_SLOWER':'MOVEMENT_TYPE_WANDER_AROUND','MOVEMENT_TYPE_TOWER_BEAM':'MOVEMENT_TYPE_WALK_IN_PLACE_LEFT'}
            if o['movement_type'] in aliases:obj['hnsMovementAlias']=aliases[o['movement_type']]
            objects.append({"map":mid,"localId":i+1,"sourceFlag":o["flag"],"script":script})
    return {"objects":objects,"omitted":omitted,"unportedInteractions":interactions,
            "flags":{"dayHidden":DAY_HIDDEN,"nightHidden":NIGHT_HIDDEN},
            "time":{"nightBegin":19,"nightEnd":6},
            "limits":"Ambient objects and straight-line native-supported cries/dialogue; story-controlled Pokémon remain with their source events. No party follower."}
