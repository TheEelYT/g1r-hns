"""Import source follower track/water art, animations and ground predicates."""
import re
from PIL import Image

ART = {
 'sand_footprints':'SandFootprints','deep_sand_footprints':'DeepSandFootprints',
 'bug_tracks':'BugTracks','spot_tracks':'SpotTracks','slither_tracks':'SlitherTracks','bike_tire_tracks':'BikeTireTracks',
 'splash':'Splash','ripple':'Ripple','sand_pile':'SandPile','hot_springs_water':'HotSpringsWater',
 'jump_small_splash':'JumpSmallSplash','jump_big_splash':'JumpBigSplash',
}

def build(source,stage,palette):
    src=(source/'src/data/field_effects/field_effect_objects.h').read_text()
    gfx=(source/'src/data/object_events/object_event_graphics.h').read_text()
    paths=dict(re.findall(r'(gFieldEffectObjectPic_\w+)\[\]\s*=\s*INCBIN_\w+\("([^"]+)"\)',gfx))
    arts={}
    for name,label in ART.items():
        block=re.search(r'gFieldEffectObjectTemplate_'+label+r'\s*=\s*\{(.*?)\n\};',src,re.S)[1]
        fw,fh=map(int,re.search(r'gObjectEventBaseOam_(\d+)x(\d+)',block).groups())
        bank=int(re.search(r'FLDEFF_PAL_TAG_GENERAL_(\d+)',block)[1])
        palpath='graphics/field_effects/palettes/general_'+str(bank)+'.pal';colors=palette(source/palpath)
        pictures=re.search(r'\.images = (\w+)',block)[1]
        picbody=re.search(pictures+r'\[\]\s*=\s*\{(.*?)\n\};',src,re.S)[1]
        frames=re.findall(r'overworld_frame\((\w+),\s*\d+,\s*\d+,\s*(\d+)\)',picbody)
        if not frames:frames=[(re.search(r'obj_frame_tiles\((\w+)\)',picbody)[1],'0')]
        symbol=frames[0][0];path=str(__import__('pathlib').Path(paths[symbol]).with_suffix('.png'));im=Image.open(source/path)
        raw=bytearray()
        for sym,n in frames:
            assert sym==symbol;n=int(n);x=n%(im.width//fw)*fw;y=n//(im.width//fw)*fh
            assert x+fw<=im.width and y+fh<=im.height
            for v in im.crop((x,y,x+fw,y+fh)).tobytes():
                c=colors[v];raw.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if v else 0))
        table=re.search(r'\.anims = (\w+)',block)[1]
        body=re.search(table+r'\[\]\s*=\s*\{(.*?)\n\};',src,re.S)[1]
        seqs=[]
        for anim in re.findall(r'\b(s\w+)\s*,',body):
            body=re.search(anim+r'\[\]\s*=\s*\{(.*?)\n\};',src,re.S)[1];cmds=[]
            for cmd,args in re.findall(r'ANIMCMD_(FRAME|JUMP|END)(?:\(([^)]*)\))?',body):
                if cmd=='FRAME':
                    ns=list(map(int,re.findall(r'^\s*(\d+)\s*,\s*(\d+)',args)[0]));cmds.append(['frame',*ns,'.hFlip = TRUE'in args,'.vFlip = TRUE'in args])
                elif cmd=='JUMP':cmds.append(['jump',int(args)])
                else:cmds.append(['end'])
            assert cmds;seqs.append(cmds)
        file='field/'+name+'.rgba';(stage/file).write_bytes(raw)
        arts[name]={'file':file,'width':fw,'height':len(frames)*fh,'fw':fw,'fh':fh,'source':path,'sourcePalette':palpath,'sourceTemplate':label,'frameOrder':[int(n)for _,n in frames],'anims':seqs}
    behavior=(source/'src/metatile_behavior.c').read_text();pred={}
    for key,fn in [('sand','IsSandOrDeepSand'),('deep','IsDeepSand'),('prints','IsFootprints'),('puddle','IsPuddle'),('ripple','HasRipples'),('flow','IsShallowFlowingWater'),('logs','IsPacifidlogLog'),('spring','IsHotSprings')]:
        body=re.search(r'bool8 MetatileBehavior_'+fn+r'\([^)]*\)\s*\{(.*?)\n\}',behavior,re.S)[1]
        pred[key]=re.findall(r'== MB_(\w+)',body)
    move=(source/'src/event_object_movement.c').read_text()
    transitions=re.search(r'slitherTracks_Transitions\[4\]\[4\]\s*=\s*\{(.*?)\n    \};',move,re.S)[1]
    transitions=[list(map(int,re.findall(r'\d+',row)))for row in re.findall(r'\{([^}]+)\}',transitions)]
    se=int(re.search(r'#define SE_PUDDLE\s+(\d+)',(source/'include/constants/songs.h').read_text())[1])
    return {'art':arts,'behaviors':pred,'turns':transitions,'puddleSe':se,'trackWaitFrames':40,'trackEndFrame':56,'limits':'Follower source tracks, sand pile, shallow water, puddles, ripples and hot springs. Reflections, seaweed bubbles, ash and further map-specific effects remain pending.'}
