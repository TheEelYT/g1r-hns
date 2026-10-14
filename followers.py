"""Source follower sprites for every species supported by the native engine."""
import json
import re
import opening
from PIL import Image


def build(source,engine,stage,opening_data,scripts,palette_parser):
    names=set(re.findall(r'"SPECIES_(\w+)"',(engine/'src/core/game3/constants/emerald/species.lua').read_text()))
    aliases={'UNOWN_EMARK':'UNOWN_EXCLAMATION','UNOWN_QMARK':'UNOWN_QUESTION'}
    species={};omitted=[]
    for name in sorted(names):
        if name in ('NONE','EGG') or name.startswith('OLD_UNOWN'):continue
        source_name=aliases.get(name,name);entry={}
        for shiny in (False,True):
            gid=50000+len(species)*2+int(shiny)
            gfx='OBJ_EVENT_GFX_SPECIES(SPECIES_'+source_name+')'+(' | OBJ_EVENT_MON_SHINY' if shiny else '')
            meta=opening.sprite(source,gfx,gid,stage,palette_parser)
            opening_data['sprites'][str(gid)]=meta
            entry['shiny' if shiny else 'normal']=gid;entry['width']=meta['width'];entry['height']=meta['height'];entry['shadowSize']=meta['shadowSize']
        species[name]=entry
    texts='\n'.join((source/p).read_text() for p in ('src/data/text/follower_messages.h','src/follower_helper.c'))
    messages={}
    for name,body in re.findall(r'(\w+)\[\]\s*=\s*_\((.*?)\);',texts,re.S):
        if not re.search(r'(Msg|Text)',name):continue
        chunks=re.findall(r'"(?:[^"\\]|\\.)*"',body)
        if chunks:messages[name]=''.join(json.loads(c)for c in chunks).replace('{PKMN}','POKéMON')
    scripts['HNS_FOLLOWER_TALK']=[{'op':'end'}]
    ball=opening.sprite(source,'OBJ_EVENT_GFX_POKE_BALL',59999,stage,palette_parser)
    opening_data['sprites']['59999']=ball
    im=Image.open(source/'graphics/misc/emotes.png');colors=palette_parser(source/'graphics/misc/emotes.pal')
    raw=bytearray()
    for n in im.tobytes():
        c=colors[n];raw.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if n else 0))
    file='ow/follower_emotes.rgba';(stage/file).write_bytes(raw)
    movement=(source/'src/event_object_movement.c').read_text()
    jump=list(map(int,re.findall(r'-?\d+',re.search(r'sJumpY_High\[\]\s*=\s*\{(.*?)\}',movement,re.S)[1])))
    jump_normal=list(map(int,re.findall(r'-?\d+',re.search(r'sJumpY_Normal\[\]\s*=\s*\{(.*?)\}',movement,re.S)[1])))
    anims=(source/'src/data/object_events/object_event_anims.h').read_text()
    def anim(name):
        body=re.search(r'\b'+name+r'\[\]\s*=\s*\{(.*?)\};',anims,re.S)[1]
        return [tuple(map(int,m))for m in re.findall(r'ANIMCMD_FRAME\((\d+),\s*(\d+)',body)]
    walk=anim('sAnim_GoSouth2F');run=anim('sAnim_GoFastSouth2F')
    assert [r[0]for r in walk]==[r[0]for r in run]and len({r[1]for r in walk})==len({r[1]for r in run})==1
    positions=list(map(int,re.search(r'\.anims = sAnimTable_Following,\s*\.animPos = \{([^}]+)',anims)[1].split(',')))
    bob=re.search(r'#define OW_FOLLOWERS_BOBBING\s+(\w+)',(source/'include/config/overworld.h').read_text())[1]=='TRUE'
    return {'species':species,'messages':messages,'disabledFlag':0x6060,'ball':ball,'motion':{'jumpY':jump,'jumpNormalY':jump_normal,'bobbing':bob,'idleFrames':16,'poseImages':[r[0]for r in walk],'walkPoseDuration':walk[0][1],'runPoseDuration':run[0][1],'animPositions':positions},
            'emotes':{'file':file,'width':im.width,'height':im.height,'durations':[30,25,30]},
            'limits':'Native species, shiny palettes, trailing steps, source ball transitions and basic named dialogue/emotes. Full conditional interaction scripts, caught-ball variants and female-specific graphics remain pending.'}
