"""Independent source pixels/animation commands and compiled track-fade oracle."""
import re,subprocess,tempfile
from pathlib import Path
from PIL import Image

def check(source,engine,mod,world,lua):
    spec=world['fieldShadows']['ground'];header=(source/'src/data/field_effects/field_effect_objects.h').read_text()
    gfx=(source/'src/data/object_events/object_event_graphics.h').read_text();pixels=0;commands=0;declarations={};expected=[]
    for name,r in spec['art'].items():
        block=re.search(r'gFieldEffectObjectTemplate_'+r['sourceTemplate']+r'\s*=\s*\{(.*?)\n\};',header,re.S)[1]
        bank=int(re.search(r'FLDEFF_PAL_TAG_GENERAL_(\d+)',block)[1]);assert r['sourcePalette']==f'graphics/field_effects/palettes/general_{bank}.pal'
        fw,fh=map(int,re.search(r'Oam_(\d+)x(\d+)',block).groups());assert (fw,fh)==(r['fw'],r['fh'])
        pic=re.search(r'\.images = (\w+)',block)[1];body=re.search(pic+r'\[\]\s*=\s*\{(.*?)\n\};',header,re.S)[1]
        frames=re.findall(r'overworld_frame\((\w+),\s*\d+,\s*\d+,\s*(\d+)\)',body)
        if not frames:frames=[(re.search(r'obj_frame_tiles\((\w+)\)',body)[1],'0')]
        symbol=frames[0][0];path=re.search(symbol+r'\[\]\s*=\s*INCBIN_\w+\("([^"]+)"',gfx)[1]
        assert str(Path(path).with_suffix('.png'))==r['source'];assert [int(n)for _,n in frames]==r['frameOrder']
        im=Image.open(source/r['source']);pal=[tuple(map(int,line.split()))for line in (source/r['sourcePalette']).read_text().splitlines()[3:]];raw=bytearray()
        for _,n in frames:
            n=int(n);x=n%(im.width//fw)*fw;y=n//(im.width//fw)*fh
            for v in im.crop((x,y,x+fw,y+fh)).tobytes():raw.extend(tuple(round((c//8)*255/31)for c in pal[v])+(255 if v else 0,))
        assert (mod/r['file']).read_bytes()==raw,name;pixels+=len(raw)//4
        table=re.search(r'\.anims = (\w+)',block)[1];body=re.search(table+r'\[\]\s*=\s*\{(.*?)\n\};',header,re.S)[1]
        names=re.findall(r'\b(s\w+)\s*,',body);assert len(names)==len(r['anims'])
        for anim,cmds in zip(names,r['anims']):
            body=re.search(r'(?:static )?const union AnimCmd '+anim+r'\[\]\s*=\s*\{.*?\n\};',header,re.S)[0]
            declarations[anim]=body.replace('union AnimCmd','struct Cmd')
            for i,c in enumerate(cmds):
                expected.append((anim,i,[c[1],c[2],int(c[3]),int(c[4])]if c[0]=='frame'else[-2,c[1],0,0]if c[0]=='jump'else[-1,0,0,0]));commands+=1
    code='''#include <stdio.h>
#define TRUE 1
#define ANIMCMD_FRAME(...) {__VA_ARGS__}
#define ANIMCMD_END {-1}
#define ANIMCMD_JUMP(n) {-2,n}
struct Cmd{int frame,delay,hFlip,vFlip;};
'''+ '\n'.join(declarations.values())+'\nint main(void){\n'+''.join(f'printf("%d %d %d %d\\n",{n}[{i}].frame,{n}[{i}].delay,{n}[{i}].hFlip,{n}[{i}].vFlip);'for n,i,_ in expected)+'return 0;}\n'
    helper=(source/'src/field_effect_helpers.c').read_text()
    fade='\n'.join(re.search(r'static void '+name+r'\([^;]*?\)\n\{.*?\n\}',helper,re.S)[0]for name in ('FadeFootprintsTireTracks_Step0','FadeFootprintsTireTracks_Step1'))
    fadecode='''#include <stdio.h>
#define FALSE 0
struct Sprite{int sTimer,sState,invisible,sFldEff;};
static int stopped;
static void UpdateObjectEventSpriteInvisibility(struct Sprite*s,int hidden){}
static void FieldEffectStop(struct Sprite*s,int effect){stopped=1;}
'''+fade+'''\nint main(void){struct Sprite s={0};for(int f=1;f<=57;f++){if(s.sState)FadeFootprintsTireTracks_Step1(&s);else FadeFootprintsTireTracks_Step0(&s);putchar(stopped?2:s.invisible);}return 0;}\n'''
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp)
        for name,program in [('anim',code),('fade',fadecode)]:
            (root/(name+'.c')).write_text(program);subprocess.run(['gcc','-std=gnu99','-O2','-Werror',str(root/(name+'.c')),'-o',str(root/name)],check=True)
        actual=[list(map(int,line.split()))for line in subprocess.check_output([str(root/'anim')],text=True).splitlines()]
        assert actual==[r[2]for r in expected],'source C frame/flip commands differ'
        reference=subprocess.check_output([str(root/'fade')])
        # Native integration tests check the actual RSE entry on every tick.
        # This independent C trace locks their expected hold/flicker/expiry
        # against the source callback, rather than the importer timer fields.
        assert reference==bytes([0]*41+[int(f%2==0)for f in range(42,57)]+[2])
    behavior=(source/'src/metatile_behavior.c').read_text()
    funcs={'sand':'IsSandOrDeepSand','deep':'IsDeepSand','prints':'IsFootprints','puddle':'IsPuddle','ripple':'HasRipples','flow':'IsShallowFlowingWater','logs':'IsPacifidlogLog','spring':'IsHotSprings'}
    for key,name in funcs.items():
        body=re.search(r'bool8 MetatileBehavior_'+name+r'\([^)]*\)\s*\{(.*?)\n\}',behavior,re.S)[1]
        assert set(spec['behaviors'][key])==set(re.findall(r'== MB_(\w+)',body))
    cue=world['audio']['groundSounds']['SE_PUDDLE'];assert world['audio']['songs'][str(cue)]=='SE_PUDDLE'
    assert cue-world['audio']['base']==spec['puddleSe']
    move=(source/'src/event_object_movement.c').read_text()
    for kind,fn,effect in [('SPOT','FootprintsC','TRACKS_BUG'),('BUG','FootprintsB','TRACKS_SPOT')]:
        assert re.search(r'\[TRACKS_'+kind+r'\] = DoTracksGroundEffect_'+fn,move)
        body=re.search(r'static void DoTracksGroundEffect_'+fn+r'\([^;]*?\)\n\{.*?\n\}',move,re.S)[0];assert 'FLDEFF_'+effect in body
    assert all(r.get('trackType','TRACKS_NONE').startswith('TRACKS_')for r in world['opening']['sprites'].values())
    return {'source_follower_ground_sound_effects':1,'source_follower_ground_art_sheets':len(spec['art']),'source_follower_ground_pixels':pixels,'source_c_follower_ground_anim_commands':commands,'source_c_follower_track_fade_frames':len(reference)}
