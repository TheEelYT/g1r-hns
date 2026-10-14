"""Compile the actual HnS ability-slot fallback and legendary function."""
import re,subprocess,tempfile
from pathlib import Path

def check(source,world):
    a=world['abilities'];records=a['records'];species=a['species'];aliases={'CASTFORM':'CASTFORM_NORMAL','DEOXYS':'DEOXYS_NORMAL'}
    pre=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/pokemon.h"\n#include "constants/global.h"\n#include "data/pokemon/species_info.h"\n',text=True)
    slots={}
    for n in species:
        b=re.search(r'\[SPECIES_'+aliases.get(n,n)+r'\]\s*=\s*\{(.*?)(?=\n\s*\[SPECIES_|\n\s*};|\Z)',pre,re.S)[1]
        expr=re.search(r'\.abilities\s*=\s*\{([^}]+)',b)[1];slots[n]=expr
        assert species[n]['slots']==re.findall(r'ABILITY_(\w+)',expr),n
    src=(source/'src/pokemon.c').read_text()
    legend=src[src.index('static const struct {\n    u16 species;\n    u16 customAbility;'):src.index('enum Ability GetAbilityBySpecies')]
    fn=re.search(r'enum Ability GetAbilityBySpecies\([^;]*?\)\n\{.*?\n\}',src,re.S)[0]
    code='#include <stdio.h>\n#include <stdint.h>\n#include "constants/abilities.h"\n#include "constants/species.h"\ntypedef uint16_t u16;typedef uint8_t u8;\n#define NUM_ABILITY_SLOTS 3\n#define NUM_NORMAL_ABILITY_SLOTS 2\n#define RANDOMIZER_AVAILABLE 0\n#define TRUE 1\n#define ARRAY_COUNT(x) (sizeof(x)/sizeof((x)[0]))\nstruct Save{struct{int tx_Mode_Legendary_Abilities;}challengeSettings;}save;static struct Save*gSaveBlock3Ptr=&save;static enum Ability gLastUsedAbility;\n'
    code+='static enum Ability table[NUM_SPECIES][3]={'+','.join('[SPECIES_'+aliases.get(n,n)+']={'+e+'}'for n,e in slots.items())+'};\nstatic enum Ability GetSpeciesAbility(u16 s,u8 i){return table[s][i];}\n'+legend+fn
    code+='\nint main(void){int slots[]={0,1,2,3,255};for(int m=0;m<2;m++){save.challengeSettings.tx_Mode_Legendary_Abilities=m;'
    for n in species:code+='for(int i=0;i<5;i++)printf("'+n+' %d %d %d\\n",slots[i],m,GetAbilityBySpecies(SPECIES_'+aliases.get(n,n)+',slots[i]));'
    code+='}return 0;}'
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'source.c').write_text(code)
        subprocess.run(['gcc','-std=gnu99','-O2','-Werror','-I'+str(source/'include'),str(root/'source.c'),'-o',str(root/'source')],check=True,capture_output=True)
        output=subprocess.check_output([str(root/'source')],text=True)
    ids={r['sourceId']:n for n,r in records.items()}
    for line in output.splitlines():
        n,slot,mode,id=line.split();slot,mode=int(slot),int(mode);names=species[n]['slots']
        key=a['legendary'].get(n)if mode and slot==0 else None
        if not key:key=names[slot]if slot<len(names)else'NONE'
        if key=='NONE'and slot>=2:key=next((k for k in names[2:]if k!='NONE'),'NONE')
        if key=='NONE':key=next((k for k in names if k!='NONE'),'NONE')
        assert key==ids[int(id)],(n,slot,mode,key,id)
    return {'source_ability_species':len(species),'source_c_ability_slot_cases':len(output.splitlines()),'source_legendary_ability_overrides':len(a['legendary'])}
