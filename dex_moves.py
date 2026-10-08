"""Source-only Dex learnable lists; this does not register battle effects."""
import json
import os
import re
import runpy
import subprocess

ALIASES = {'VISE_GRIP':'VICE_GRIP', 'HIGH_JUMP_KICK':'HI_JUMP_KICK',
           'FEINT_ATTACK':'FAINT_ATTACK', 'SMELLING_SALTS':'SMELLING_SALT'}


def aliases(source):
    result=dict(ALIASES)
    for name,target in re.findall(r'MOVE_(\w+)\s*=\s*MOVE_(\w+)',(source/'include/constants/moves.h').read_text()):
        result[name]=result.get(target,target)
    return result


def build(source, preprocess, modern_generation):
    source=source.resolve()
    move_aliases=aliases(source)
    # Run only the pinned helpers' read/generate functions. Their main/tutor
    # writers are deliberately not invoked, so the source checkout stays clean.
    previous=os.getcwd()
    try:
        os.chdir(source)
        helpers=source/'tools/learnset_helpers'
        teach=runpy.run_path(str(helpers/'make_teachables.py'))
        types=runpy.run_path(str(helpers/'make_teaching_types.py'))
        tutors=runpy.run_path(str(helpers/'make_tutors.py'))
        special=json.loads((source/'src/data/pokemon/special_movesets.json').read_text())
        machines=list(teach['extract_repo_tms']('POKEMON_HNS'))
        tutor_moves=sorted(set(tutors['extract_repo_tutors']())|set(special['extraTutors']))
        settings=(source/'include/config/pokedex_plus_hgss.h').read_text()
        ordered=machines if re.search(r'#define HGSS_SORT_TMS_BY_NUM\s+(?:TRUE|1)\b',settings)else sorted(machines)
        generated=teach['prepare_output'](json.loads((source/'src/data/pokemon/all_learnables.json').read_text()),ordered,tutor_moves,special,types['extract_repo_species_data'](),'')
    finally:
        os.chdir(previous)
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "config/general.h"\n#include "config/pokemon.h"\n#include "config/species_enabled.h"\n'
    pp=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+generated,text=True)
    def arrays(body):
        return {name:[move_aliases.get(move,move)for move in re.findall(r'MOVE_(\w+)',rows)if move!='UNAVAILABLE']for name,rows in re.findall(r'static const u16 (\w+)\[\]\s*=\s*\{(.*?)\};',body,re.S)}
    teachables=arrays(pp)
    eggs={str(modern_generation):arrays(preprocess('data/pokemon/egg_moves.h')),'3':arrays(preprocess('data/pokemon/egg_moves_gen3.h'))}
    legacy={}
    for key,path in [('level','level_up_learnsets_gen3.c'),('egg','egg_moves_gen3.c')]:
        body=(source/'src/data/pokemon'/path).read_text()
        body=re.sub(r'^#include.*$', '',body,flags=re.M)
        body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+body,text=True)
        legacy[key]={name:ref for name,ref in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*(\w+)',body)}
    labels={}
    for kind,macro in [('TM','FOREACH_TM'),('HM','FOREACH_HM')]:
        text=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-'],input=prefix+'#include "constants/global.h"\n#include "constants/tms_hms.h"\n#define SHOW_MOVE(x) MACHINE_##x\n'+macro+'(SHOW_MOVE)\n',text=True)
        for i,move in enumerate(re.findall(r'MACHINE_(\w+)',text),1):
            labels[move_aliases.get(move,move)]=kind+str(i).zfill(2)
    return teachables,eggs,legacy,labels


def move_info(body):
    from gameplay import TYPE_NAMES
    def value(expression):
        expression=expression.strip()
        if '?' in expression:
            m=re.fullmatch(r'\(*\s*(\d+)\s*>=\s*(\d+)\s*\)*\s*\?\s*([\w-]+)\s*:\s*([\w-]+)',expression)
            assert m,expression
            expression=m[3]if int(m[1])>=int(m[2])else m[4]
        return expression.strip('() ')
    def string(expression):
        return ''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',expression))
    result={}
    for name,row in re.findall(r'\[MOVE_(\w+)\]\s*=\s*(.*?)(?=\n    \[MOVE_|\Z)',body,re.S):
        if name=='NONE':continue
        fields={key:re.search(r'\.'+key+r'\s*=\s*([^,]+),',row)[1]for key in ('power','accuracy','type','category')}
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',row,re.S)
        if not desc:
            ref=re.search(r'\.description\s*=\s*(\w+),',row)[1]
            desc=re.search(r'\b'+ref+r'(?:\[\])?\s*=\s*(?:COMPOUND_STRING|_)\((.*?)\);',body,re.S)
        assert desc,name
        title=re.search(r'\.name\s*=\s*(?:COMPOUND_STRING|_)\((.*?)\),',row,re.S)
        assert title,name
        result[ALIASES.get(name,name)]={'name':string(title[1]),'description':string(desc[1]).replace('{POKEBLOCK}','POKéBLOCK').replace('{PKMN}','POKéMON'),
            'power':int(value(fields['power'])),'accuracy':int(value(fields['accuracy'])),
            'type':value(fields['type']).removeprefix('TYPE_'),'category':value(fields['category']).removeprefix('DAMAGE_CATEGORY_').lower()}
    return result
