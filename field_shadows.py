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
    for name,label in (('tall_grass','TallGrass'),('long_grass','LongGrass'),('short_grass','ShortGrass')):
        path='graphics/field_effects/pics/'+name+'.png';im=Image.open(source/path)
        frames=[im.crop((x,y,x+16,y+16))for y in range(0,im.height,16)for x in range(0,im.width,16)]
        def rgba(n):
            v=colors[n];return (round((v&31)*255/31),round((v>>5&31)*255/31),round((v>>10&31)*255/31),255 if n else 0)
        file='field/'+name+'.rgba';(stage/file).write_bytes(bytes(c for f in frames for n in f.tobytes()for c in rgba(n)))
        body=re.search(r'sAnim_'+label+r'\[\]\s*=\s*\{([^}]+)',info)[1]
        seq=[list(map(int,m))for m in re.findall(r'ANIMCMD_FRAME\((\d+),\s*(\d+)\)',body)]
        grass[name]={'file':file,'width':16,'height':len(frames)*16,'sequence':seq,'source':path}
    movement=(source/'src/event_object_movement.c').read_text()
    def elevation(name):
        body=re.search(r'sElevationTo'+name+r'\[\]\s*=\s*\{([^}]+)',movement)[1]
        return {str(i):int(v) for i,v in enumerate(re.findall(r'\d+',body))}
    behavior=(source/'src/metatile_behavior.c').read_text()
    grass_fn=re.search(r'bool8 MetatileBehavior_IsPokeGrass\([^)]*\)\s*\{(.*?)\n\}',behavior,re.S)[1]
    grasses=re.findall(r'== MB_(\w+)',grass_fn)
    water=re.findall(r'\[MB_(\w+)\]\s*=\s*([^,]+)',behavior.split('};',1)[0])
    waters=[name for name,flags in water if 'TILE_FLAG_SURFABLE' in flags]
    weather=(source/'src/field_weather_effect.c').read_text()
    no_shadow=[]
    constants=(source/'include/constants/weather.h').read_text()
    for fn,name in [('FogDiagonal_InitVars','FOG_DIAGONAL'),('Bubbles_InitVars','UNDERWATER_BUBBLES')]:
        body=re.search(r'void '+fn+r'\([^)]*\)\s*\{(.*?)\n\}',weather,re.S)[1]
        assert 'gWeatherPtr->noShadows = TRUE;' in body
        no_shadow.append(int(re.search(r'#define WEATHER_'+name+r'\s+(\d+)',constants)[1]))
    tag=int(re.search(r'#define FLDEFF_PAL_TAG_GENERAL_1\s+(0x[0-9A-Fa-f]+)',(source/'include/constants/field_effects.h').read_text())[1],16)
    assert tag&0x8000==0  # source palette.h BLEND_IMMUNE_FLAG
    helper=(source/'src/field_effect_helpers.c').read_text()
    filters={}
    for kind,fn in [('pond','ApplyPondFilter'),('ice','ApplyIceFilter')]:
        body=re.search(r'static void '+fn+r'\([^;]*?\)\n\{.*?\n\}',helper,re.S)[0]
        delta={c:0 for c in 'rgb'}
        for c,op,n in re.findall(r'([rgb]) ([+-])= (\d+);',body):delta[c]=int(n)*(1 if op=='+' else -1)
        filters[kind]=[delta[c] for c in 'rgb']
    bridge=int(re.search(r'CpuFill16\((0x[0-9A-Fa-f]+), blueData',helper)[1],16)
    reflection={'filters':filters,'bridgeColor':bridge}
    import follower_ground
    ground=follower_ground.build(source,stage,palette)
    return {'reflection':reflection,'ground':ground,'paletteTag':tag,'timeBlend':True,'intensity':intensity,'none':3,'shadows':shadows,'grass':grass,'elevationSubpriority':elevation('Subpriority'),'elevationPriority':elevation('Priority'),'suppression':{'grass':grasses,'water':waters,'weather':no_shadow},'limits':'Source shadow sizes/masks, ordering and weather/ground suppression; follower grass rustles. Complete non-grass follower ground effects remain unfinished.'}
