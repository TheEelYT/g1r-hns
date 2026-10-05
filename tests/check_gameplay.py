"""Audit source battle parameters using a C compiler as the expression oracle.

Independent of the converter: all 354 native moves and 361 matchups are
compared with pinned C data/config, plus source farewell and jingle targets.
"""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path


def check(source, engine, mod, luajit):
    world=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')],text=True))
    rules=world['startup']['rules']
    native=set(re.findall(r'MOVE_(\w+)',(engine/'src/core/game3/constants/emerald/moves.lua').read_text()))-{'NONE','UNAVAILABLE'}
    aliases={'VISE_GRIP':'VICE_GRIP','HIGH_JUMP_KICK':'HI_JUMP_KICK','FEINT_ATTACK':'FAINT_ATTACK','SMELLING_SALTS':'SMELLING_SALT'}
    includes=['config/general.h','config/battle.h','config/contest.h','data/moves_info.h']
    pre=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n'+''.join('#include "'+f+'"\n'for f in includes),text=True)
    types=re.search(r'enum __attribute__\(\(packed\)\) Type\s*\{(.*?)\};',(source/'include/constants/pokemon.h').read_text(),re.S)[1]
    type_names={int(n):name for name,n in re.findall(r'TYPE_(\w+)\s*=\s*(\d+)',types)}
    c='#include <stdio.h>\n#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\nenum Type {'+types+'};\nenum {DAMAGE_CATEGORY_PHYSICAL,DAMAGE_CATEGORY_SPECIAL,DAMAGE_CATEGORY_STATUS};\n'
    c+='enum {CONTEST_CATEGORY_COOL,CONTEST_CATEGORY_BEAUTY,CONTEST_CATEGORY_CUTE,CONTEST_CATEGORY_SMART,CONTEST_CATEGORY_TOUGH};\n'
    matchup=(source/'src/data/types_info.h').read_text()
    definitions='\n'.join(line for line in matchup.splitlines() if line.startswith('#define '))
    table=matchup.split('gTypeEffectivenessTable')[1].split('=',1)[1].split('\n};')[0]
    c+='#define UQ_4_12(x) ((x)*10)\n'+definitions+'\nstatic const double matchups[21][21]='+table+'\n};\nint main(void){\n'
    names=[]
    for entry in re.finditer(r'\[MOVE_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[MOVE_|\Z)',pre,re.S):
        name=aliases.get(entry[1],entry[1])
        if name!='NONE':
            fields=[re.search(r'\.'+field+r'\s*=\s*([^,]+),',entry[2])[1]for field in ('power','accuracy','type','category')]
            c+='printf("DISPLAY '+name+' %d %d %d %d\\n",'+','.join(fields)+');\n'
        if name not in native:continue
        fields=[]
        for field in ('power','accuracy','pp','priority','type','category'):
            fields.append(re.search(r'\.'+field+r'\s*=\s*([^,]+),',entry[2])[1])
        c+='printf("MOVE '+name+' %d %d %d %d %d %d\\n",'+','.join(fields)+');\n'
        ce=re.search(r'\.contestEffect\s*=\s*([^,]+),',entry[2])[1]
        cc=re.search(r'\.contestCategory\s*=\s*([^,]+),',entry[2])[1]
        c+='printf("CONTEST '+name+' %d %d\\n",'+ce+','+cc+');\n'
        names.append(name)
    c+='for(int a=1;a<20;a++)for(int d=1;d<20;d++)printf("TYPE %d %d %.0f\\n",a-1,d-1,matchups[a][d]);\nreturn 0;}\n'
    assert set(names)==native and len(names)==354
    with tempfile.TemporaryDirectory() as temp:
        root=Path(temp);(root/'oracle.c').write_text(c)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(root/'oracle.c'),'-o',str(root/'oracle')],check=True)
        results=subprocess.check_output([str(root/'oracle')],text=True)
    counts={'source_move_rows':0,'source_matchups':0,'source_contest_move_rows':0}
    effects_pp=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/contest.h"\n#include "constants/contest.h"\n#include "data/contest_moves.h"\n',text=True)
    effects={}
    for n,b in re.findall(r'\[(\d+)\]\s*=\s*\{(.*?)(?=\n\s*\[\d+\]|\n};)',effects_pp,re.S):
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',b,re.S)
        effects[int(n)]={'description':''.join(json.loads(q)for q in re.findall(r'"(?:[^"\\]|\\.)*"',desc[1])),'appeal':int(re.search(r'\.appeal\s*=\s*(\d+)',b)[1])//10,'jam':int(re.search(r'\.jam\s*=\s*(\d+)',b)[1])//10}

    # Let C concatenate/escape the source description literals independently.
    desc_c='#include <stdio.h>\n#define _(x) x\n#define COMPOUND_STRING(x) x\n'
    for variable,body in re.findall(r'static const u8 (s\w+)\[\]\s*=\s*_\((.*?)\);',pre,re.S):
        desc_c+='static const char '+variable+'[]= _('+body+');\n'
    desc_c+='int main(void){const unsigned char *p;\n'
    for entry in re.finditer(r'\[MOVE_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[MOVE_|\Z)',pre,re.S):
        name=aliases.get(entry[1],entry[1])
        if name=='NONE':continue
        found=re.search(r'\.description\s*=\s*(COMPOUND_STRING\(.*?\)|\w+)\s*,',entry[2],re.S)
        assert found,name
        desc_c+='printf("'+name+' ");p=(const unsigned char *)('+found[1]+');while(*p)printf("%02x",*p++);puts("");\n'
    desc_c+='return 0;}\n'
    with tempfile.TemporaryDirectory() as temp:
        root=Path(temp);(root/'desc.c').write_text(desc_c)
        subprocess.run(['gcc','-std=c99',str(root/'desc.c'),'-o',str(root/'desc')],check=True)
        desc_rows=subprocess.check_output([str(root/'desc')],text=True)
    for line in desc_rows.splitlines():
        name,raw=line.split(' ',1);expected=bytes.fromhex(raw).decode().replace('{POKEBLOCK}','POKéBLOCK').replace('{PKMN}','POKéMON')
        assert world['pokedex']['moveInfo'][name]['description']==expected,name
        if name in native:assert rules['moves'][name]['description']==expected,name
    counts['source_move_descriptions']=len(desc_rows.splitlines())
    for row in results.splitlines():
        parts=row.split()
        if parts[0]=='DISPLAY':
            name=parts[1];values=list(map(int,parts[2:]));expected=world['pokedex']['moveInfo'][name]
            assert [expected['power'],expected['accuracy']]==values[:2],name
            assert expected['type']==type_names[values[2]],(name,values[2],expected['type'])
            assert expected['category']==('physical','special','status')[values[3]],name
            counts['source_display_move_rows']=counts.get('source_display_move_rows',0)+1
        elif parts[0]=='MOVE':
            name=parts[1];values=list(map(int,parts[2:]));expected=rules['moves'][name]
            for key,value in zip(('power','accuracy','pp','priority'),values):assert expected[key]==value,(name,key,value)
            assert expected['type']==values[4]-1,name
            assert expected['category']==('physical','special','status')[values[5]],name
            counts['source_move_rows']+=1
        elif parts[0]=='CONTEST':
            _,name,e,category=parts;expected={**effects[int(e)],'category':('COOL','BEAUTY','CUTE','SMART','TOUGH')[int(category)]}
            assert world['pokedex']['contestMoves'][name]==expected,name
            counts['source_contest_move_rows']+=1
        else:
            _,a,d,value=parts;assert rules['chart'][a][d]==int(value),(a,d,value)
            counts['source_matchups']+=1
    odds=re.search(r'sGen7CriticalHitOdds\[\]\s*=\s*\{([^}]+)\}',(source/'src/battle_util.c').read_text())[1]
    assert rules['criticalOdds']=={str(i):int(n)for i,n in enumerate(re.findall(r'\d+',odds))}
    for name,value in rules['fixedConfig'].items():assert re.search(r'#define '+name+r'\s+'+value+r'\b',(source/'include/config/battle.h').read_text())
    assert len(rules['species'])==18
    expected_active={'ITEM_MODE_MODERN_MOVES','ITEM_MODE_SPLIT','ITEM_MODE_FAIRY_TYPES','ITEM_MODE_STURDY','ITEM_MODE_NEW_CITRUS','ITEM_MODE_SURVIVE_POISON','ITEM_DIFFICULTY_EXP_MULTIPLIER','ITEM_DIFFICULTY_NO_EVS','ITEM_DIFFICULTY_ITEM_PLAYER','ITEM_DIFFICULTY_ITEM_TRAINER','ITEM_MAIN_FOLLOWER','ITEM_MAIN_LARGE_FOLLOWER','ITEM_FEATURES_RTC_TYPE','ITEM_BATTLE_FAST_INTRO','ITEM_BATTLE_FAST_BATTLES','ITEM_BATTLE_NEW_BACKGROUNDS','ITEM_BATTLE_NEW_BATTLEUI','ITEM_BATTLE_BALL_PROMPT','ITEM_BATTLE_RUN_TYPE','ITEM_BATTLE_LR_RUN','ITEM_MODE_GEN_ONE_RECHARGE','ITEM_DIFFICULTY_LESS_ESCAPES','ITEM_DIFFICULTY_ESCAPE_ROPE_DIG'}
    assert set(rules['implemented'])==expected_active
    for page in world['startup']['settings']['pages']:
        for row in page['rows']:
            if row['id'] in rules['implemented']:assert row['implemented']
    source_lab=(source/'data/maps/NewBarkTown_Lab_hns/scripts.inc').read_text()
    police=re.search(r'NewBarkTown_Lab_EventScript_PoliceYes::\n(.*?)(?=^\w+::)',source_lab,re.M|re.S)[1]
    assert 'MUS_LEVEL_UP' in police
    for key in ('HNS_QUEST_ELM_RETURN','HNS_SCENE_POLICE_NAME'):
        cues=world['audio']['cues'][key]
        cue=next(a for a in cues if any(r.get('songName')=='MUS_HG_LEVEL_UP' for r in a.get('rows',[])))
        assert world['scripts'][key][cue['before']-1]['ptr'].endswith('NewBarkTown_Lab_Text_ElmAfterTheft2'),key
        assert any(a.get('after')==cue['before'] and a['rows']==[{'op':'waitfanfare'}] for a in cues),key
    assert rules['momFarewellFlag']==0x602D
    script=world['scripts']['HNS_RULES_MOM']
    assert {'op':'setflag','flag':0x602D}in script
    assert {'op':'playbgm','songName':'MUS_HG_FOLLOW_ME_1'}in script
    counts.update(source_critical_stages=5,source_fairy_species=18,implemented_settings=len(expected_active),egg_handoff_paths=2)
    return {'result':'pass','counts':counts}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','engine','mod','luajit'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--report',type=Path)
    a=p.parse_args();result=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
