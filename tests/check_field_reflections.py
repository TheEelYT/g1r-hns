"""Compare every RGB555 input against the actual pinned HnS C filters."""
import re,subprocess,tempfile
from pathlib import Path

def check(source,engine,mod,luajit,world):
    helper=(source/'src/field_effect_helpers.c').read_text()
    functions='\n'.join(re.search(r'static void '+n+r'\([^;]*?\)\n\{.*?\n\}',helper,re.S)[0]for n in ('ApplyPondFilter','ApplyIceFilter'))
    assert 'CpuFill16(0x55C9, blueData,'in helper
    code='''#include <stdint.h>
#include <stdio.h>
typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32; typedef int32_t s32;
u16 gPlttBufferUnfaded[16];
#define OBJ_PLTT_ID(n) 0
#define RGB2(r,g,b) ((r)|((g)<<5)|((b)<<10))
'''+functions+'''
int main(void){u16 out[16]; for(int mode=0;mode<3;mode++)for(int c=0;c<32768;c++){
for(int i=0;i<16;i++)gPlttBufferUnfaded[i]=c;
if(mode==0)ApplyPondFilter(0,out);else if(mode==1)ApplyIceFilter(0,out);else out[1]=0x55C9;
if(mode<2 && out[0]!=c)return 1;
putchar(out[1]&255);putchar(out[1]>>8);
}return 0;}
'''
    script="""package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');require('src.core.GameVersion').set('emerald');require('src.import.gba.versions').select('emerald')
local w=dofile(arg[1]..'/world.lua');local game={}
assert(loadfile(arg[1]..'/field_reflections.lua'))()({},w,game)
local S=game._hnsReflections.state
for _,kind in ipairs({'pond','ice','bridge'})do for color=0,32767 do local c=S.filter(color,kind);io.write(string.char(c%256,math.floor(c/256)))end end
"""
    with tempfile.TemporaryDirectory()as tmp:
        root=Path(tmp);(root/'oracle.c').write_text(code);(root/'actual.lua').write_text(script)
        subprocess.run(['gcc','-std=c99','-O2',str(root/'oracle.c'),'-o',str(root/'oracle')],check=True)
        expected=subprocess.check_output([str(root/'oracle')])
        actual=subprocess.check_output([str(luajit),str(root/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'Runtime reflection colors differ from source C'
    return {'source_c_reflection_color_cases':32768*3}
