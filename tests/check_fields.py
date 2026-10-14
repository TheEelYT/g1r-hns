"""Independent source font pixels and compiled field-power arithmetic."""
import re,subprocess,tempfile
from pathlib import Path
from PIL import Image


def check(source,engine,mod,luajit,world):
    f=world['bootPresentation']['title']['captionFont'];im=Image.open(source/'graphics/title_screen/hns/press_start.png');samples=0
    for char,(x,y,w,h)in f['sourceGlyphs'].items():
        g=f['glyphs'][char]
        for n in range(1,6):
            a=f['layers'][str(n)];raw=(mod/a['file']).read_bytes()
            for py in range(h):
                for px in range(w):
                    offset=(py*a['width']+g['x']+px)*4
                    assert raw[offset:offset+4]==bytes((255,255,255,255 if im.getpixel((x+px,y+py))==n else 0))
                    samples+=1
    util=(source/'src/battle_util.c').read_text()
    assert re.search(r'gFieldTimers\.terrainTimer = 8;\s*else\s*gFieldTimers\.terrainTimer = 5;',util)
    fields=world['battleFields'];assert fields['terrainTurns']==5 and fields['extendedTurns']==8
    expr=re.search(r'if \(IsGrassyTerrainAffected\(battlerAtk, ctx->abilityAtk, ctx->holdEffectAtk, ctx->fieldStatuses\) && moveType == TYPE_GRASS\)\s*modifier = uq4_12_multiply\(modifier,\s*(.*?)\);',util,re.S)[1]
    prefix='#include <stdio.h>\ntypedef unsigned int u32;typedef int s32;typedef unsigned short u16;typedef short s16;\n#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "fpmath.h"\n'
    code=prefix+'int main(void){u32 factors[]={UQ_4_12(0.5),UQ_4_12(1.0),'+expr+'};for(int i=0;i<3;i++)for(int p=1;p<=512;p++)printf("%u\\n",uq4_12_multiply_by_int_half_down(factors[i],p));}\n'
    script="package.path='./?.lua;./?/init.lua;'..package.path;love=require('tests.love_stub');require('src.core.GameVersion').set('emerald');local w=dofile(arg[1]..'/world.lua');local game={_hnsRules={rules={battle=function()return true end}}};assert(loadfile(arg[1]..'/battle_fields.lua'))()({},w,game);local F=game._hnsFields.fields;local ad={_st={hnsTerrain='MISTY'},abilityOf=function()end,hasType=function()return false end};local u,d={},{};for _,row in ipairs({{'MISTY',16},{'NONE',0},{'ELECTRIC',13}})do ad._st.hnsTerrain=row[1];for p=1,512 do io.write(F.power(ad,u,d,{},p,row[2]),'\\n')end end"
    with tempfile.TemporaryDirectory()as temp:
        tmp=Path(temp);(tmp/'oracle.c').write_text(code)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(tmp/'oracle.c'),'-o',str(tmp/'oracle')],check=True)
        expected=subprocess.check_output([str(tmp/'oracle')])
        (tmp/'actual.lua').write_text(script)
        actual=subprocess.check_output([str(luajit),str(tmp/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'installed field-power rounding differs from source fpmath.h'
    return {'source_title_glyph_mask_pixels':samples,'source_c_terrain_power_cases':1536,'source_core_terrain_moves':4,'source_duration_items':len(fields['items'])}
