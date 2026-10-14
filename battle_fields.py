"""Reviewed source field rules and five duration items; no free story rewards."""
import json,re,subprocess,tempfile
from pathlib import Path

ITEMS={'DAMP_ROCK':945,'HEAT_ROCK':946,'SMOOTH_ROCK':947,'ICY_ROCK':948,'TERRAIN_EXTENDER':949,
       'ELECTRIC_SEED':950,'GRASSY_SEED':951,'MISTY_SEED':952,'PSYCHIC_SEED':953}
SEEDS={'ELECTRIC_SEED':('ELECTRIC','defense'),'GRASSY_SEED':('GRASSY','defense'),
       'MISTY_SEED':('MISTY','spDef'),'PSYCHIC_SEED':('PSYCHIC','spDef')}


def build(source,quest):
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/battle.h"\n#include "config/item.h"\n'
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "data/items.h"\n',text=True)
    rows=dict(re.findall(r'\[ITEM_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[ITEM_|\Z)',body,re.S))
    expressions={n:re.search(r'\.price\s*=\s*([^,]+)',rows[n])[1]for n in ITEMS}
    code='#include <stdio.h>\n'+prefix+'int main(void){'+''.join('printf("'+n+' %d\\n",'+v+');'for n,v in expressions.items())+'printf("BOOST %d\\nBG_CHANGE %d\\nNEW_BG %d\\n",B_TERRAIN_TYPE_BOOST,B_TERRAIN_BG_CHANGE,B_NEW_TERRAIN_BACKGROUNDS);}'
    with tempfile.TemporaryDirectory()as tmp:
        root=Path(tmp);(root/'oracle.c').write_text(code)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(root/'oracle.c'),'-o',str(root/'oracle')],check=True)
        values={n:int(v)for n,v in (line.split()for line in subprocess.check_output([str(root/'oracle')],text=True).splitlines())}
    items={}
    for n,index in ITEMS.items():
        r=rows[n];desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',r,re.S)[1]
        name=re.search(r'\.name\s*=\s*(?:ITEM_NAME|COMPOUND_STRING(?:_SIZE_LIMIT)?)\("([^"]+)"',r)[1]
        effect=re.search(r'\.holdEffect\s*=\s*HOLD_EFFECT_(\w+)',r)[1];key='HNS_'+n
        record={'id':key,'index':index,'name':name,'price':values[n],'description':''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',desc)),
                'importance':0,'registrability':0,'battleUsage':0,'fieldUse':'none','pocket':'ITEMS','holdEffect':0}
        quest['items'][key]=record;items[n]={'index':index,'effect':effect,'record':record}
        if n in SEEDS:items[n].update(terrain=SEEDS[n][0],stat=SEEDS[n][1])
    text={};body=(source/'src/battle_message.c').read_text()
    for n,r in re.findall(r'\[(STRINGID_\w*TERRAIN\w*)\]\s*=\s*COMPOUND_STRING\((.*?)\),',body,re.S):
        text[n]=''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',r)).replace('{B_SCR_NAME_WITH_PREFIX}','{B_SCR_ACTIVE_NAME_WITH_PREFIX}')
    assert 'STRINGID_GRASSYTERRAINHEALS'in text
    return {'items':items,'texts':text,'terrainTurns':5,'extendedTurns':8,'typeBoost':5325 if values['BOOST']>=8 else 6144,
            'backgroundChanges':bool(values['BG_CHANGE']),'newBackgrounds':bool(values['NEW_BG']),
            'limits':'Core terrains, eight terrain-dependent attacks, source backgrounds and weather/terrain duration items. Four seeds and Surge entry handlers are connected; automatic source ability assignment, other terrain abilities and remaining field rules are pending. Item rewards/shops are not invented.'}
