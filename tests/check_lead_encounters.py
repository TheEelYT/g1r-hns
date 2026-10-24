"""Source C lead-ability selectors and personality rejection, on common inputs."""
import re,subprocess,tempfile
from pathlib import Path

def check(source,engine,mod,lua,world):
    cfg=world['abilities']['fieldLead']['synchronizeGeneration'];assert cfg==9
    src=re.sub(r'^#include[^\n]*','',(source/'src/ow_abilities.c').read_text(),flags=re.M)
    pid=re.search(r'u32 GetMonPersonality\([^;]*?\)\n\{.*?\n\}',(source/'src/pokemon.c').read_text(),re.S)[0]
    prefix=r'''#include <stdint.h>
#include <stdio.h>
typedef uint32_t u32;typedef uint8_t u8;typedef uint16_t u16;typedef unsigned int bool32;
#define TRUE 1
#define FALSE 0
#define UNUSED
#include "config/general.h"
#define OW_SYNCHRONIZE_NATURE GEN_LATEST
#include "constants/pokemon.h"
#include "constants/abilities.h"
#include "ow_synchronize.h"
#define MON_DATA_SANITY_IS_EGG 1
#define MON_DATA_PERSONALITY 2
struct Mon{u32 personality,ability,gender,egg;};
static struct Mon gPlayerParty[1];
static struct{struct{int tx_Mode_Synchronize;}challengeSettings;}save,*gSaveBlock3Ptr=&save;
static struct{int genderRatio;int eggGroups[2];}gSpeciesInfo[2];
static int value,draws,stream;static u32 rng;
static u16 Random(void){draws++;if(!stream)return value;rng=rng*1103515245u+24691u;return rng>>16;}
static u32 Random32(void){u32 lo=Random();return lo|((u32)Random()<<16);}
static u32 GetMonData(const struct Mon*m,int field){return field==MON_DATA_PERSONALITY?m->personality:m->egg;}
static u32 GetMonAbility(const struct Mon*m){return m->ability;}
static u32 GetMonGender(const struct Mon*m){return m->gender;}
static u32 GetNatureFromPersonality(u32 p){return p%25;}
static u32 GetGenderFromSpeciesAndPersonality(u16 species,u32 p){int ratio=gSpeciesInfo[species].genderRatio;if(ratio==0)return MON_MALE;if(ratio==254)return MON_FEMALE;if(ratio==255)return MON_GENDERLESS;return ratio>(p&255)?MON_FEMALE:MON_MALE;}
#define GET_UNOWN_LETTER(p) 0
#define NUM_UNOWN_FORMS 28
#define RANDOM_UNOWN_LETTER 0
#define assertf(...) if(1){}else
'''
    selectors=r'''
int main(void){int ratios[]={0,31,127,254,255},genders[]={MON_MALE,MON_FEMALE,MON_GENDERLESS},abilities[]={ABILITY_NONE,ABILITY_SYNCHRONIZE,ABILITY_CUTE_CHARM},natures[]={0,12,24};
for(int o=0;o<4;o++)for(int mode=0;mode<2;mode++)for(int ab=0;ab<3;ab++)for(int egg=0;egg<2;egg++)for(int r=0;r<5;r++)for(int g=0;g<3;g++)for(int roll=0;roll<6;roll++)for(int n=0;n<3;n++){
gPlayerParty[0]=(struct Mon){natures[n],abilities[ab],genders[g],egg};gSpeciesInfo[1].genderRatio=ratios[r];save.challengeSettings.tx_Mode_Synchronize=mode;value=roll;draws=0;
u32 nature=GetSynchronizedNature(o,1),gender=GetSynchronizedGender(o,1);printf("%u %u %d\n",nature,gender,draws);
}return 0;}
'''
    personalities=r'''
int main(void){u32 seeds[]={0,1,4660,65535};int ratios[]={31,127,191},genders[]={MON_GENDER_RANDOM,MON_MALE,MON_FEMALE};stream=1;
for(int s=0;s<4;s++)for(int r=0;r<3;r++)for(int n=0;n<=25;n++)for(int g=0;g<3;g++){
rng=seeds[s];gSpeciesInfo[1].genderRatio=ratios[r];u32 p=GetMonPersonality(1,genders[g],n,0);printf("%u %u\n",p,rng);
}return 0;}
'''
    setup=r'''package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');require('src.core.GameVersion').set('emerald');require('src.import.gba.versions').select('emerald')
local P=require('src.core.game3.pokemon');local Rng=require('src.core.game3.rng');local w=dofile(arg[1]..'/world.lua')
local session={party={{species=999,personality=0,hnsAbilityOverride=true}}};local mode,ratio,leadGender=0,127,'M'
local names={[0]='NONE','SYNCHRONIZE','CUTE_CHARM'};local byId={};for id,name in pairs(names)do byId[id]={name=name}end
local game={_hnsRules={rules={value=function()return mode end}},_hnsAbilities={abilities={byId=byId}}}
P.isEgg=function(m)return m.isEgg end;P.speciesOf=function(m)return m.species end;P.speciesMeta=function()return{genderRatio=ratio}end
P.gender=function(sp,p)if sp==999 then return leadGender end;if ratio==0 then return'M'elseif ratio==254 then return'F'elseif ratio==255 then return'U'end;return ratio>p%256 and'F'or'M'end
assert(loadfile(arg[1]..'/lead_encounters.lua'))()({},w,game);local S=game._hnsLeadEncounters.encounters
'''
    selector_lua=r'''
local draws,roll=0,0;Rng.Random=function()draws=draws+1;return roll end
for _,origin in ipairs({'wild','static','roamer','gift'})do for m=0,1 do mode=m;for ab=0,2 do for egg=0,1 do
for _,r in ipairs({0,31,127,254,255})do ratio=r;for _,g in ipairs({'M','F','U'})do leadGender=g;for v=0,5 do roll=v;for _,n in ipairs({0,12,24})do
local mon=session.party[1];mon.ability=ab;mon.isEgg=egg==1;mon.personality=n;draws=0
local nature=S.nature(origin,session);local gender=S.gender(origin,1,session)
io.write(nature or 25,' ',({M=0,F=254,U=255})[gender]or 1,' ',draws,'\n')
end end end end end end end end
'''
    pid_lua=r'''
for _,seed in ipairs({0,1,4660,65535})do for _,r in ipairs({31,127,191})do ratio=r;for n=0,25 do for _,g in ipairs({'U','M','F'})do
Rng.SeedRng(seed);local p=S.personality(1,n~=25 and n or nil,g~='U'and g or nil);io.write(string.format('%.0f %.0f\n',p,Rng.getState().value))
end end end end
'''
    # Exact source importance branch, with source item rows supplied as inputs.
    importance=re.search(r'u8 GetItemImportance\([^;]*?\)\n\{.*?\n\}',(source/'src/item.c').read_text(),re.S)[0]
    assert 'tx_Mode_InfiniteTMs == 1'in importance and 'POCKET_TM_HM'in importance
    native=(engine/'src/core/game3/item_use.lua').read_text();generated=(mod/'hns_use_tm.lua').read_text()
    assert 'if learned and not isHm and not consumed and not HNS.reusable(session,id) then'in generated
    # Check complete native useTm body remains intact apart from the predicate.
    nativefn=re.search(r'function ItemUse.useTm\([^\n]*\).*?\nend',native,re.S)[0]
    expected=nativefn.replace('function ItemUse.useTm','local function useTm',1).replace('if learned and not isHm and not consumed then','if learned and not isHm and not consumed and not HNS.reusable(session,id) then')
    assert expected in generated
    with tempfile.TemporaryDirectory()as temporary:
        root=Path(temporary)
        for name,program,script in [('selectors',prefix+src+selectors,setup+selector_lua),('pid',prefix+pid+personalities,setup+pid_lua)]:
            (root/(name+'.c')).write_text(program);(root/(name+'.lua')).write_text(script)
            subprocess.run(['gcc','-std=gnu99','-O2','-I'+str(source/'include'),str(root/(name+'.c')),'-o',str(root/name)],check=True,capture_output=True)
            expected=subprocess.check_output([str(root/name)])
            actual=subprocess.check_output([str(lua),str(root/(name+'.lua')),str(mod)],cwd=engine)
            assert actual==expected,'Source lead encounter '+name+' differs on common inputs'
    return {'source_c_lead_ability_selector_cases':25920,'source_c_constrained_personality_cases':936,'native_tm_learning_body_preserved':True,'native_rng_preserved':True}
