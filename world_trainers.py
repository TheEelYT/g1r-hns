"""Reviewed ordinary single battles, source rosters, portraits and money.

Stable IDs derive from the complete pinned source roster, not the subset that
happens to be imported. Expanded mechanics and complex story branches are
audited; they never receive guessed replacement teams.
"""
import re
import opening
import world_events
from world_marts import ITEM_ALIASES

PREFIX="HNS_TRAINER_"
TRAINER_BASE=0x4000
CLASS_BASE=160
PIC_BASE=128


def symbol(value):return re.sub(r"[^A-Z0-9]+","_",value.upper()).strip("_")


def parse_rosters(text):
    result={}
    for match in re.finditer(r"^=== (TRAINER_\w+) ===\s*\n(.*?)(?=^=== |\Z)",text,re.M|re.S):
        label,body=match.groups();header={};party=[];mon=None
        for line in body.splitlines():
            line=line.strip()
            if not line or line.startswith("//"):continue
            if line.startswith("- "):
                if mon is None:raise ValueError(f"move before species: {label}")
                mon.setdefault("moves",[]).append(line[2:]);continue
            if ":" in line:
                key,value=line.split(":",1);(header if mon is None else mon)[key.strip()]=value.strip();continue
            if line.endswith(" Nature"):
                if mon is None:raise ValueError(f"nature before species: {label}")
                mon["Nature"]=line[:-7];continue
            if mon is not None and "Level" not in mon:raise ValueError(f"unrecognized party line: {label}/{line}")
            species,_,held=line.partition(" @ ")
            mon={"species":symbol(species)}
            if held:mon["heldItem"]=symbol(held)
            party.append(mon)
        result[label]={"header":header,"party":party}
    return result


def prepare(source,engine):
    rosters=parse_rosters((source/"src/data/trainers_hns.party").read_text())
    ids={label:TRAINER_BASE+i for i,label in enumerate(sorted(rosters))}
    classes={name:CLASS_BASE+i for i,name in enumerate(sorted({r["header"]["Class"] for r in rosters.values()}))}
    pics={name:PIC_BASE+i for i,name in enumerate(sorted({r["header"]["Pic"] for r in rosters.values()}))}
    if max(classes.values())>255 or max(pics.values())>255:raise ValueError("reserved trainer presentation IDs exhausted")
    def native_names(file,prefix):return set(re.findall(r'"'+prefix+r'(\w+)"',(engine/"src/core/game3/constants/emerald"/file).read_text()))
    known={"species":native_names("species.lua","SPECIES_"),"moves":native_names("moves.lua","MOVE_"),"items":native_names("items.lua","ITEM_")}
    class_source=(source/"src/battle_main.c").read_text()
    class_rows={}
    for name,id in classes.items():
        token="TRAINER_CLASS_"+symbol(name)
        row=re.search(r"\["+re.escape(token)+r"\]\s*=\s*\{\s*_\(\"([^\"]+)\"\)(?:\s*,\s*(\d+))?",class_source)
        if not row:continue
        class_rows[str(id)]={"name":row[1].replace("{PKMN}","POKéMON"),"money":int(row[2] or 0),"source":token}
    return {"rosters":rosters,"ids":ids,"classes":classes,"pics":pics,"classRows":class_rows,"known":known}


def roster(label,prepared):
    src=prepared["rosters"].get(label)
    if not src:raise ValueError("missing source roster: "+label)
    h=src["header"]
    if h["Double Battle"]!="No":raise ValueError("double trainer event")
    ai={"Check Bad Move":1,"Basic Trainer":7}
    if h["AI"] not in ai:raise ValueError("expanded trainer AI: "+h["AI"])
    if str(prepared["classes"][h["Class"]]) not in prepared["classRows"]:raise ValueError("unmapped trainer class")
    party=[]
    for m in src["party"]:
        unknown=set(m)-{"species","heldItem","Level","IVs","moves"}
        if unknown:raise ValueError("expanded/unsupported team attributes: "+",".join(sorted(unknown)))
        if m["species"] not in prepared["known"]["species"]:raise ValueError("expanded species: "+m["species"])
        level=int(m["Level"])
        if not 1<=level<=100:raise ValueError("invalid trainer level")
        ivs=[int(v) for v in re.findall(r"\b(\d+)\s+(?:HP|Atk|Def|SpA|SpD|Spe)",m.get("IVs","0 HP / 0 Atk / 0 Def / 0 SpA / 0 SpD / 0 Spe"))]
        if len(ivs)!=6 or len(set(ivs))!=1 or not 0<=ivs[0]<=31:raise ValueError("nonuniform trainer IVs require native bridge")
        mon={"species":m["species"],"level":level,"iv":ivs[0]}
        if "heldItem" in m:
            item=ITEM_ALIASES.get("ITEM_"+m["heldItem"],"ITEM_"+m["heldItem"])
            if item.removeprefix("ITEM_") not in prepared["known"]["items"]:raise ValueError("expanded held item: "+item)
            mon["heldItem"]=item.removeprefix("ITEM_")
        if "moves" in m:
            moves=[symbol(v) for v in m["moves"]]
            if len(moves)>4 or any(v not in prepared["known"]["moves"] for v in moves):raise ValueError("expanded trainer moves: "+",".join(moves))
            mon["moves"]=moves
        party.append(mon)
    if not 1<=len(party)<=6:raise ValueError("invalid team size")
    items=[]
    for item in h.get("Items","").split(","):
        if not item.strip():continue
        token=ITEM_ALIASES.get("ITEM_"+symbol(item),"ITEM_"+symbol(item))
        if token.removeprefix("ITEM_") not in prepared["known"]["items"]:raise ValueError("expanded trainer item: "+token)
        items.append(token.removeprefix("ITEM_"))
    return {"name":h["Name"],"class":prepared["classes"][h["Class"]],"className":prepared["classRows"][str(prepared["classes"][h["Class"]])]["name"],
            "pic":prepared["pics"][h["Pic"]],"gender":0 if h["Gender"]=="Male" else 1,"doubleBattle":False,"aiFlags":ai[h["AI"]],"items":items,"party":party,"source":label}


def portrait(source,pic,id,stage,palette_parser):
    from PIL import Image
    graphics=(source/"src/data/graphics/trainers.h").read_text()
    token="TRAINER_PIC_FRONT_"+symbol(pic)
    row=re.search(r"TRAINER_SPRITE\("+re.escape(token)+r",\s*(\w+),\s*(\w+)\)",graphics)
    if not row:raise ValueError("unmapped source trainer portrait: "+pic)
    paths=dict(re.findall(r"\b(\w+)\[\]\s*=\s*INCBIN_\w+\(\"([^\"]+)\"\)",graphics))
    path=re.sub(r"\.4bpp(?:\.smol|\.lz)?$",".png",paths[row[1]])
    im=Image.open(source/path)
    if im.mode!="P" or im.size!=(64,64):raise ValueError("unsupported trainer portrait PNG: "+pic)
    pal=(source/paths[row[2]]).with_suffix(".pal")
    if pal.exists():colors=palette_parser(pal)
    else:
        # GBA build derives some .gbapal files directly from an indexed PNG.
        png=pal.with_suffix(".png")
        if not png.exists():raise ValueError("missing source trainer palette: "+pic)
        palette_image=Image.open(png)
        rgb=palette_image.getpalette()
        if palette_image.mode!="P" or not rgb or len(rgb)<48:raise ValueError("unsupported PNG-derived trainer palette")
        colors=[(rgb[i*3]//8)|((rgb[i*3+1]//8)<<5)|((rgb[i*3+2]//8)<<10) for i in range(16)]
    rgba=bytearray()
    for value in im.tobytes():
        if value>15:raise ValueError("trainer portrait is not 4bpp")
        c=colors[value];rgba.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if value else 0))
    dest=stage/"trainers"/"front";dest.mkdir(parents=True,exist_ok=True)
    (dest/f"{id}.rgba").write_bytes(rgba)
    return {"source":token,"file":f"trainers/front/{id}.rgba","width":64,"height":64}


def add_object(source,stage,maps,mid,event,index,script,opening_data,palette_parser,scripted_movement=False,**extra):
    sprites={v["source"]:v for v in opening_data["sprites"].values()};gfx=event["graphics_id"]
    walking=scripted_movement or world_events.needs_walk_frames(event["movement_type"])
    info=sprites.get(gfx)
    if info is None or (walking and info.get("standingOnly")):
        gid=info["graphicsId"] if info else max(map(int,opening_data["sprites"]))+1
        info=opening.sprite(source,gfx,gid,stage,palette_parser,standing_only=not walking)
        opening_data["sprites"][str(gid)]=info
    obj={"localId":index+1,"x":event["x"],"y":event["y"],"elevation":event["elevation"],"graphicsId":info["graphicsId"],"hnsGraphicsId":info["graphicsId"],"scriptKey":script,"flag":0,**world_events.movement_fields(event),**extra}
    face=event["movement_type"].removeprefix("MOVEMENT_TYPE_FACE_").lower()
    if face in ("up","down","left","right"):obj["facing"]=face
    maps[mid]["objects"].append(obj)
    return obj


def basic_script(label,labels):
    rows=[v for line in labels.get(label,[]) if (v:=line.split("@",1)[0].strip())]
    if not rows:return None
    match=re.fullmatch(r"trainerbattle_single (TRAINER_\w+), (\w+), (\w+)",rows[0])
    if match and len(rows)==3 and rows[2]=="end":
        after=re.fullmatch(r"msgbox (\w+), MSGBOX_AUTOCLOSE",rows[1])
        if after:return (*match.groups(),after[1])
    # Joey's initial single battle is reviewed separately. Match Call and
    # rematches are omitted; source after-battle dialogue remains available.
    if label=="Route30_EventScript_Youngster_Joey" and rows[0]=="trainerbattle_single TRAINER_JOEY_HNS, Route30_Text_YoungsterJoey1Seen, Route30_Text_YoungsterJoey1Beaten, Route30_EventScript_RegisterJoey":
        return "TRAINER_JOEY_HNS","Route30_Text_YoungsterJoey1Seen","Route30_Text_YoungsterJoey1Beaten","Route30_Text_YoungsterJoey1After"
    return None


def build(source,engine,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,prepared):
    records={};portraits={};events=[];omitted=[]
    for mid,dest in sorted(maps.items()):
        existing={o["localId"] for o in dest["objects"]}
        for i,event in enumerate(source_maps[dest["hnsSourceId"]].get("object_events",[])):
            if i+1 in existing or event.get("flag")!="0" or event.get("trainer_type") not in ("TRAINER_TYPE_NORMAL","TRAINER_TYPE_SEE_ALL_DIRECTIONS"):continue
            parsed=basic_script(event.get("script"),labels)
            if parsed is None:continue
            label,intro,defeat,after=parsed
            try:
                record=roster(label,prepared);tid=prepared["ids"][label]
                pic=prepared["rosters"][label]["header"]["Pic"];pid=prepared["pics"][pic]
                if str(pid) not in portraits:portraits[str(pid)]=portrait(source,pic,pid,stage,palette_parser)
                messages={kind:opening.source_text(key,labels) for kind,key in (("INTRO",intro),("DEFEAT",defeat),("AFTER",after))}
                if not(0<=event["x"]<dest["width"] and 0<=event["y"]<dest["height"]):raise ValueError("out-of-bounds trainer")
            except ValueError as error:
                omitted.append({"map":mid,"sourceIndex":i,"trainer":label,"reason":str(error)});continue
            key=PREFIX+mid+"_"+str(i)
            for kind,value in messages.items():text[key+"_"+kind]=value
            record["dialogs"]={"intro":messages["INTRO"],"defeat":messages["DEFEAT"]}
            records[str(tid)]=record
            r=lambda op,**kw:{"op":op,**kw}
            scripts[key]=[r("lockall"),r("faceplayer"),r("trainerbattle",type=1,trainer=tid,introText=key+"_INTRO",defeatText=key+"_DEFEAT",eventScript=key+"_FINISH"),
                          r("checkflag",flag=0x500+tid),r("goto_if",cond=0,target=key+"_FINISH"),
                          r("message",ptr=key+"_AFTER"),r("waitmessage"),r("waitbuttonpress"),r("closemessage"),r("releaseall"),r("end")]
            scripts[key+"_FINISH"]=[r("closemessage"),r("releaseall"),r("end")]
            trainer_type=3 if event["trainer_type"]=="TRAINER_TYPE_SEE_ALL_DIRECTIONS" else 1
            add_object(source,stage,maps,mid,event,i,key,opening_data,palette_parser,trainerType=trainer_type,trainerId=tid,trainerRange=int(event["trainer_sight_or_berry_tree_id"],0))
            events.append({"map":mid,"localId":i+1,"trainerId":tid,"script":key,"sourceScript":event["script"]})
    return {"records":records,"portraits":portraits,"classes":prepared["classRows"],"events":events,"omitted":omitted,
            "limits":"Reviewed single battles, native sight/approach and persistent defeat flags; source species/levels/uniform IVs/moves/held items, portraits, class money and basic AI. Expanded mechanics, story trainers, doubles, phone and rematches remain unported."}
