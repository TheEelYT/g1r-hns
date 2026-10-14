"""Source C sprite cadence and follower jump traces, independent of Lua timing."""
import re,subprocess,tempfile
from pathlib import Path


def check(source,engine,mod,luajit,world):
    move=(source/'src/event_object_movement.c').read_text();sprite=(source/'src/sprite.c').read_text();anims=(source/'src/data/object_events/object_event_anims.h').read_text()
    spec=world['followers']['motion']
    def fn(code,name):return re.search(r'(?:static )?(?:void|u8|s16) '+name+r'\([^;]*?\)\n\{.*?\n\}',code,re.S)[0]
    arrays='\n'.join(re.search(r'static const union AnimCmd '+n+r'\[\]\s*=\s*\{.*?\n\};',anims,re.S)[0]for n in ('sAnim_GoSouth2F','sAnim_GoFastSouth2F'))
    positions=list(map(int,re.search(r'\.anims = sAnimTable_Following,\s*\.animPos = \{([^}]+)',anims)[1].split(',')))
    assert spec['animPositions']==positions
    assert spec['poseImages']==[0,1,1,0]and spec['walkPoseDuration']==6 and spec['runPoseDuration']==4
    prefix='''#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
typedef uint8_t u8;typedef uint16_t u16;typedef int16_t s16;typedef int8_t s8;
#define TRUE 1
#define FALSE 0
#define ST_OAM_AFFINE_ON_MASK 3
#define OW_GFX_COMPRESS 0
#define ARRAY_COUNT(x) (sizeof(x)/sizeof((x)[0]))
union AnimCmd {s16 type;struct{s16 imageValue;u8 duration,hFlip,vFlip;}frame;struct{s16 type;u8 target;}jump;};
#define ANIMCMD_FRAME(i,d) {.frame={i,d,0,0}}
#define ANIMCMD_JUMP(t) {.jump={-2,t}}
struct Sprite{const union AnimCmd*const*anims;int animCmdIndex,animDelayCounter,animPaused,animBeginning,animEnded,animNum,usingSheet,sheetSpan,sheetTileStart;struct{int affineMode,tileNum;}oam;void*images;s16 x,y,y2,data[8];};
struct ObjectEvent{int inanimate;};struct StepAnimTable{const union AnimCmd*const*anims;int animPos[4];};
static void ContinueAnim(struct Sprite*);static void AnimCmd_frame(struct Sprite*);static void AnimCmd_jump(struct Sprite*);static void SeekSpriteAnim(struct Sprite*,u8);static void DecrementAnimDelayCounter(struct Sprite*);
static void unused(struct Sprite*s){}
static void(*sAnimCmdFuncs[])(struct Sprite*)={unused,AnimCmd_jump,unused,AnimCmd_frame};
static void SetSpriteOamFlipBits(struct Sprite*s,u8 h,u8 v){}
static void RequestSpriteFrameImageCopy(s16 i,int t,void*p){}
'''
    prefix+=arrays+'\nstatic const union AnimCmd*const table[]={sAnim_GoSouth2F,sAnim_GoFastSouth2F};\n'
    prefix+='static const struct StepAnimTable step={table,{'+','.join(map(str,positions))+'}};\nstatic const struct StepAnimTable*GetStepAnimTable(const union AnimCmd*const*a){return &step;}\n'
    code=prefix+'\n'.join(fn(sprite,n)for n in ('DecrementAnimDelayCounter','AnimCmd_frame','AnimCmd_jump','ContinueAnim','SeekSpriteAnim'))+'\n'+fn(move,'SetStepAnimHandleAlternation')
    code+='''
int main(void){struct Sprite s={.anims=table,.usingSheet=1};struct ObjectEvent o={0};
for(int f=0;f<2048;f++){int p=f%128;int start=p==0||p==16||p==32||p==40||p==48||p==80||p==96||p==104||p==112;
if(start)SetStepAnimHandleAlternation(&o,&s,(p==32||p==40||p==96||p==104)?1:0);
ContinueAnim(&s);putchar(s.oam.tileNum);}return 0;}
'''
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'oracle.c').write_text(code)
        subprocess.run(['gcc','-std=gnu99','-O2','-Werror',str(root/'oracle.c'),'-o',str(root/'oracle')],check=True,capture_output=True)
        expected=subprocess.check_output([str(root/'oracle')])
        script="local M=dofile(arg[1]..'/follower_motion.lua');local w=dofile(arg[1]..'/world.lua');local a={};for f=0,2047 do local p=f%128;local start=p==0 or p==16 or p==32 or p==40 or p==48 or p==80 or p==96 or p==104 or p==112;if start then M.begin(a,w.followers.motion,p==32 or p==40 or p==96 or p==104)else M.tick(a)end;io.write(string.char(M.frame(a,w.followers.motion)))end"
        (root/'actual.lua').write_text(script);actual=subprocess.check_output([str(luajit),str(root/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'walking/running/step-transition animation differs from source Sprite routines'
        # Compile the real jump routine, including fast/faster branches used by followers.
        jumps='\n'.join(re.search(r'static const s8 '+n+r'\[\]\s*=\s*\{.*?\n\};',move,re.S)[0]for n in ('sJumpY_High','sJumpY_Normal'))
        jump_code='''#include <stdio.h>
#include <stdint.h>
typedef uint8_t u8;typedef int8_t s8;typedef int16_t s16;
struct Sprite{s16 x,y,y2,data[8];};
enum{JUMP_DISTANCE_IN_PLACE,JUMP_DISTANCE_NORMAL,JUMP_DISTANCE_FAR};enum{JUMP_TYPE_HIGH,JUMP_TYPE_LOW,JUMP_TYPE_NORMAL,JUMP_TYPE_FAST,JUMP_TYPE_FASTER};
#define JUMP_HALFWAY 1
#define JUMP_FINISHED 255
#define sDirection data[3]
#define sDistance data[4]
#define sJumpType data[5]
#define sTimer data[6]
static void Step1(struct Sprite*s,int d){s->y++;}static void Step3(struct Sprite*s,int d){s->y+=3;}
'''+jumps+'\nstatic s16 GetJumpY(s16 i,u8 type){return (type==JUMP_TYPE_HIGH?sJumpY_High:sJumpY_Normal)[i];}\n'+fn(move,'DoJumpSpriteMovement')+'''
int main(void){for(int t=0;t<3;t++){struct Sprite s={0};s.sDistance=JUMP_DISTANCE_FAR;s.sJumpType=t==0?JUMP_TYPE_HIGH:t==1?JUMP_TYPE_FAST:JUMP_TYPE_FASTER;while(1){u8 r=DoJumpSpriteMovement(&s);putchar((s.y2+256)%256);if(r==JUMP_FINISHED)break;}}return 0;}
'''
        (root/'jump.c').write_text(jump_code);subprocess.run(['gcc','-std=gnu99','-O2','-Werror',str(root/'jump.c'),'-o',str(root/'jump')],check=True,capture_output=True)
        expected=subprocess.check_output([str(root/'jump')]);actual=bytearray()
        for stride,shape in ((1,spec['jumpY']),(2,spec['jumpNormalY']),(4,spec['jumpNormalY'])):
            for f in range(32//stride):actual.append((0 if f==32//stride-1 else shape[f*stride//2])%256)
        assert bytes(actual)==expected,'source follower jump arcs/durations differ'
    return {'source_c_follower_pose_frames':2048,'source_c_follower_jump_frames':56}
