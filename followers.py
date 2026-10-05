"""Source follower sprites for every species supported by the native engine."""
import json
import re
import opening


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
            entry['shiny' if shiny else 'normal']=gid;entry['width']=meta['width'];entry['height']=meta['height']
        species[name]=entry
    texts='\n'.join((source/p).read_text() for p in ('src/data/text/follower_messages.h','src/follower_helper.c'))
    messages={}
    for name,body in re.findall(r'(\w+)\[\]\s*=\s*_\((.*?)\);',texts,re.S):
        if not re.search(r'(Msg|Text)',name):continue
        chunks=re.findall(r'"(?:[^"\\]|\\.)*"',body)
        if chunks:messages[name]=''.join(json.loads(c)for c in chunks).replace('{PKMN}','POKéMON')
    scripts['HNS_FOLLOWER_TALK']=[{'op':'end'}]
    return {'species':species,'messages':messages,'disabledFlag':0x6060,
            'limits':'Native species, shiny palettes, trailing steps and basic source dialogue. Conditional emotes, emerge/retract effects and female-specific graphics remain pending.'}
