"""Compare the built world directly with pinned source and the prior release.

Uses the engine's Lua-to-JSON reader, not converter-internal map selection or
conversion helpers. Check every layout, event index and map connection.
"""
import argparse
import collections
import json
import re
from pathlib import Path
import struct
import subprocess


def check(source, engine, mod, luajit, baseline=None):
    world=json.loads(subprocess.check_output([str(luajit),str(engine/"tools/lua_to_json.lua"),str(mod/"world.lua")],text=True))
    source_maps={m["id"]:m for p in(source/"data/maps").glob("*/map.json") for m in[json.loads(p.read_text())]}
    expected={k for k,m in source_maps.items() if m.get("game_version")=="hns"}
    shared={"MAP_UNION_ROOM","MAP_TRADE_CENTER","MAP_ARTISAN_CAVE_B1F","MAP_ARTISAN_CAVE_1F"}
    expected|=shared
    assert {m["hnsSourceId"] for m in world["maps"].values()}==expected
    assert len(world["maps"])==564
    layouts={l["id"]:l for l in json.loads((source/"data/layouts/layouts.json").read_text())["layouts"]}
    maps=world["maps"];ids={m["hnsSourceId"]:mid for mid,m in maps.items()}
    report=json.loads((mod/"build_report.json").read_text())
    omitted={(e["map"],e["index"]):e for e in report["omitted_slice_events"] if "warp" in e["kind"] or "arrival" in e["kind"]}
    fixups={("MAP_ARTISAN_CAVE_B1F",0):("MAP_BATTLE_FRONTIER_OUTSIDE_WEST_HNS",9),
            ("MAP_ARTISAN_CAVE_1F",0):("MAP_BATTLE_FRONTIER_OUTSIDE_EAST_HNS",12)}
    counts=collections.Counter();regions=collections.Counter()
    for mid,m in maps.items():
        src=source_maps[m["hnsSourceId"]];lay=layouts[src["layout"]]
        blob=(mod/m["hnsLayoutFile"]).read_bytes()
        assert blob[:4]==b"SVML" and len(blob)==24+4*lay["width"]*lay["height"]
        assert (m["width"],m["height"])==(lay["width"],lay["height"])
        words=struct.iter_unpack("<H",(source/lay["blockdata_filepath"]).read_bytes())
        cells=struct.iter_unpack("<HBB",blob[24:])
        for (word,),(tile,collision,elevation) in zip(words,cells):
            assert (tile,collision,elevation)==(word&1023,word>>10&3,word>>12),mid
            counts["layout_cells"]+=1
        native={w["sourceIndex"]:w for w in m["warps"]}
        assert len(native)==len(m["warps"])
        for i,w in enumerate(src.get("warp_events",[])):
            if (mid,i) in omitted:
                assert i not in native
                counts["audited_source_warp_omissions"]+=1;continue
            n=native[i]
            assert (n["x"],n["y"],n["elevation"])==(w["x"],w["y"],w["elevation"])
            if w["dest_map"]=="MAP_DYNAMIC":assert n["mapNum"]==127;counts["dynamic_warps"]+=1
            else:
                did,j=fixups.get((src["id"],i),(w["dest_map"],int(w["dest_warp_id"],0)))
                arrival=source_maps[did]["warp_events"][j]
                assert (n["destMap"],n["destX"],n["destY"],n["destWarp"])==(ids[did],arrival["x"],arrival["y"],0)
                counts["static_warps"]+=1
        translated=[{"dir":{"up":"north","down":"south","left":"west","right":"east"}.get(c["direction"],c["direction"]),
                     "map":ids[c["map"]],"offset":c["offset"]} for c in src.get("connections") or []]
        assert m["connections"]==translated,mid
        counts["connections"]+=len(translated)
        for o in m["objects"]:
            original=src["object_events"][o["localId"]-1]
            assert (o["x"],o["y"],o["elevation"])==(original["x"],original["y"],original["elevation"])
            assert world["opening"]["sprites"][str(o["graphicsId"])]["source"]==original["graphics_id"]
            assert (o["hnsMovementType"],o["rangeX"],o["rangeY"])==(original["movement_type"],original["movement_range_x"],original["movement_range_y"])
            counts["objects"]+=1
        regions[src.get("region","unspecified/shared")]+=1
    assert counts["dynamic_warps"]==11 and counts["connections"]==219
    if world.get('fieldPokemon'):
        from PIL import Image
        mon=world['fieldPokemon']
        entries={(e['map'],e['localId']):e for e in mon['objects']}
        omissions={(e['map'],e['localId']):e for e in mon['omitted']}
        special={'OBJ_EVENT_GFX_NO_TAIL_SLOWPOKE_HNS','OBJ_EVENT_GFX_NURSE_CHANSEY_HNS','OBJ_EVENT_GFX_SHINY_GYARADOS_HNS','OBJ_EVENT_GFX_SLEEPING_SNORLAX_HNS','OBJ_EVENT_GFX_SWIMMING_LAPRAS_HNS','OBJ_EVENT_GFX_MEW','OBJ_EVENT_GFX_DEOXYS','OBJ_EVENT_GFX_ZIGZAGOON_1'}
        for mid,m in maps.items():
            rendered={o['localId']:o for o in m['objects']}
            for i,o in enumerate(source_maps[m['hnsSourceId']].get('object_events',[]),1):
                if not ('SPECIES_' in o['graphics_id'] or o['graphics_id'].startswith('OBJ_EVENT_GFX_SPECIES(') or o['graphics_id'] in special):continue
                if i in rendered:
                    if (mid,i) in entries:
                        e=entries[mid,i];n=rendered[i]
                        assert e['sourceFlag']==o['flag']
                        assert n['flag']=={'0':0,'FLAG_DAY_POKEMON':mon['flags']['dayHidden'],'FLAG_NIGHT_POKEMON':mon['flags']['nightHidden']}[o['flag']]
                        counts['restored_field_pokemon']+=1
                    continue
                assert (mid,i) in omissions,(mid,i)
                e=omissions[mid,i]
                if e['reason']=='out-of-bounds source object':assert not (0<=o['x']<m['width'] and 0<=o['y']<m['height'])
                else:assert o['flag'] not in ('0','FLAG_DAY_POKEMON','FLAG_NIGHT_POKEMON')
                counts['audited_field_pokemon_omissions']+=1
        assert counts['restored_field_pokemon']==len(entries)
        for gid,info in world['opening']['sprites'].items():
            if not info.get('sourcePng'):continue
            assert info['sourcePng'].startswith('graphics/pokemon/') and info['sourcePalette'].startswith('graphics/pokemon/')
            assert info['frameOrder']==([0,2,4,0,1,2,3,4,5,6,6,7] if info['asymmetric'] else [0,2,4] if info['standingOnly'] else [0,2,4,0,1,2,3,4,5])
            im=Image.open(source/info['sourcePng']);w,h=info['width'],info['height']
            pal=[tuple(round((int(v)>>3)*255/31) for v in row.split()) for row in (source/info['sourcePalette']).read_text().splitlines()[3:]]
            raw=(mod/'ow'/(gid+'.rgba')).read_bytes()
            for frame,original in enumerate(info['frameOrder']):
                for y in range(0,h,3):
                    for x in range(0,w,3):
                        n=im.getpixel(((original%(im.width//w))*w+x,(original//(im.width//w))*h+y))
                        pixel=pal[n]+(255 if n else 0,)
                        pos=(frame*w*h+y*w+x)*4
                        assert tuple(raw[pos:pos+4])==pixel,(gid,frame,x,y)
                        counts['source_field_pokemon_pixel_samples']+=1
            counts['source_field_pokemon_sheets']+=1
        center=source/'graphics/field_effects';pal=[tuple(round((int(v)>>3)*255/31) for v in row.split()) for row in (center/'palettes/pokeball_glow.pal').read_text().splitlines()[3:]]
        im=Image.open(center/'pics/pokeball_glow.png')
        assert (mod/'field_effects/pokeball_glow.idx').read_bytes()==im.tobytes()
        assert (mod/'field_effects/pokeball_glow.pal').read_bytes()==bytes(v for c in pal for v in c)
        im=Image.open(center/'pics/pokecenter_monitor/frlg.png');rgba=(mod/'field_effects/hns_center_monitor.rgba').read_bytes()
        for i,n in enumerate(im.tobytes()):
            assert tuple(rgba[i*4:i*4+4])==pal[n]+(255 if n else 0,)
            counts['source_healing_pixel_samples']+=1
    if world.get("campaign"):
        from PIL import Image
        wooper=next(v for v in world["opening"]["sprites"].values() if v["source"]=="OBJ_EVENT_GFX_MON_BASE+SPECIES_WOOPER")
        assert (wooper["width"],wooper["height"],wooper["frameCount"])==(32,32,9)
        png=Image.open(source/"graphics/pokemon/wooper/overworld.png")
        colors=[tuple(round((int(v)>>3)*255/31) for v in row.split())+(255,) for row in (source/"graphics/pokemon/wooper/overworld_normal.pal").read_text().splitlines()[3:]]
        raw=(mod/"ow"/(str(wooper["graphicsId"])+".rgba")).read_bytes()
        for frame,source_frame in enumerate([0,2,4,0,1,2,3,4,5]):
            for y in range(32):
                for x in range(32):
                    index=png.getpixel(((source_frame%(png.width//32))*32+x,(source_frame//(png.width//32))*32+y))
                    expected_pixel=colors[index][:3]+(255 if index else 0,)
                    offset=(frame*1024+y*32+x)*4
                    assert tuple(raw[offset:offset+4])==expected_pixel
                    counts["source_wooper_pixel_samples"]+=1
        eligible=json.loads((source/"src/data/pokemon/all_learnables.json").read_text())
        known=set(re.findall(r'"SPECIES_(\w+)"',(engine/"src/core/game3/constants/emerald/species.lua").read_text()))
        assert world["campaign"]["roostSpecies"]==[s for s,moves in sorted(eligible.items()) if 'MOVE_ROOST' in moves and s in known]
        counts["campaign_objects"]=len(world["campaign"]["objects"])
        counts["campaign_battles"]=len(world["campaign"]["battles"])
    if world.get("audio"):
        audio=world["audio"]
        mode=audio["soundMode"]
        sound_source=(source/"src/m4a.c").read_text()
        assert f'({mode["maxDsChannels"]} << SOUND_MODE_MAXCHN_SHIFT)' in sound_source
        assert mode["maxDsChannels"]==15 and mode["samplesPerVBlank"]==304 and mode["frequencySetting"]==18157
        native_seq=(engine/"src/core/game3/m4a_seq.lua").read_text()
        assert (mod/"hns_m4a_seq.lua").read_text()=='-- Derived from pinned Gen1Recomp m4a_seq.lua; source-scoped channel limit.\n'+native_seq.replace('if count >= MAX_DS then','if count >= (player.hnsMaxDsChannels or MAX_DS) then')
        songs=re.findall(r'^\s*song (\w+),',(source/"sound/song_table.inc").read_text(),re.M)
        song_ids={name.upper():audio["base"]+i for i,name in enumerate(songs)}
        for mid,m in maps.items():
            name=source_maps[m["hnsSourceId"]]["music"]
            expected_song=0 if name in ("MUS_NONE","MUS_DUMMY") else song_ids[name]
            assert m["music"]==audio["mapSongs"][mid]==expected_song
            counts["source_map_music"]+=1
        index=json.loads(subprocess.check_output([str(luajit),str(engine/"tools/lua_to_json.lua"),str(mod/"audio/index.lua")],text=True))
        at=lambda table,id:table[int(id)-1] if isinstance(table,list) else table[str(id)]
        sample_bytes=(mod/"audio/samples.bin").stat().st_size
        assert sample_bytes==audio["sampleBytes"]
        for id,name in audio["songs"].items():
            row=index["songs"][id]
            assert song_ids[name]==int(id)<0x4000 and row["name"]==name and row["tracks"]>0
            assert (mod/"audio/songs"/(id+".bin")).stat().st_size==row["songBytes"]
            at(index["voicegroups"],row["voicegroupId"])
            counts["source_songs"]+=1
        for sample in index["samples"] if isinstance(index["samples"],list) else index["samples"].values():
            assert sample["size"]>0 and 0<=sample["offset"]<sample["offset"]+sample["size"]<=sample_bytes
            counts["source_instrument_samples"]+=1
        fanfares=re.search(r'sFanfaresHnS\[\]\s*=\s*\{(.*?)\};',(source/"src/sound.c").read_text(),re.S)[1]
        assert {song_ids[n]:int(f) for n,f in re.findall(r'\{\s*(MUS_\w+),\s*(\d+)\s*\}',fanfares)}=={int(id):row["frames"] for id,row in audio["fanfares"].items()}
        # Source HGSS instrument 80 is National Park's split piano, stored
        # beyond main bank 229 in bank 230. Padding must not replace it.
        park=index["songs"][str(song_ids["MUS_HG_NATIONAL_PARK"])]
        tone=at(index["voicegroups"],park["voicegroupId"])["80"]
        assert tone["type"]==64 and tone["keySplit"]["60"]==3
        piano=at(index["voicegroups"],tone["subVgId"])["3"]
        assert at(index["samples"],piano["sampleId"])["size"]>0
    if world.get("encounters"):
        entries={e["base_label"]:e for g in json.loads((source/"src/data/wild_encounters.json").read_text())["wild_encounter_groups"] if g.get("for_maps") for e in g["encounters"]}
        fields={"land":"land_mons","water":"water_mons","rocks":"rock_smash_mons","fishing":"fishing_mons"}
        for mid,areas in world["encounters"]["tables"].items():
            src=entries[world["encounters"]["sources"][mid]]
            assert src["map"]==maps[mid]["hnsSourceId"]
            for kind,area in areas.items():
                original=src[fields[kind]]
                assert area["rate"]==original["encounter_rate"]>0
                assert area["slots"]==[{"species":m["species"][8:],"minLevel":m["min_level"],"maxLevel":m["max_level"]} for m in original["mons"]]
                counts["source_wild_areas"]+=1
                counts["source_wild_slots"]+=len(area["slots"])
        counts["wild_maps"]=len(world["encounters"]["tables"])
    if world.get("trainers"):
        bodies=dict(re.findall(r"^=== (TRAINER_\w+) ===\s*\n(.*?)(?=^=== |\Z)",(source/"src/data/trainers_hns.party").read_text(),re.M|re.S))
        symbol=lambda s:re.sub(r"[^A-Z0-9]+","_",s.upper()).strip("_")
        for record in world["trainers"]["records"].values():
            body=bodies[record["source"]]
            name=re.search(r"^Name: (.*)$",body,re.M)[1]
            assert record["name"]==name
            if world.get("audio"):
                cue=re.search(r'^Music: (.+)$',body,re.M)[1].removeprefix('Hg ').upper().replace(' ','_')
                if cue=='SILVER':cue='RIVAL'
                assert record["encounterMusic"]==song_ids['MUS_HG_ENCOUNTER_'+cue]
                counts["source_encounter_music"]+=1
            chunks=re.findall(r"^([^\n]+)\nLevel: (\d+)\n(.*?)(?=\n\s*\n|\Z)",body,re.M|re.S)
            assert len(chunks)==len(record["party"])
            for mon,(species,level,attributes) in zip(record["party"],chunks):
                species,_,held=species.partition(" @ ")
                assert (mon["species"],mon["level"])==(symbol(species),int(level))
                ivs=re.findall(r"\b(\d+)\s+(?:HP|Atk|Def|SpA|SpD|Spe)",attributes)
                assert len(ivs)==6 and all(int(v)==mon["iv"] for v in ivs)
                moves=re.findall(r"^- (.+)$",attributes,re.M)
                assert mon.get("moves",[])==[symbol(v) for v in moves]
                if held:assert mon["heldItem"]==symbol(held)
                counts["source_trainer_mons"]+=1
            counts["source_trainer_rosters"]+=1
        for event in world["trainers"]["events"]:
            original=source_maps[maps[event["map"]]["hnsSourceId"]]["object_events"][event["localId"]-1]
            obj=next(o for o in maps[event["map"]]["objects"] if o["localId"]==event["localId"])
            assert obj["trainerRange"]==int(original["trainer_sight_or_berry_tree_id"],0)
            assert obj["trainerType"]=={"TRAINER_TYPE_NORMAL":1,"TRAINER_TYPE_SEE_ALL_DIRECTIONS":3}[original["trainer_type"]]
        class_source=(source/"src/battle_main.c").read_text()
        for info in world["trainers"]["classes"].values():
            row=re.search(r"\["+re.escape(info["source"])+r"\]\s*=\s*\{\s*_\(\"([^\"]+)\"\)(?:\s*,\s*(\d+))?",class_source)
            assert row and info["name"]==row[1].replace("{PKMN}","POKéMON") and info["money"]==int(row[2] or 0)
        counts["trainer_maps"]=len({e["map"] for e in world["trainers"]["events"]})
        counts["trainer_portraits"]=len(world["trainers"]["portraits"])
        for info in world["trainers"]["portraits"].values():assert len((mod/info["file"]).read_bytes())==64*64*4
    for center,target in world["worldEvents"]["healCheckpoints"].items():
        source_id=maps[center]["hnsSourceId"]
        rows=json.loads((source/"src/data/heal_locations.json").read_text())["heal_locations"]
        heal=next(h for h in rows if h.get("respawn_map")==source_id)
        assert (target["map"],target["x"],target["y"])==(ids[heal["map"]],heal["x"],heal["y"])
    if world.get("pokedex"):
        dex=world["pokedex"]
        header=(source/"include/constants/pokedex.h").read_text()
        part=header[header.index("    JOHTO_DEX_NONE,"):header.index("#define JOHTO_DEX_COUNT")]
        names=re.findall(r"JOHTO_DEX_(\w+),",part)[1:]
        assert [(e["number"],e["speciesName"]) for e in dex["entries"]]==list(enumerate(names,1))
        known=set(re.findall(r'"SPECIES_(\w+)"',(engine/"src/core/game3/constants/emerald/species.lua").read_text()))
        assert all(e["supported"]==(e["speciesName"] in known) for e in dex["entries"])
        counts["source_johto_numbers"]=len(names)
        counts["supported_johto_species"]=sum(e["supported"] for e in dex["entries"])
        # Independent pixel sampling directly from source PNG indices, tilemap
        # entries, flips and RGB555 palette rather than the converter renderer.
        from PIL import Image
        base=source/"graphics/pokedex/hgss"
        rgb=[tuple(round((int(v)>>3)*255/31) for v in row.split())+(255,) for row in (base/"palette_default.pal").read_text().splitlines()[3:]]
        for name,filename,tilemaps in [("list","tileset_menu_list.png",["tilemap_list_screen_underlay.bin","tilemap_list_screen.bin"]),("info","tileset_menu1.png",["tilemap_info_screen.bin"])]:
            data=(mod/dex["backgrounds"][name]).read_bytes();assert len(data)==240*160*4
            tiles=Image.open(base/filename)
            tables=[struct.unpack("<"+"H"*((base/tm).stat().st_size//2),(base/tm).read_bytes()) for tm in tilemaps]
            for y in range(0,160,5):
                for x in range(0,240,5):
                    expected=rgb[1]
                    for table in tables:
                        word=table[(y//8)*32+x//8];n=word&1023
                        ix=(7-x%8) if word&1024 else x%8;iy=(7-y%8) if word&2048 else y%8
                        index=tiles.getpixel(((n%(tiles.width//8))*8+ix,(n//(tiles.width//8))*8+iy))
                        if index:expected=rgb[(word>>12)*16+index]
                    pos=(y*240+x)*4;assert tuple(data[pos:pos+4])==expected,(name,x,y)
                    counts["source_pokedex_pixel_samples"]+=1
    if baseline:
        old=json.loads(subprocess.check_output([str(luajit),str(engine/"tools/lua_to_json.lua"),str(baseline/"world.lua")],text=True))
        for mid,m in old["maps"].items():
            assert (baseline/m["hnsLayoutFile"]).read_bytes()==(mod/maps[mid]["hnsLayoutFile"]).read_bytes()
        for pair in old["pairs"]:
            for name in ("mids.idx","mids_over.idx","mids_mid.idx"):
                def pixels(path):
                    raw=path.read_bytes();count=struct.unpack_from("<H",raw,6)[0]
                    mids=struct.unpack_from(f"<{count}H",raw,12)
                    return {mid:raw[12+count*2+i*256:12+count*2+(i+1)*256] for i,mid in enumerate(mids)}
                before=pixels(baseline/"native"/pair/name);after=pixels(mod/"native"/pair/name)
                assert all(after[mid]==data for mid,data in before.items()),(pair,name)
            assert (baseline/"native"/pair/"palettes.bin").read_bytes()==(mod/"native"/pair/"palettes.bin").read_bytes()
        for gid,info in old["opening"]["sprites"].items():
            new=world["opening"]["sprites"][gid]
            assert (new["source"],new["width"],new["height"])==(info["source"],info["width"],info["height"])
            before=(baseline/"ow"/(gid+".rgba")).read_bytes();after=(mod/"ow"/(gid+".rgba")).read_bytes()
            assert after[:len(before)]==before,"standing pixels changed: "+gid
            if new["frameCount"]==info["frameCount"]:
                assert (baseline/"ow"/(gid+".meta")).read_bytes()==(mod/"ow"/(gid+".meta")).read_bytes()
            else:
                assert info["frameCount"]==3 and new["frameCount"]>=9,"unexpected sprite change: "+gid
                counts["extended_walking_sheets"]+=1
        assert old["opening"]["flags"]==world["opening"]["flags"] and old["opening"]["vars"]==world["opening"]["vars"]
        # Reconstruct every intentional 0.6.5 replacement from 0.6.4 and
        # direct source movements. Unlisted scripts still compare byte-for-byte.
        corrections={}
        if world['startup'].get('helpNative') and old['startup'].get('gearFlag') and not old['startup'].get('helpNative'):
            def op(name,**kw):return {'op':name,**kw}
            def movement(label,lid):
                filenames=['data/maps/NewBarkTown_hns/scripts.inc','data/maps/NewBarkTown_Lab_hns/scripts.inc','data/scripts/movement.inc']
                found=[]
                for f in filenames:
                    c=(source/f).read_text();m=re.search(r'^'+label+r'::?\s*\n(.*?)(?=^\w+::?|\Z)',c,re.M|re.S)
                    if not m:continue
                    for line in m[1].splitlines():
                        n=line.split('@')[0].strip().upper()
                        if not n:continue
                        if n in ('WALK_UP','WALK_DOWN','WALK_LEFT','WALK_RIGHT'):n=n.replace('WALK_','WALK_NORMAL_',1)
                        found.append('MOVEMENT_ACTION_'+n)
                    break
                assert found,label
                return op('applymovement',localId=lid,movementNames=found)
            def move(label,lid):return [movement(label,lid),op('waitmovement',localId=lid)]
            def msg(label,prompt=False):return [op('message',ptr='HNS_POLISH_'+label),op('waitmessage'),op('yesnobox' if prompt else 'waitbuttonpress'),op('closemessage')]
            done=[op('releaseall'),op('end')]
            for name in ('CHIKORITA','CYNDAQUIL','TOTODILE'):
                key='HNS_OPENING_'+name;rows=old['scripts'][key][:]
                at=next(i for i,r in enumerate(rows)if r['op']=='bufferstring');rows.insert(at,op('showmonpic',speciesName=name,x=10,y=3));corrections[key]=rows
                rows=old['scripts'][key+'_GIFT'][:];at=next(i for i,r in enumerate(rows)if r.get('ptr')=='HNS_OPENING_NewBarkTown_Lab_Text_ElmLetYourMonBattle');rows=rows[:at]
                rows.insert(1,{'op':'copyvar','1':0x8005,'2':0x800D});rows.insert(0,op('hidemonpic'))
                corrections[key+'_GIFT']=rows+[op('compare_var_to_value',var=0x8005,value=0),op('goto_if',cond=0,target='HNS_POLISH_FINISH')]+msg('NewBarkTown_Lab_Text_Nickname',True)+[op('compare_var_to_value',var=0x800D,value=1),op('goto_if',cond=1,target='HNS_POLISH_NICKNAME')]+done
            corrections['HNS_OPENING_DECLINE']=[op('hidemonpic')]+old['scripts']['HNS_OPENING_DECLINE']
            for key in ('HNS_STARTUP_CLOCK1','HNS_STARTUP_CLOCK2'):corrections[key]=old['scripts'][key][:-6]+[op('callnative',fn=0x484E5309),op('waitstate')]+done
            corrections['HNS_FIDELITY_ELM_WAIT']=old['scripts']['HNS_FIDELITY_ELM_WAIT'][:-1]+[op('turnobject',localId=255,direction=2)]+done
            rows=old['scripts']['HNS_SCENE_ELM_ACCEPT'][:];at=next(i for i,r in enumerate(rows)if r.get('movementNames')==movement('Common_Movement_QuestionMark',2)['movementNames'])
            rows[at:at+2]=[op('delay',frames=30),op('playse',seName='SE_PC_LOGIN'),op('waitse'),op('playse',seName='SE_PIN'),movement('Common_Movement_QuestionMark',2),op('delay',frames=55),op('waitmovement',localId=2)]
            for a,b in [('NewBarkTown_Lab_Movement_CheckEmail','NewBarkTown_Lab_Movement_Look_Left'),('NewBarkTown_Lab_Movement_ReturnFromEmail','NewBarkTown_Lab_Movement_Look_Up')]:
                at=next(i for i,r in enumerate(rows)if r.get('movementNames')==movement(a,2)['movementNames']);rows[at:at+4]=[movement(a,2),movement(b,255),op('waitmovement',localId=2),op('waitmovement',localId=255)]
            corrections['HNS_SCENE_ELM_ACCEPT']=rows
            corrections['HNS_FIDELITY_WINDOW']=[op('lockall')]+msg('NewBarkTown_Text_Silver1')+[op('delay',frames=60),op('playse',seName='SE_PIN')]+move('Common_Movement_ExclamationMark',3)+[op('faceplayer')]+msg('NewBarkTown_Text_Silver2')+[op('playse',seName='SE_BANG'),movement('NewBarkTown_Movement_SilverPushesPlayer',3),movement('NewBarkTown_Movement_PlayerPushedBySilver',255),op('waitmovement',localId=3),op('waitmovement',localId=255)]+move('Common_Movement_FaceOriginalDirection',3)+done
            counts['reviewed_065_script_replacements']=len(corrections)
        if world['startup'].get('rules') and not old['startup'].get('rules'):
            for key,target in [('HNS_OPENING_MOM','MOM'),('HNS_FIDELITY_TOWN_INIT','TOWN_RETURN'),('HNS_FIDELITY_BLOCK_EXIT','BLOCK_MOM')]:
                corrections[key]=[{'op':'checkflag','flag':0x6005},{'op':'goto_if','cond':1,'target':'HNS_RULES_'+target}]+old['scripts'][key]
            corrections['HNS_OPENING_MOM_AFTER']=[{'op':'message','ptr':'HNS_RULES_NewBarkTown_PlayersHouse_1F_Text_MomHurryUpElmIsWaiting'},{'op':'waitmessage'},{'op':'waitbuttonpress'},{'op':'closemessage'},{'op':'releaseall'},{'op':'end'}]
            key='HNS_FIDELITY_LASS'
            corrections[key]=old['scripts'][key][:2]+[{'op':'checkflag','flag':0x6005},{'op':'goto_if','cond':1,'target':'HNS_RULES_LASS_RETURN'}]+old['scripts'][key][2:]
            counts['reviewed_066_script_replacements']=5
        changed=set(world.get("quest",{}).get("changedPriorScripts",[]))
        reviewed={"HNS_OPENING_ELM","HNS_OPENING_AIDE1","HNS_OPENING_ELM_AFTER",
                  "HNS_OPENING_CHIKORITA_GIFT","HNS_OPENING_CYNDAQUIL_GIFT","HNS_OPENING_TOTODILE_GIFT",
                  "HNS_SCENE_LAB_INIT","HNS_SCENE_LAB_COMPUTER","HNS_STARTUP_CLOCK1","HNS_STARTUP_CLOCK2","HNS_STARTUP_MOM"}
        assert changed<=reviewed
        for key,script in old["scripts"].items():
            new=world["scripts"][key]
            if key in corrections:assert new==corrections[key],key
            elif new==script:continue
            elif key=='HNS_FIDELITY_ELM_DIRECTIONS' and world.get('services'):
                assert new==script[:-2]+[{'op':'compare_var_to_value','var':0x800C,'value':4},{'op':'goto_if','cond':1,'target':'HNS_FIDELITY_FINISH'},{'op':'setflag','flag':0x602F}]+script[-2:]
                counts['reviewed_070_condition_unlock']=1
            elif key=="HNS_OPENING_ELM_AFTER":
                assert world['scripts']['HNS_FIDELITY_ELM_AFTER_DONE']==script
                assert new==[{'op':'checkflag','flag':0x6026},{'op':'goto_if','cond':1,'target':'HNS_FIDELITY_ELM_AFTER_DONE'},{'op':'goto','target':'HNS_FIDELITY_ELM_DIRECTIONS'}]
            elif key=="HNS_SCENE_LAB_COMPUTER":
                assert world['scripts']['HNS_FIDELITY_LAB_COMPUTER_DONE']==script
                assert new==[{'op':'checkflag','flag':0x6026},{'op':'goto_if','cond':1,'target':'HNS_FIDELITY_LAB_COMPUTER_DONE'},{'op':'setvar','var':0x7009,'value':1},{'op':'end'}]
            elif key=="HNS_SCENE_LAB_INIT":
                assert new[0]=={'op':'setvar','var':0x7009,'value':0} and new[1:]==script
            elif key in {"HNS_OPENING_CHIKORITA_GIFT","HNS_OPENING_CYNDAQUIL_GIFT","HNS_OPENING_TOTODILE_GIFT"}:
                row={'op':'setvar','var':0x7009,'value':1};assert new.count(row)==1
                pos=new.index(row);assert new[pos-1]=={'op':'setflag','flag':0x6001}
                assert new[:pos]+new[pos+1:]==script
            elif key in {"HNS_STARTUP_CLOCK1","HNS_STARTUP_CLOCK2"}:
                assert new[-6:-2]==[{'op':'message','ptr':'HNS_FIDELITY_CLOCK_HELP'},{'op':'waitmessage'},{'op':'waitbuttonpress'},{'op':'closemessage'}]
                assert new[:-6]+new[-2:]==script
            elif key=="HNS_STARTUP_MOM":
                pos=next(i for i,r in enumerate(new)if r.get('songName')=='MUS_HG_POKEGEAR_REGISTERED')
                assert new[pos:pos+12]==[{'op':'playfanfare','songName':'MUS_HG_POKEGEAR_REGISTERED'},
                    {'op':'message','ptr':'HNS_FIDELITY_NewBarkTown_PlayersHouse_1F_Text_ObtainedPokeGear'}, {'op':'waitmessage'}, {'op':'waitbuttonpress'}, {'op':'closemessage'},
                    {'op':'waitfanfare'},{'op':'setflag','flag':0x6025},{'op':'setflag','engineFlagName':'FLAG_SYS_POKENAV_GET'},
                    {'op':'message','ptr':'HNS_FIDELITY_NewBarkTown_PlayersHouse_1F_Text_ExplainPokeGear'}, {'op':'waitmessage'}, {'op':'waitbuttonpress'}, {'op':'closemessage'}]
                assert new[:pos]+new[pos+12:]==script
            elif key in changed:assert new[-len(script):]==script,key
            else:assert new==script,key
        counts["preserved_prior_maps"] = len(old["maps"])
    return {"result":"pass","map_count":len(maps),"regions":dict(regions),"counts":dict(counts)}


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    for name in ("source","engine","mod","luajit"):p.add_argument("--"+name,type=Path,required=True)
    p.add_argument("--baseline",type=Path);p.add_argument("--report",type=Path)
    a=p.parse_args()
    result=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve(),a.baseline.resolve() if a.baseline else None)
    if a.report:a.report.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))
