"""Source ability identities with stable IDs and explicit effect coverage."""
import re,subprocess,tempfile
from pathlib import Path
from move_table import fields

SURGES={'ELECTRIC_SURGE':'ELECTRIC','GRASSY_SURGE':'GRASSY','MISTY_SURGE':'MISTY','PSYCHIC_SURGE':'PSYCHIC'}


def build(source,engine,dex):
    body=(engine/'src/core/game3/battle/adapter.lua').read_text().split('local ABILITY_BY_ID = {',1)[1].split('\n}',1)[0]
    native={n:int(i)for i,n in re.findall(r'\[(\d+)\]\s*=\s*"(\w+)"',body)};native['NONE']=0
    rows=dex['abilities']
    pre=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "data/abilities.h"\n',text=True)
    source_fields={n:fields(b)for n,b in re.findall(r'\[ABILITY_(\w+)\]\s*=\s*\{(.*?)\n\s*\},',pre,re.S)}
    code='#include <stdio.h>\n#include "constants/abilities.h"\nint main(void){'+''.join('printf("'+n+' %d\\n",ABILITY_'+n+');'for n in rows)+'}'
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'ids.c').write_text(code)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(root/'ids.c'),'-o',str(root/'ids')],check=True)
        ids={n:int(i)for n,i in(line.split()for line in subprocess.check_output([str(root/'ids')],text=True).splitlines())}
    records={}
    for name,row in rows.items():
        records[name]={**row,'sourceId':ids[name],'id':native.get(name,1000+ids[name]),'sourceFields':source_fields[name],
                       'support':'native'if name in native else'reviewed'if name in SURGES else'pending'}
    assert len({r['id']for r in records.values()})==len(records)
    species={}
    for row in dex['registrationEntries']:
        names=row['abilityNames'];assert len(names)==3 and all(n in records for n in names)
        species[row['speciesName']]={'slots':names}
    pokemon=(source/'src/pokemon.c').read_text()
    legendary=dict(re.findall(r'\{ SPECIES_(\w+),\s*ABILITY_(\w+)',pokemon.split('sLegendaryCustomAbilities[] = {')[1].split('};',1)[0]))
    assert len(legendary)==9
    config=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-'],input='#include "config/general.h"\n#include "config/overworld.h"\nOW_SYNCHRONIZE_NATURE\n',text=True)
    synchronize_generation=int(config.strip().splitlines()[-1])+1  # source GEN_1..GEN_9 are zero-based
    return {'fieldLead':{'synchronizeGeneration':synchronize_generation},'records':records,'species':species,'legendary':legendary,'normalSlots':2,'hiddenSlots':1,'surges':SURGES,'counts':{k:sum(r['support']==k for r in records.values())for k in ('native','reviewed','pending')},
            'limits':'Complete source ability identities/descriptions/fields, native bridges and four reviewed Surge entry effects. Normal/hidden source slot identities and legendary setting are connected; hidden acquisition, randomizer and remaining expanded effects, suppression/transfer differences and source ability popups remain pending.'}
