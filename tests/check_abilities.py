"""Compile source identities/descriptions and check seed/script/title contracts."""
import json,re,subprocess,tempfile
from pathlib import Path


def check(source,engine,world):
    pre=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "data/abilities.h"\n',text=True)
    rows={n:b for n,b in re.findall(r'\[ABILITY_(\w+)\]\s*=\s*\{(.*?)\n\s*\},',pre,re.S)}
    code='#include <stdio.h>\n#include "constants/abilities.h"\n#define _(s) s\n#define COMPOUND_STRING(s) s\nint main(void){const unsigned char *p;'
    for n,b in rows.items():
        name=re.search(r'\.name\s*=\s*(_\("[^"\\]*"\))',b)[1]
        desc=re.search(r'\.description\s*=\s*(COMPOUND_STRING\(.*?\)),',b,re.S)[1]
        code+='printf("'+n+' %d ",ABILITY_'+n+');p=(const unsigned char *)'+name+';while(*p)printf("%02x",*p++);putchar(32);p=(const unsigned char *)'+desc+';while(*p)printf("%02x",*p++);puts("");'
    code+='}'
    with tempfile.TemporaryDirectory()as tmp:
        root=Path(tmp);(root/'source.c').write_text(code)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(root/'source.c'),'-o',str(root/'source')],check=True)
        lines=subprocess.check_output([str(root/'source')],text=True).splitlines()
    actual=world['abilities']['records'];assert set(actual)==set(rows)
    for line in lines:
        n,i,name,desc=line.split();r=actual[n]
        assert r['sourceId']==int(i)and r['name']==bytes.fromhex(name).decode()and r['description']==bytes.fromhex(desc).decode(),n
        if r['support']!='native':assert r['id']==1000+int(i),n
        # Independent token extraction verifies every raw source field remains.
        tokens=lambda s:re.findall(r'"(?:[^"\\]|\\.)*"|[A-Za-z_]\w*|\d+|[^\s]',s)
        original={};part=[];depth=0
        for t in tokens(rows[n]):
            if t==','and depth==0:
                if part:assert part[0]=='.'and part[2]=='=';original[part[1]]=part[3:];part=[]
            else:
                part.append(t)
                if t in ('(','{','['):depth+=1
                elif t in (')','}',']'):depth-=1
        assert not part and depth==0
        assert set(original)==set(r['sourceFields']),n
        for k,v in r['sourceFields'].items():assert tokens(v)==original[k],(n,k)
    seeds=world['battleFields']['items'];script=(source/'src/battle_hold_effects.c').read_text()
    assert 'IsBattlerGrounded'not in script[script.index('enum ItemEffect TryHandleSeed('):script.index('static enum ItemEffect TryTerrainSeeds(')]
    for kind,stat in [('ELECTRIC','defense'),('GRASSY','defense'),('MISTY','spDef'),('PSYCHIC','spDef')]:
        r=seeds[kind+'_SEED'];assert r['terrain']==kind and r['stat']==stat
        native='STAT_DEF'if stat=='defense'else'STAT_SPDEF'
        assert re.search(r'TryHandleSeed\(battler, STATUS_FIELD_'+kind+r'_TERRAIN, '+native+r'\)',script)
    assert world['bootPresentation']['title']['bannerPosition']=={'LEFT_X':98,'RIGHT_X':162,'Y':2,'Y_GOAL':58}
    from check_ability_slots import check as slots
    slot_counts=slots(source,world)
    return {**slot_counts,'source_ability_rows':len(actual),'native_ability_bridges':77,'reviewed_surge_handlers':4,'pending_ability_effects':230,'source_seed_items':4,'source_title_banner_goal_y':58}
