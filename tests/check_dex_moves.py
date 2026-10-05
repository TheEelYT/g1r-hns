"""Compare Dex lists with isolated upstream helper output and a C oracle."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


def check(source, engine, mod, luajit):
    dex=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')]))['pokedex']
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'src/data/pokemon').mkdir(parents=True);(root/'data').mkdir()
        (root/'include').symlink_to(source/'include',target_is_directory=True)
        for folder in ('maps','scripts'):(root/'data'/folder).symlink_to(source/'data'/folder,target_is_directory=True)
        (root/'src/data/pokemon/species_info').symlink_to(source/'src/data/pokemon/species_info',target_is_directory=True)
        for name in ('all_learnables.json','special_movesets.json','species_info.h'):shutil.copy2(source/'src/data/pokemon'/name,root/'src/data/pokemon'/name)
        shutil.copytree(source/'tools/learnset_helpers',root/'tools/learnset_helpers',ignore=shutil.ignore_patterns('__pycache__'))
        generated=root/'generated';generated.mkdir()
        for script,args in [('make_teaching_types.py',[str(generated/'all_teaching_types.json')]),('make_tutors.py',[str(generated/'all_tutors.json')]),('make_teachables.py',['--build','POKEMON_HNS',str(generated)])]:
            subprocess.run(['python3',str(root/'tools/learnset_helpers'/script),*args],cwd=root,check=True)
        prefix='#include <stdio.h>\ntypedef unsigned short u16;typedef unsigned char u8;\n#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "config/general.h"\n#include "config/pokemon.h"\n#include "config/species_enabled.h"\n#include "constants/moves.h"\n#define LEVEL_UP_MOVE_END 65535\nstruct LevelUpMove {u16 move;u8 level;};\n'
        move_ids={}
        source_names={'VICE_GRIP':'VISE_GRIP','HI_JUMP_KICK':'HIGH_JUMP_KICK','FAINT_ATTACK':'FEINT_ATTACK','SMELLING_SALT':'SMELLING_SALTS'}
        c=prefix+'int main(void){\n'+''.join('printf("'+name+' %u\\n",MOVE_'+source_names.get(name,name)+');\n'for name in dex['moveInfo'])+'}\n'
        def run(c):
            (root/'oracle.c').write_text(c)
            subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),'-I'+str(source/'src'),str(root/'oracle.c'),'-o',str(root/'oracle')],check=True)
            return subprocess.check_output([str(root/'oracle')],text=True)
        move_ids={name:int(value)for name,value in (line.split()for line in run(c).splitlines())}
        totals={'teachable_rows':0,'egg_rows':0,'level_rows':0,'learnset_arrays':0}
        groups=[('teachable',dex['teachables'],str(root/'src/data/pokemon/teachable_learnsets.h'))]
        for gen,arrays in dex['eggsets'].items():groups.append(('egg',arrays,'data/pokemon/egg_moves'+('_gen3'if gen=='3'else '')+'.h'))
        for gen,arrays in dex['learnsets'].items():groups.append(('level',arrays,'data/pokemon/level_up_learnsets/gen_'+gen+'.h'))
        for kind,arrays,header in groups:
            c=prefix+'#include "'+header+'"\nint main(void){\n'
            for name in arrays:
                field='[i].move'if kind=='level'else '[i]'
                end='LEVEL_UP_MOVE_END'if kind=='level'else 'MOVE_UNAVAILABLE'
                extra=', '+name+'[i].level'if kind=='level'else ''
                c+='for(unsigned i=0;'+name+field+'!='+end+';i++)printf("'+name+' %u'+(' %u'if kind=='level'else '')+'\\n",'+name+field+extra+');\n'
            actual={name:[]for name in arrays}
            for line in run(c+'}\n').splitlines():
                values=line.split();actual[values[0]].append(list(map(int,values[1:])))
            for name,rows in arrays.items():
                expected=[[move_ids[row['move']],row['level']]if kind=='level'else[move_ids[row]]for row in rows]
                assert actual[name]==expected,(kind,name)
                totals[kind+'_rows']+=len(rows);totals['learnset_arrays']+=1
        r=next(r for r in dex['registrationEntries']if r['speciesName']=='TOTODILE');gen=str(dex['modernGeneration'])
        counts=[len(dex['eggsets'][gen][r['eggRef']]),len(dex['learnsets'][gen][r['learnsetRef']]),len(dex['teachables'][r['teachableRef']])]
        assert counts==[14,17,56],counts
        totals['totodile_modern_moves']=sum(counts)
        return {'result':'pass','counts':totals}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','engine','mod','luajit'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--report',type=Path);a=p.parse_args()
    result=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
