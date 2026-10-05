"""Explicit native bridge for the opening's first playable interactions.

This is a reviewed subset of the HnS event flow, not a general ASM compiler.
Source dialogue and object graphics are converted; unsupported later branches
are not executed. Stable port flags/vars never reuse hack numeric IDs.
"""
import json
from pathlib import Path
import re
import struct

RECEIVED = 0x6001
ELM_READY = 0x6002
MOM_VISITED = 0x6003
SPECIES_VAR = 0x7001
STARTER_VAR = 0x7002
RESULT = 0x800D
HEAL_NATIVE = 0x484E5301
PREFIX = "HNS_OPENING_"


def source_text(label, labels):
    chunks = []
    for line in labels.get(label, []):
        line = line.strip()
        match = re.fullmatch(r'\.string\s+"(.*)"\s*(?:@.*)?', line)
        if match:
            chunks.append(match[1].replace(r'\"', '"'))
        elif line and not line.startswith("@"):
            raise ValueError(f"unsupported opening text directive in {label}: {line}")
    if not chunks or "$" not in "".join(chunks):
        raise ValueError(f"missing terminated opening dialogue: {label}")
    return "".join(chunks).split("$", 1)[0]


def sprite(source, gfx, gid, stage, palette_parser, standing_only=False):
    from PIL import Image
    base = source / "src/data/object_events"
    species_match = re.search(r"SPECIES_(\w+)", gfx) or re.fullmatch(r"OBJ_EVENT_GFX_SPECIES\((\w+)\)", gfx)
    if species_match:
        # Followers use species-owned palettes and ascending 32px frames.
        # Keep their original expression in the manifest for source auditing.
        species = "SPECIES_" + species_match[1]
        aliases=dict(re.findall(r'^#define\s+(SPECIES_\w+)\s+(SPECIES_\w+)\b',(source/'include/constants/species.h').read_text(),re.M))
        seen=set()
        while species in aliases and species not in seen:
            seen.add(species);species=aliases[species]
        families = "\n".join(p.read_text() for p in sorted((source/"src/data/pokemon/species_info").glob("*.h")))
        match = re.search(r"\["+re.escape(species)+r"\]\s*=\s*(.*?)(?=\n\s*\[SPECIES_|\Z)",families,re.S)
        if not match:raise ValueError('missing follower species entry: '+gfx)
        entry=match[1]
        if not entry.startswith('{'):
            call=re.match(r'(\w+)\(([^)]*)\)',entry)
            definition=re.search(r'^#define '+re.escape(call[1])+r'\(([^)]*)\)[ \t]+([^\n]+)',families.replace('\\\n',' '),re.M)
            if not definition:raise ValueError('unsupported follower species macro: '+gfx)
            entry=definition[2].replace('\\\n',' ')
            for parameter,value in zip(definition[1].split(','),call[2].split(',')):
                entry=re.sub(r'\b'+re.escape(parameter.strip())+r'\b',value.strip(),entry)
            entry=re.sub(r'\s*##\s*','',entry)
        ow = re.search(r"OVERWORLD\(\s*(\w+),\s*SIZE_(\d+)x(\d+),.*?(sAnimTable_\w+),\s*(\w+),\s*(\w+)",entry,re.S)
        if not ow:raise ValueError('missing follower OVERWORLD declaration: '+gfx)
        images,width,height,anims,pal,shiny_pal = ow.groups(); width,height=int(width),int(height)
        if 'OBJ_EVENT_MON_SHINY' in gfx:pal=shiny_pal
        tables=(base/"object_event_pic_tables_followers.h").read_text()
        frames=re.search(r"\b"+images+r"\[\]\s*=\s*\{(.*?)\};",tables,re.S).group(1)
        symbol=re.search(r"overworld_ascending_frames\((\w+),",frames).group(1)
        graphics=(source/"src/data/graphics/pokemon.h").read_text()
        paths=dict(re.findall(r'\b(\w+)\[\]\s*=\s*INCBIN_\w+\("([^\"]+)"\)',graphics))
        image=Image.open((source/paths[symbol]).with_suffix(".png"))
        if image.mode!="P" or image.width%width or image.height%height:raise ValueError("unsupported follower sheet: "+gfx)
        count=image.width*image.height//(width*height)
        asymmetric=anims=='sAnimTable_Following_Asym'
        if count!=(8 if asymmetric else 6):raise ValueError('unreviewed follower frame order: '+gfx)
        order=[0,2,4] if standing_only else [0,2,4,0,1,2,3,4,5]
        if asymmetric:order=[0,2,4,0,1,2,3,4,5,6,6,7]
        colors=palette_parser((source/paths[pal]).with_suffix(".pal"))
        rgba=bytearray()
        for frame in order:
            fx,fy=frame%(image.width//width)*width,frame//(image.width//width)*height
            for value in image.crop((fx,fy,fx+width,fy+height)).tobytes():
                if value>15:raise ValueError("non-4bpp follower: "+gfx)
                c=colors[value];rgba.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if value else 0))
        n=len(order)
        meta=b"SVOW"+struct.pack("<BB6HBHB",2,0,gid,width,height,n,0xFFFF,0xFFFF,4,0xFFFF,0)+struct.pack("<16H",*colors)+bytes(64)
        directory=stage/"ow";directory.mkdir(exist_ok=True)
        (directory/f"{gid}.meta").write_bytes(meta);(directory/f"{gid}.rgba").write_bytes(rgba)
        return {"graphicsId":gid,"width":width,"height":height,"frameCount":n,"source":gfx,"standingOnly":standing_only,"asymmetric":asymmetric,
                "sourcePng":str(Path(paths[symbol]).with_suffix('.png')),"sourcePalette":str(Path(paths[pal]).with_suffix('.pal')),"frameOrder":order,"sourceAnimTable":anims}
    pointers = (base / "object_event_graphics_info_pointers.h").read_text()
    info_name = re.search(r"\[" + re.escape(gfx) + r"\]\s*=\s*&(\w+)", pointers).group(1)
    infos = (base / "object_event_graphics_info.h").read_text()
    block = re.search(r"\b" + re.escape(info_name) + r"\s*=\s*\{(.*?)\};", infos, re.S).group(1)
    if ".paletteTag" in block:
        fields = dict(re.findall(r"\.(\w+)\s*=\s*(\w+)", block))
        tag, images = fields["paletteTag"], fields["images"]
        width, height, slot = int(fields["width"]), int(fields["height"]), 4
        inanimate = fields["inanimate"] == "TRUE"
    else:
        fields = [v.strip() for v in block.split(",")]
        tag, width, height, slot, inanimate, images = fields[1], int(fields[4]), int(fields[5]), int(fields[6]), fields[8] == "TRUE", fields[14]
    tables = (base / "object_event_pic_tables.h").read_text()
    frames = re.search(r"\b" + re.escape(images) + r"\[\]\s*=\s*\{(.*?)\};", tables, re.S).group(1)
    rows = re.findall(r"overworld_frame\((\w+),\s*(\d+),\s*(\d+),\s*(\d+)\)", frames)
    graphics = (base / "object_event_graphics.h").read_text()
    paths = dict(re.findall(r"\b(\w+)\[\]\s*=\s*INCBIN_\w+\(\"([^\"]+)\"\)", graphics))
    multi={symbol:re.findall(r'"([^"\n]+)"',args) for symbol,args in re.findall(r'\b(\w+)\[\]\s*=\s*INCBIN_\w+\(([^;]+)\)',graphics)}
    def object_image(symbol):
        files=multi.get(symbol) or [paths[symbol]]
        ims=[Image.open((source/f).with_suffix('.png')) for f in files]
        if len(ims)==1:return ims[0]
        if any(im.mode!='P' or im.height!=ims[0].height for im in ims):raise ValueError('unsupported concatenated sprite '+symbol)
        result=Image.new('P',(sum(im.width for im in ims),ims[0].height));result.putpalette(ims[0].getpalette())
        x=0
        for im in ims:result.paste(im,(x,0));x+=im.width
        return result
    # Source sprite.h has two other frame forms: relativeFrames walks the PNG
    # in ascending frame order, and obj_frame_tiles is one inanimate image.
    ascending = re.fullmatch(r"\s*overworld_ascending_frames\((\w+),\s*(\d+),\s*(\d+)\),?\s*",frames)
    single = re.fullmatch(r"\s*obj_frame_tiles\((\w+)\),?\s*",frames)
    if ascending:
        symbol,w,h=ascending.groups()
        im=object_image(symbol)
        rows=[(symbol,w,h,str(i)) for i in range(im.width*im.height//(width*height))]
    elif single:
        rows=[(single[1],str(width//8),str(height//8),"0")]
    if not rows or any(int(w)*8 != width or int(h)*8 != height for _,w,h,_ in rows):
        raise ValueError(f"unsupported frame table for {gfx}")
    if not inanimate and 'sAnimTable_Following' in block and len(rows)==6:
        rows=[rows[i] for i in (0,2,4,0,1,2,3,4,5)]
    if standing_only and not inanimate:
        # The world dialogue bridge uses STAY objects. Preserve down/up/left
        # source poses; right mirrors left. Walking frames are a later import.
        rows=rows[:3]
    palettes = (source / "src/event_object_movement.c").read_text()
    pal_symbol = re.search(r"\{\s*(\w+)\s*,\s*" + re.escape(tag) + r"\s*\}", palettes).group(1)
    colors = palette_parser((source / paths[pal_symbol]).with_suffix(".pal"))
    rgba = bytearray()
    for symbol,_,_,index in rows:
        im = object_image(symbol)
        if im.mode != "P" or im.width % width or im.height % height:
            raise ValueError(f"unsupported object PNG layout: {gfx}")
        frame = int(index)
        fx, fy = frame % (im.width // width) * width, frame // (im.width // width) * height
        if fy + height > im.height:
            raise ValueError(f"object frame outside PNG: {gfx}/{frame}")
        for value in im.crop((fx,fy,fx+width,fy+height)).tobytes():
            if value > 15: raise ValueError(f"non-4bpp object pixel: {gfx}")
            color = colors[value]
            rgba.extend((round((color & 31)*255/31),round((color >> 5 & 31)*255/31),round((color >> 10 & 31)*255/31),255 if value else 0))
    # Gen1Recomp SVOW v2: palette arrays are zero-based on decode.
    meta = b"SVOW" + struct.pack("<BB6HBHB",2,int(inanimate),gid,width,height,len(rows),0xFFFF,0xFFFF,slot,0xFFFF,0)
    meta += struct.pack("<16H",*colors) + bytes(64)
    directory = stage / "ow"; directory.mkdir(exist_ok=True)
    (directory / f"{gid}.meta").write_bytes(meta)
    (directory / f"{gid}.rgba").write_bytes(rgba)
    return {"graphicsId":gid,"width":width,"height":height,"frameCount":len(rows),"source":gfx,"standingOnly":standing_only}


def preview_sprites(stage, opening, directory):
    """Inspect native RGBA output, including transparency and frame order."""
    from PIL import Image, ImageDraw
    rows = list(opening["sprites"].values())
    scale = 3
    row_height = max(v["height"] for v in rows)*scale + 36
    width = max(v["width"]*v["frameCount"] for v in rows)*scale + 24
    panel = Image.new("RGB",(width,row_height*len(rows)),(224,229,232))
    draw = ImageDraw.Draw(panel)
    for i,info in enumerate(rows):
        w,h,n,gid = (info[k] for k in ("width","height","frameCount","graphicsId"))
        sheet = Image.frombytes("RGBA",(w,h*n),(stage / "ow" / f"{gid}.rgba").read_bytes())
        draw.text((12,i*row_height+6),info["source"]+f" ({gid}, {n} frames)",fill=(24,30,36))
        for frame in range(n):
            im = sheet.crop((0,frame*h,w,(frame+1)*h)).resize((w*scale,h*scale),Image.Resampling.NEAREST)
            x,y = 12+frame*w*scale,i*row_height+24
            panel.paste(im,(x,y),im)
    directory.mkdir(parents=True,exist_ok=True)
    panel.save(directory / "HNS_OPENING_NPC_FRAMES.png")


def build(source, stage, maps, text, scripts, labels, palette_parser):
    def key(name): return PREFIX + name
    def row(op, **kw): return {"op":op, **kw}
    def dialogue(label, prompt=False):
        tid=key(label); text[tid]=source_text(label,labels)
        result=[row("message",ptr=tid),row("waitmessage")]
        result += [row("yesnobox")] if prompt else [row("waitbuttonpress")]
        return result + [row("closemessage")]
    def branch(flag,target,on=True):
        return [row("checkflag",flag=flag),row("goto_if",cond=1 if on else 0,target=key(target))]
    end=[row("releaseall"),row("end")]
    lock=[row("lockall"),row("faceplayer")]
    def script(name,rows): scripts[key(name)]=rows; return key(name)

    script("ELM",lock + branch(RECEIVED,"ELM_AFTER") + branch(ELM_READY,"ELM_READY") + dialogue("NewBarkTown_Lab_Text_ElmIntro",True)
           + [row("compare_var_to_value",var=RESULT,value=1),row("goto_if",cond=1,target=key("ELM_ACCEPT"))]
           + dialogue("NewBarkTown_Lab_Text_ElmRefused") + end)
    script("ELM_ACCEPT",dialogue("NewBarkTown_Lab_Text_ElmAccepted")+dialogue("NewBarkTown_Lab_Text_ElmResearchAmbitions")
           +dialogue("NewBarkTown_Lab_Text_ElmGotAnEmail")+dialogue("NewBarkTown_Lab_Text_ElmMissionFromMrPokemon")
           +[row("setflag",flag=ELM_READY),row("goto",target=key("ELM_READY"))])
    script("ELM_READY",dialogue("NewBarkTown_Lab_Text_ElmChooseAPokemon")+end)
    script("ELM_AFTER",dialogue("NewBarkTown_Lab_Text_ElmLetYourMonBattle")+dialogue("NewBarkTown_Lab_Text_ElmDirections2")+end)
    script("MOM",lock+branch(RECEIVED,"MOM_AFTER")+dialogue("NewBarkTown_PlayersHouse_1F_Text_MomHurryUpElmIsWaiting")
           +[row("setflag",flag=MOM_VISITED)]+end)
    script("MOM_AFTER",dialogue("NewBarkTown_PlayersHouse_1F_Text_MomLeaving")+[row("setflag",flag=MOM_VISITED)]+end)
    script("AIDE1",lock+dialogue("NewBarkTown_Lab_Text_AideAlwaysBusy")+end)
    script("AIDE2",lock+dialogue("NewBarkTown_Lab_Text_AideSave")+end)
    script("FRIEND",lock+dialogue("NewBarkTown_PlayersHouse_1F_Text_MomsFriend")+end)
    script("DONT_TOUCH",dialogue("NewBarkTown_Lab_Text_ShouldntTouch")+end)
    script("DECLINE",dialogue("NewBarkTown_Lab_Text_DidntChooseStarter")+end)
    text[key("GIFT_FAILED_TEXT")]="Your party and PC cannot accept another POKéMON."
    script("GIFT_FAILED",[row("message",ptr=key("GIFT_FAILED_TEXT")),row("waitmessage"),row("waitbuttonpress"),row("closemessage")]+end)
    categories=(source / "src/data/pokemon/species_info/gen_2_families.h").read_text()
    for i,name in enumerate(("CHIKORITA","CYNDAQUIL","TOTODILE")):
        category=re.search(r"\[SPECIES_"+name+r"\].*?\.categoryName\s*=\s*_\(\"([^\"]+)\"\)",categories,re.S).group(1)
        for buffer,value in (("NAME",name),("CATEGORY",category.upper())): text[key(f"{name}_{buffer}")]=value
        choice="NewBarkTown_Lab_Text_Choose"+name.title()
        script(name,lock+branch(RECEIVED,"DONT_TOUCH")+branch(ELM_READY,"DONT_TOUCH",False)
               +[row("bufferstring",dest=0,src=key(f"{name}_NAME")),row("bufferstring",dest=1,src=key(f"{name}_CATEGORY"))]
               +dialogue(choice,True)+[row("compare_var_to_value",var=RESULT,value=1),row("goto_if",cond=1,target=key(name+"_GIFT")),row("goto",target=key("DECLINE"))])
        script(name+"_GIFT",[row("givemon",speciesName=name,level=5),row("compare_var_to_value",var=RESULT,value=2),row("goto_if",cond=1,target=key("GIFT_FAILED")),
               row("setflag",flag=RECEIVED),row("setflag",flag=0x6010+i),row("setflag",engineFlagName="FLAG_SYS_POKEMON_GET"),
               row("setvar",var=SPECIES_VAR,speciesName=name),row("setvar",var=STARTER_VAR,value=i),row("removeobject",localId=4+i)]
               +dialogue("NewBarkTown_Lab_Text_ChoseStarter")+dialogue("NewBarkTown_Lab_Text_ReceivedStarter")
               +dialogue("NewBarkTown_Lab_Text_ElmLetYourMonBattle")+end)
    script("HEAL",[row("lockall")]+branch(RECEIVED,"HEAL_PARTY")+dialogue("NewBarkTown_Lab_Text_ShouldntTouch")+end)
    text[key("HEALED_TEXT")]="Your POKéMON are fully healed."
    script("HEAL_PARTY",[row("callnative",fn=HEAL_NATIVE),row("waitstate"),row("message",ptr=key("HEALED_TEXT")),row("waitmessage"),row("waitbuttonpress"),row("closemessage")]+end)
    labid="EM_HNS_NEW_BARK_TOWN_LAB_HNS"
    houseid="EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS"
    chosen={labid:{1:"AIDE1",2:"ELM",3:"AIDE2",4:"CHIKORITA",5:"CYNDAQUIL",6:"TOTODILE"},houseid:{1:"MOM",2:"FRIEND"}}
    sprites={}; count=0
    for mid,npcs in chosen.items():
        if mid not in maps: continue
        source_map=json.loads((source / "data/maps" / ("NewBarkTown_Lab_hns" if mid==labid else "NewBarkTown_PlayersHouse_1F_hns") / "map.json").read_text())
        objects=[]
        for lid,event_name in npcs.items():
            o=source_map["object_events"][lid-1]; gfx=o["graphics_id"]
            if gfx not in sprites: sprites[gfx]=sprite(source,gfx,0xE000+len(sprites),stage,palette_parser)
            direction=o["movement_type"].removeprefix("MOVEMENT_TYPE_FACE_").lower()
            if direction not in ("up","down","left","right"): direction="down"
            objects.append({"localId":lid,"x":o["x"],"y":o["y"],"elevation":o["elevation"],"graphicsId":sprites[gfx]["graphicsId"],
                            "hnsGraphicsId":sprites[gfx]["graphicsId"],"facing":direction,"movement":"STAY","radius":{"x":0,"y":0},
                            "scriptKey":key(event_name),"flag":0x6010+lid-4 if mid==labid and lid in (4,5,6) else 0})
            objects[-1].update({"hnsMovementType":o["movement_type"],"rangeX":o["movement_range_x"],"rangeY":o["movement_range_y"]})
            count+=1
        maps[mid]["objects"]=objects
    lab_source=json.loads((source / "data/maps/NewBarkTown_Lab_hns/map.json").read_text())
    for e in lab_source["bg_events"]:
        if e.get("script")=="NewBarkTown_Lab_EventScript_HealingMachine1":
            maps[labid]["bgEvents"].append({"x":e["x"],"y":e["y"],"elevation":e["elevation"],"kind":0,"scriptKey":key("HEAL")})
    # First-battle milestone: source daytime Route 29 land table, exact slots
    # and level/rate values. Species references are engine names, never HnS IDs.
    tables=json.loads((source / "src/data/wild_encounters.json").read_text())
    route=next(e for g in tables["wild_encounter_groups"] for e in g.get("encounters",[]) if e.get("base_label")=="gRoute29_hns_Day")
    land=route["land_mons"]
    encounters={"EM_HNS_ROUTE29_HNS":{"land":{"rate":land["encounter_rate"],"slots":[{"species":v["species"].removeprefix("SPECIES_"),"minLevel":v["min_level"],"maxLevel":v["max_level"]} for v in land["mons"]]}}}
    return {"format":1,"sprites":{str(v["graphicsId"]):v for v in sprites.values()},"npcCount":count,"healNative":HEAL_NATIVE,
            "encounters":encounters,"flags":{"received":RECEIVED,"elmReady":ELM_READY,"momVisited":MOM_VISITED},
            "vars":{"species":SPECIES_VAR,"starter":STARTER_VAR},
            "limits":"Source lab entrance/email is added by scenes.py; no clock/Mom intro cutscene, nickname, follower, Nuzlocke or Pokegear. Mr Pokemon/rival progression is in world.quest. Battles use vanilla Emerald rules/data; world.encounters imports supported daytime/default source areas."}
