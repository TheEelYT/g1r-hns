"""Compare imported shadow masks and grass pixels/sequences with source."""
import re,subprocess,tempfile
from pathlib import Path
from PIL import Image

def check(source,mod,world):
    spec=world['fieldShadows'];assert spec['paletteTag']==0x1005 and spec['timeBlend']is True
    header=(source/'include/palette.h').read_text();assert re.search(r'#define BLEND_IMMUNE_FLAG\s+\(1 << 15\)',header)
    assert 'FLDEFF_PAL_TAG_GENERAL_1' in re.search(r'const struct SpriteTemplate gFieldEffectObjectTemplate_ShortGrass = \{(.*?)\n\};',(source/'src/data/field_effects/field_effect_objects.h').read_text(),re.S)[1]
    config=(source/'include/config/overworld.h').read_text()
    assert re.search(r'#define OW_OBJECT_VANILLA_SHADOWS\s+FALSE',config)
    assert spec['intensity']==int(re.search(r'#define OW_SHADOW_INTENSITY\s+(\d+)',config)[1])
    assert spec['none']==int(re.search(r'#define SHADOW_SIZE_NONE\s+(\d+)',(source/'include/constants/event_objects.h').read_text())[1])
    movement=(source/'src/event_object_movement.c').read_text()
    for name,key in [('Subpriority','elevationSubpriority'),('Priority','elevationPriority')]:
        body=re.search(r'sElevationTo'+name+r'\[\]\s*=\s*\{([^}]+)',movement)[1]
        assert spec[key]=={str(i):int(v)for i,v in enumerate(re.findall(r'\d+',body))}
    # Compile the actual source table and predicates independently of the importer.
    code=(source/'src/metatile_behavior.c').read_text()
    table=re.search(r'static const u8 sTileBitAttributes\[.*?\n\};',code,re.S)[0]
    fns='\n'.join(re.search(r'bool8 MetatileBehavior_'+name+r'\([^)]*\)\s*\{.*?\n\}',code,re.S)[0]for name in ('IsPokeGrass','IsPuddle','IsSurfableWaterOrUnderwater'))
    names=re.findall(r'^\s*(MB_\w+),', (source/'include/constants/metatile_behaviors.h').read_text(),re.M)
    program='#include <stdio.h>\n#include "constants/metatile_behaviors.h"\ntypedef unsigned char u8;typedef int bool8;\n#define TRUE 1\n#define FALSE 0\n#define TILE_FLAG_HAS_ENCOUNTERS 1\n#define TILE_FLAG_SURFABLE 2\n#define TILE_FLAG_UNUSED 4\n'+table+'\n'+fns+'\nint main(void){\n'+''.join(f'printf("{n[3:]} %d %d %d\\n",MetatileBehavior_IsPokeGrass({n}),MetatileBehavior_IsPuddle({n}),MetatileBehavior_IsSurfableWaterOrUnderwater({n}));'for n in names)+'return 0;}\n'
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);(root/'source.c').write_text(program)
        subprocess.run(['gcc','-std=gnu99','-O2','-Werror','-I',str(source/'include'),str(root/'source.c'),'-o',str(root/'source')],check=True)
        rows=[line.split()for line in subprocess.check_output([str(root/'source')],text=True).splitlines()]
    assert set(spec['suppression']['grass'])=={r[0]for r in rows if r[1]=='1'}
    assert set(spec['suppression']['water'])=={r[0]for r in rows if r[3]=='1'}
    assert {r[0]for r in rows if r[2]=='1'}=={'PUDDLE'}
    weather=(source/'src/field_weather_effect.c').read_text()
    setters=re.findall(r'void (\w+)_InitVars\(void\)\s*\{(.*?)\n\}',weather,re.S)
    assert {n for n,body in setters if 'noShadows = TRUE' in body}=={'FogDiagonal','Bubbles'}
    assert spec['suppression']['weather']==[9,14]
    pixels,grass=0,0
    for r in spec['shadows'].values():
        im=Image.open(source/r['source']);assert (im.width,im.height)==(r['width'],r['height'])
        assert (mod/r['file']).read_bytes()==bytes(c for n in im.tobytes()for c in (0,0,0,255 if n else 0));pixels+=im.width*im.height
    cols=[tuple(map(int,line.split()))for line in (source/'graphics/field_effects/palettes/general_1.pal').read_text().splitlines()[3:]]
    anim=(source/'src/data/field_effects/field_effect_objects.h').read_text()
    for n,r in spec['grass'].items():
        im=Image.open(source/r['source']);expected=[]
        for y in range(0,im.height,16):
            for x in range(0,im.width,16):
                for v in im.crop((x,y,x+16,y+16)).tobytes():expected.extend([round((c//8)*255/31)for c in cols[v]]+[255 if v else 0])
        assert (mod/r['file']).read_bytes()==bytes(expected);grass+=im.width*im.height
        body=re.search(r'sAnim_'+{'tall_grass':'TallGrass','long_grass':'LongGrass','short_grass':'ShortGrass'}[n]+r'\[\]\s*=\s*\{([^}]+)',anim)[1]
        assert r['sequence']==[list(map(int,m))for m in re.findall(r'ANIMCMD_FRAME\((\d+),\s*(\d+)\)',body)]
    assert all(r.get('shadowSize')in range(4)for r in world['opening']['sprites'].values())
    return {'source_c_shadow_behavior_rows':len(rows),'source_shadow_no_shadow_weathers':len(spec['suppression']['weather']),'source_shadow_mask_pixels':pixels,'source_shadow_size_rows':len(world['opening']['sprites']),'source_follower_grass_pixels':grass,'source_follower_grass_sequences':len(spec['grass'])}
