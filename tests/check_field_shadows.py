"""Compare imported shadow masks and grass pixels/sequences with source."""
import re
from PIL import Image

def check(source,mod,world):
    spec=world['fieldShadows'];config=(source/'include/config/overworld.h').read_text()
    assert re.search(r'#define OW_OBJECT_VANILLA_SHADOWS\s+FALSE',config)
    assert spec['intensity']==int(re.search(r'#define OW_SHADOW_INTENSITY\s+(\d+)',config)[1])
    assert spec['none']==int(re.search(r'#define SHADOW_SIZE_NONE\s+(\d+)',(source/'include/constants/event_objects.h').read_text())[1])
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
    return {'source_shadow_mask_pixels':pixels,'source_shadow_size_rows':len(world['opening']['sprites']),'source_follower_grass_pixels':grass,'source_follower_grass_sequences':len(spec['grass'])}
