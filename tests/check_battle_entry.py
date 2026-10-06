"""Compare Modern entry register traces with the actual source C tasks."""
import re
import struct
import subprocess
import tempfile
from pathlib import Path


def function(code, name):
    start = re.search(r'(?:static )?void ' + name + r'\(u8 taskId\)\s*\{', code).start()
    opening = code.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (code[end] == '{') - (code[end] == '}')
        end += 1
    return code[start:end]


def check_entry(source, mod, luajit):
    code = (source / 'src/battle_intro.c').read_text()
    functions = '\n'.join(function(code, name) for name in ('BattleIntroSlide1', 'BattleIntroSlide2', 'BattleIntroSlide3'))
    trig = (source / 'src/trig.c').read_text()
    table = re.search(r'gSineDegreeTable\[\]\s*=\s*\{(.*?)\};', trig, re.S)[1]
    pre = r'''
#include <stdint.h>
#include <stdio.h>
typedef uint8_t u8;typedef uint16_t u16;
#define Q_4_12(x) ((int16_t)((x)*4096))
#define DISPLAY_WIDTH 240
#define DISPLAY_HEIGHT 160
#define B_FAST_INTRO_NO_SLIDE 0
#define FALSE 0
#define BATTLE_TYPE_LINK 1
#define BATTLE_TYPE_RECORDED_LINK 2
enum { BATTLE_ENVIRONMENT_GRASS, BATTLE_ENVIRONMENT_LONG_GRASS, BATTLE_ENVIRONMENT_SAND, BATTLE_ENVIRONMENT_WATER, BATTLE_ENVIRONMENT_UNDERWATER, BATTLE_ENVIRONMENT_KYOGRE, BATTLE_ENVIRONMENT_BUILDING };
enum {REG_OFFSET_WININ, REG_OFFSET_BLDCNT, REG_OFFSET_BLDALPHA, REG_OFFSET_BLDY, REG_OFFSET_BG1CNT, REG_OFFSET_BG2CNT};
#define WININ_WIN0_BG_ALL 0
#define WININ_WIN0_OBJ 0
#define WININ_WIN0_CLR 0
#define BLDCNT_TGT1_BG1 0
#define BLDCNT_EFFECT_BLEND 0
#define BLDCNT_TGT2_BG3 0
#define BLDCNT_TGT2_OBJ 0
#define BLDALPHA_BLEND(a,b) ((a)|((b)<<8))
#define BGCNT_PRIORITY(x) 0
#define BGCNT_CHARBASE(x) 0
#define BGCNT_SCREENBASE(x) 0
#define BGCNT_16COLOR 0
#define BGCNT_TXT256x512 0
#define BGCNT_TXT512x256 0
#define BG_SCREEN_ADDR(x) 0
#define BG_SCREEN_SIZE 0
#define BG_ATTR_CHARBASEINDEX 0
#define tState data[0]
#define tEnvironment data[1]
struct {int16_t data[16];} gTasks[1];
struct {int fastIntro;} settings={1};struct {struct {int fastIntro;} challengeSettings;} save={ {1} };
#define gSaveBlock3Ptr (&save)
int gTestRunnerHeadless=0,gBattleTypeFlags=0,gIntroSlideFlags=1;
u16 gBattle_BG1_X,gBattle_BG1_Y,gBattle_BG2_X,gBattle_BG2_Y,gBattle_WIN0V;
struct {int state,srcBuffer;} gScanlineEffect;
u16 gScanlineEffectRegBuffers[2][160];
int alpha,visible;
void SetGpuReg(int reg,int value){if(reg==REG_OFFSET_BLDALPHA)alpha=value;}
void SetBgAttribute(int a,int b,int c){}
void CpuFill32(int a,void *b,int c){visible=0;}
void BattleIntroSlideEnd(u8 taskId){gBattle_BG1_X=gBattle_BG1_Y=0;visible=0;}
void BattleIntroNoSlide(u8 taskId){}
'''
    trig_code = 'static const int16_t sine[]={' + table + '};\nint Cos2(unsigned angle){angle+=90;int v=sine[angle%180];return (angle/180)%2?-v:v;}\n'
    main = r'''
int main(void){
  for(int env=0;env<7;env++){
    for(int i=0;i<16;i++)gTasks[0].data[i]=0;
    gTasks[0].tEnvironment=env;
    gBattle_BG1_X=gBattle_BG1_Y=0;gBattle_WIN0V=0x5051;alpha=16;visible=1;
    for(int i=0;i<80;i++)gScanlineEffectRegBuffers[0][i]=240;
    for(int i=80;i<160;i++)gScanlineEffectRegBuffers[0][i]=(u16)-240;
    for(int frame=1;frame<=154;frame++){
      if(env<2)BattleIntroSlide1(0);else if(env<6)BattleIntroSlide2(0);else BattleIntroSlide3(0);
      int16_t v[]={gBattle_BG1_X,(int16_t)gBattle_BG1_Y,gScanlineEffectRegBuffers[0][0],gBattle_WIN0V>>8,gBattle_WIN0V&255,alpha&31,visible};
      fwrite(v,sizeof(v),1,stdout);
    }
  }
}
'''
    script = r'''
local w=dofile(arg[1]..'/world.lua')
local f=assert(loadfile(arg[1]..'/terrain_entry.lua'))()(w.bootPresentation.credits.sineDegrees)
for n,env in ipairs({'GRASS','LONG_GRASS','SAND','WATER','UNDERWATER','KYOGRE','BUILDING'})do
  for frame=1,154 do
    local s=f(frame,n<3 and 1 or n<7 and 2 or 3,env)
    for _,v in ipairs({s.x,s.y,s.scan,s.top,s.bottom,s.alpha,s.visible and 1 or 0})do
      v=v%65536;io.write(string.char(v%256,math.floor(v/256)))
    end
  end
end
'''
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / 'entry.c').write_text(pre + trig_code + functions + main)
        subprocess.run(['gcc', '-std=c99', '-O2', str(root / 'entry.c'), '-o', str(root / 'oracle')], check=True)
        expected = subprocess.check_output([str(root / 'oracle')])
        (root / 'actual.lua').write_text(script)
        actual = subprocess.check_output([str(luajit), str(root / 'actual.lua'), str(mod)])
    rows = 7 * 154
    for i in range(rows):
        a = struct.unpack_from('<7h', actual, i * 14)
        e = struct.unpack_from('<7h', expected, i * 14)
        # Blend registers after the entry map is cleared do not affect pixels.
        assert a[:5] + a[6:] == e[:5] + e[6:], (i // 154, i % 154 + 1, a, e)
        if e[6]:
            assert a[5] == min(16, e[5]), (i, a, e)
    return rows
