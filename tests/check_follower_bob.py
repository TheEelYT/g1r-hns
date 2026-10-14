"""Compile the actual following-movement callback's normal walking y2 trace."""
import re,subprocess,tempfile
from pathlib import Path

def check(source,engine,mod,luajit):
    src=(source/'src/event_object_movement.c').read_text()
    fn=re.search(r'bool8 MovementType_FollowPlayer_Moving\([^;]*?\)\n\{.*?\n\}',src,re.S)[0]
    code='''#include <stdio.h>
typedef int bool8;
#define FALSE 0
#define TRUE 1
#define OW_FOLLOWERS_BOBBING 1
#define MOVEMENT_ACTION_NONE 0
#define MOVEMENT_ACTION_EXIT_POKEBALL 1
struct ObjectEvent{int movementActionId,singleMovementActive,facingDirectionLocked;};
struct Sprite{int y2,data[8],sActionFuncId,sTypeFuncId;};
static bool8 step(struct ObjectEvent*o,struct Sprite*s){return ++s->data[5]>=16;}
static bool8(*gMovementActionFuncs[1][1])(struct ObjectEvent*,struct Sprite*)={{step}};
static void UpdateFollowerTransformEffect(struct ObjectEvent*o,struct Sprite*s){}
'''+fn+'''
int main(void){struct ObjectEvent o={0};struct Sprite s={0};for(int n=0;n<8;n++){s.data[5]=0;for(int f=1;f<=16;f++){MovementType_FollowPlayer_Moving(&o,&s);putchar((s.y2+256)%256);}}return 0;}
'''
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'source.c').write_text(code)
        subprocess.run(['gcc','-std=gnu99','-O2','-Werror',str(root/'source.c'),'-o',str(root/'source')],check=True)
        expected=subprocess.check_output([str(root/'source')])
        (root/'actual.lua').write_text("local M=dofile(arg[1]..'/follower_motion.lua');for n=1,8 do for f=1,16 do io.write(string.char((M.walkBob(f)+256)%256))end end")
        actual=subprocess.check_output([str(luajit),str(root/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'walking bob differs from source movement callback'
    return {'source_c_follower_walking_bob_frames':128}
