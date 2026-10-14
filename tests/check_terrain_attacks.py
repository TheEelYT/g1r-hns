"""Source pixels and real source terrain-boost C arithmetic, independently."""
import re,struct,subprocess,tempfile
from pathlib import Path
from PIL import Image


def check(source,engine,mod,luajit,world):
    backgrounds=world['battleVisuals']['fieldBackgrounds']
    assert set(backgrounds)=={'ELECTRIC','GRASSY','MISTY','PSYCHIC'}
    assert world['battleFields']['backgroundChanges']is True
    assert world['battleFields']['newBackgrounds']is False
    for kind,row in backgrounds.items():
        root=source/'graphics/battle_anims/backgrounds';name=kind.lower()+'_terrain'
        assert row['sourceTiles']==str((root/(name+'.png')).relative_to(source))
        im=Image.open(root/(name+'.png'));tilemap=(root/(name+'.bin')).read_bytes();words=struct.unpack('<'+str(len(tilemap)//2)+'H',tilemap)
        pal=[tuple((int(v)>>3)*255//31+int(((int(v)>>3)*255)%31>=16)for v in line.split())for line in(root/(name+'.pal')).read_text().splitlines()[3:19]]
        raw=bytearray()
        for y in range(160):
            for x in range(256):
                word=words[y//8*32+x//8];tile=word&1023;px=7-x%8 if word&1024 else x%8;py=7-y%8 if word&2048 else y%8
                n=im.getpixel((tile%(im.width//8)*8+px,tile//(im.width//8)*8+py))
                raw.extend(pal[n]+(255,))
        assert (mod/row['full']['file']).read_bytes()==raw,kind
    util=(source/'src/battle_util.c').read_text()
    fn=util[util.index('static inline u32 CalcTerrainBoostedPower('):util.index('static inline u32 IsFieldMudSportAffected(')]
    percent=util[util.index('ARM_FUNC NOINLINE static uq4_12_t PercentToUQ4_12(u32 percent)\n{'):util.index('enum BattlerId GetBattlerForBattleScript(')]
    names=['EXPANDING_FORCE','MISTY_EXPLOSION','RISING_VOLTAGE','PSYBLADE'];rows=[]
    moves=(source/'src/data/moves_info.h').read_text()
    for name in names:
        row=re.search(r'\[MOVE_'+name+r'\]\s*=\s*\{(.*?)(?=\n    \[MOVE_|\Z)',moves,re.S)[1]
        arg=re.search(r'\.argument\.terrainBoost\s*=\s*\{([^}]+)',row)[1]
        terrain=re.search(r'\.terrain\s*=\s*(\w+)',arg)[1];pc=re.search(r'\.percent\s*=\s*(\d+)',arg)[1]
        ground=re.search(r'\.groundCheck\s*=\s*(\w+)',arg)[1]
        rows.append('{'+terrain+','+pc+','+ground+'}')
    prefix='#include <stdio.h>\ntypedef unsigned int u32;typedef int s32;typedef unsigned short u16;typedef short s16;typedef int bool32;\n#define TRUE 1\n#define FALSE 0\n#define ARM_FUNC\n#define NOINLINE\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/battle.h"\n#include "constants/pokemon.h"\n#include "constants/battle.h"\n#include "constants/moves.h"\n#include "fpmath.h"\nenum {GROUND_CHECK_NONE,GROUND_CHECK_USER,GROUND_CHECK_TARGET};\nstruct BattleContext{u32 move,battlerAtk,battlerDef,abilityAtk,abilityDef,holdEffectAtk,holdEffectDef,fieldStatuses;};\n'
    prefix+='struct Boost{u32 terrain,percent,ground;} rows[]={'+','.join(rows)+'};\nstatic u32 ground[2];\n'
    prefix+='u32 GetMoveTerrainBoost_GroundCheck(u32 m){return rows[m].ground;}u32 GetMoveTerrainBoost_Terrain(u32 m){return rows[m].terrain;}u32 GetMoveTerrainBoost_Percent(u32 m){return rows[m].percent;}\nbool32 IsBattlerTerrainAffected(u32 b,u32 a,u32 h,u32 f,u32 flag){return ground[b]&&(f&flag);}\n'
    main='int main(void){printf("%u %u %u %u\\n",FIRST_Z_MOVE,LAST_Z_MOVE,FIRST_MAX_MOVE,LAST_MAX_MOVE);u32 terrain[]={0,STATUS_FIELD_ELECTRIC_TERRAIN,STATUS_FIELD_GRASSY_TERRAIN,STATUS_FIELD_MISTY_TERRAIN,STATUS_FIELD_PSYCHIC_TERRAIN};u32 typ[]={14,18,13,14};struct BattleContext c={0};c.battlerDef=1;for(c.move=0;c.move<4;c.move++)for(int t=0;t<5;t++)for(ground[0]=0;ground[0]<2;ground[0]++)for(ground[1]=0;ground[1]<2;ground[1]++)for(u32 p=1;p<=512;p++){c.fieldStatuses=terrain[t];u32 power=CalcTerrainBoostedPower(&c,p);u32 modifier=UQ_4_12(1.0);if(ground[0]&&((t==1&&typ[c.move]==13)||(t==2&&typ[c.move]==12)||(t==4&&typ[c.move]==14)))modifier=B_TERRAIN_TYPE_BOOST>=GEN_8?UQ_4_12(1.3):UQ_4_12(1.5);if(t==3&&typ[c.move]==16&&ground[1])modifier=UQ_4_12(0.5);printf("%u\\n",uq4_12_multiply_by_int_half_down(modifier,power));}}'
    script="package.path='./?.lua;./?/init.lua;'..package.path;love=require('tests.love_stub');require('src.core.GameVersion').set('emerald');local w=dofile(arg[1]..'/world.lua');local g={_hnsRules={rules={battle=function()return true end}}};assert(loadfile(arg[1]..'/battle_fields.lua'))()({hooks={wrap=function()end}},w,g);local F=g._hnsFields.fields;local ad={_st={},abilityOf=function()end,hasType=function(_,b)return b.air end};local u,d={},{};for _,name in ipairs({'EXPANDING_FORCE','MISTY_EXPLOSION','RISING_VOLTAGE','PSYBLADE'})do local m=w.expandedMoves.moves[name];for _,t in ipairs({'NONE','ELECTRIC','GRASSY','MISTY','PSYCHIC'})do ad._st.hnsTerrain=t;for ug=0,1 do u.air=ug==0;for dg=0,1 do d.air=dg==0;for p=1,512 do io.write(F.power(ad,u,d,m,p,m.type),'\\n')end end end end end"
    with tempfile.TemporaryDirectory()as tmp:
        root=Path(tmp);(root/'oracle.c').write_text(prefix+percent+fn+main)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(root/'oracle.c'),'-o',str(root/'oracle')],check=True)
        bounds,expected=subprocess.check_output([str(root/'oracle')]).split(b'\n',1)
        z0,z1,m0,m1=map(int,bounds.split());special=0
        for name,row in world['moveTable']['moves'].items():
            if z0<=row['sourceId']<=z1 or m0<=row['sourceId']<=m1:
                assert row['support']=='pending'and name not in world['expandedMoves']['moves'],name
                special+=1
        (root/'actual.lua').write_text(script)
        actual=subprocess.check_output([str(luajit),str(root/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'installed terrain-dependent power differs from actual source C functions'
    return {'source_field_background_pixels':4*256*160,'source_c_terrain_attack_power_cases':40960,'reviewed_terrain_dependent_attacks':8,'source_special_move_rows_pending':special}
