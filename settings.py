"""Source-derived HnS challenge and option page descriptors; stable saved vars."""
import re
import json

VAR_BASE=0x7100

def strings(body):
    return [json.loads('"'+s+'"').replace('{PKMN}','POKéMON') for s in re.findall(r'(?:COMPOUND_STRING|_)\(\s*"((?:\\.|[^"\\])*)"\s*\)',body)]

def build(source):
    defaults=dict(re.findall(r'challengeSettings\.(\w+)\s*=\s*(\d+)',(source/'src/new_game.c').read_text()))
    defaults={k:int(v) for k,v in defaults.items()}
    defaults['tx_Random_GenScope']=1
    pages=[];n=0
    native={'ITEM_MAIN_TEXTSPEED':'textSpeed','ITEM_MAIN_BATTLESCENE':'battleScene','ITEM_MAIN_BATTLESTYLE':'battleStyle','ITEM_MAIN_BUTTONMODE':'buttonMode','ITEM_MAIN_FRAMETYPE':'frameType','ITEM_SOUND_SOUND':'sound'}
    for filename,kind in [('challenge_menu.c','challenge'),('option_menu.c','option')]:
        src=(source/'src'/filename).read_text()
        arrays={name:strings(body) for name,body in re.findall(r'static const u8 \*const (\w+)\[\]\s*=\s*\{(.*?)\};',src,re.S)}
        locks=dict(re.findall(r'\[TAB_\w+\s*\*\s*MAX_ITEMS_PER_TAB\s*\+\s*(\w+)\]\s*=\s*LOCK_(\w+)',src))
        # Source load expressions determine polarity and recommended selections.
        selections={}
        for item,neg,field in re.findall(r'\*GetSelectionPtr\(\w+,\s*(\w+)\)\s*=\s*(!?)cs->(\w+)\s*;',src):
            v=defaults.get(field,0);selections[item]=int(not v) if neg else v
        for tab,body in re.findall(r'static const struct (?:Challenge|Option)MenuItem sTabItems_(\w+)\[\]\s*=\s*\{(.*?)\n\};',src,re.S):
            rows=[]
            for item,row in re.findall(r'\[(\w+)\]\s*=\s*\{(.*?)\n    \},',body,re.S):
                name=strings(row)[0]
                choice=re.search(r'\.choiceNames\s*=\s*(\w+)',row).group(1)
                opts=arrays.get(choice,[])
                if item=='ITEM_MAIN_FRAMETYPE':opts=[str(i+1) for i in range(20)]
                if item=='ITEM_CHALLENGES_ONE_TYPE':
                    types=dict(re.findall(r'\[TYPE_(\w+)\].*?\.name\s*=\s*_\("([^\"]+)"\)',(source/'src/data/types_info.h').read_text(),re.S))
                    names=('NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST','STEEL','FIRE','WATER','GRASS','ELECTRIC','PSYCHIC','ICE','DRAGON','DARK','FAIRY')
                    opts=[types[name] for name in names]+['RANDOM','OFF']
                desc=re.search(r'\.descriptions\s*=\s*(\w+)',row).group(1)
                descriptions=arrays.get(desc,[])
                if item=='ITEM_CHALLENGES_ONE_TYPE':
                    value=re.search(r'sText_Desc_OneType\[\].*?=\s*_\("((?:\\.|[^"\\])*)"\)',src,re.S)[1]
                    descriptions=[json.loads('"'+value+'"').replace('{PKMN}','POKéMON')]*20
                default=selections.get(item,0)
                if item=='ITEM_CHALLENGES_ONE_TYPE':default=19
                # Options load directly from SaveBlock; OnOff has inverted polarity.
                option_defaults={'ITEM_MAIN_TEXTSPEED':2,'ITEM_MAIN_FOLLOWER':1,'ITEM_MAIN_LARGE_FOLLOWER':1,'ITEM_MAIN_FISHING':1,'ITEM_BATTLE_FAST_BATTLES':1,'ITEM_BATTLE_BALL_PROMPT':1,'ITEM_BATTLE_LR_RUN':1,'ITEM_SOUND_BIKE_MUSIC':1,'ITEM_SOUND_SURF_MUSIC':1}
                if kind=='option':default=option_defaults.get(item,0)
                if opts and default>=len(opts):raise ValueError((item,default,opts))
                rows.append({'id':item,'name':name,'choices':opts,'descriptions':descriptions,'default':default,'var':VAR_BASE+n,'native':native.get(item),'implemented':item in native or item=='ITEM_MAIN_UNIT_TYPE','lock':locks.get(item,'FREE')})
                n+=1
            pages.append({'id':tab.upper(),'name':{'MAIN':'OPTIONS','BATTLE':'BATTLE OPTIONS'}.get(tab.upper(),tab.upper()),'kind':kind,'rows':rows})
    assert len(pages)==9
    return {'pages':pages,'varBase':VAR_BASE,'initializedFlag':0x6029,'choiceCount':n}
