"""Source-owned healing effect assets and map layout style."""
from PIL import Image

def build(source,stage,maps,source_maps,layouts,palette_parser):
    root=source/'graphics/field_effects'
    out=stage/'field_effects';out.mkdir()
    colors=palette_parser(root/'palettes/pokeball_glow.pal')
    rgb=[(round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31)) for c in colors]
    ball=Image.open(root/'pics/pokeball_glow.png')
    assert ball.mode=='P' and ball.size==(8,8)
    (out/'pokeball_glow.idx').write_bytes(ball.tobytes())
    (out/'pokeball_glow.pal').write_bytes(bytes(v for c in rgb for v in c))
    def rgba(image,palette):
        assert image.mode=='P'
        return bytes(v for n in image.tobytes() for v in (*palette[n],255 if n else 0))
    (out/'hns_center_monitor.rgba').write_bytes(rgba(Image.open(root/'pics/pokecenter_monitor/frlg.png'),rgb))
    # Emerald's 24x16 monitor uses the field-effect general palette.
    general=palette_parser(root/'palettes/general_0.pal')
    general_rgb=[(round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31)) for c in general]
    (out/'hns_center_monitor_rse.rgba').write_bytes(b''.join(rgba(Image.open(root/f'pics/pokecenter_monitor/{i}.png'),general_rgb) for i in (0,1)))
    for mid,m in maps.items():m['hnsLayoutVersion']=layouts[source_maps[m['hnsSourceId']]['layout']].get('layout_version','emerald')
    return {'files':['pokeball_glow.idx','pokeball_glow.pal','hns_center_monitor.rgba','hns_center_monitor_rse.rgba'],
            'source':'src/field_effect.c','healEffect':25}
