"""Persistent HnS object shadows and independent follower grass effects."""
import re
from PIL import Image

def build(source,stage,palette):
    config=(source/'include/config/overworld.h').read_text()
    assert re.search(r'#define OW_OBJECT_VANILLA_SHADOWS\s+FALSE',config)
    intensity=int(re.search(r'#define OW_SHADOW_INTENSITY\s+(\d+)',config)[1])
    info=(source/'src/data/field_effects/field_effect_objects.h').read_text()
    offsets=list(map(int,re.findall(r'\d+',re.search(r'gShadowVerticalOffsets\[\]\s*=\s*\{([^}]+)',(source/'src/field_effect_helpers.c').read_text())[1])))
    (stage/'field').mkdir(exist_ok=True);shadows={}
    for i,name in enumerate(('small','medium','large','extra_large')):
        path='graphics/field_effects/pics/shadow_'+name+'.png';im=Image.open(source/path);file='field/shadow_'+name+'.rgba'
        (stage/file).write_bytes(bytes(c for n in im.tobytes()for c in (0,0,0,255 if n else 0)))
        shadows[str(i)]={'file':file,'width':im.width,'height':im.height,'offset':offsets[i],'source':path}
    colors=palette(source/'graphics/field_effects/palettes/general_1.pal');grass={}
    for name,label in (('tall_grass','TallGrass'),('long_grass','LongGrass')):
        path='graphics/field_effects/pics/'+name+'.png';im=Image.open(source/path)
        frames=[im.crop((x,y,x+16,y+16))for y in range(0,im.height,16)for x in range(0,im.width,16)]
        def rgba(n):
            v=colors[n];return (round((v&31)*255/31),round((v>>5&31)*255/31),round((v>>10&31)*255/31),255 if n else 0)
        file='field/'+name+'.rgba';(stage/file).write_bytes(bytes(c for f in frames for n in f.tobytes()for c in rgba(n)))
        body=re.search(r'sAnim_'+label+r'\[\]\s*=\s*\{([^}]+)',info)[1]
        seq=[list(map(int,m))for m in re.findall(r'ANIMCMD_FRAME\((\d+),\s*(\d+)\)',body)]
        grass[name]={'file':file,'width':16,'height':len(frames)*16,'sequence':seq,'source':path}
    return {'intensity':intensity,'none':3,'shadows':shadows,'grass':grass,'limits':'Persistent source shadow sizes/masks and follower grass rustles. Weather suppression and complete non-grass follower ground effects remain unfinished.'}
