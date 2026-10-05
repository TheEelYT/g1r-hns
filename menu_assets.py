"""Decode pinned HnS Pokégear backgrounds and battle/menu sprite assets."""
import struct
from PIL import Image


def build(source, stage):
    art = {}

    def palette(path, bank=0):
        p = source / path
        if p.exists():
            lines = p.read_text().splitlines()
            colors = [tuple(map(int, s.split())) for s in lines[3:3+int(lines[2])]]
        else:
            colors = list(zip(*[iter(Image.open(p.with_suffix('.png')).getpalette())]*3))
        # The GBA palette converter truncates 8-bit channels to five bits.
        return [tuple(round((v//8)*255/31) for v in c) for c in colors[bank*16:bank*16+16]]

    def rgba(im, colors):
        return Image.frombytes('RGBA', im.size, bytes(v for i in im.tobytes() for v in (*colors[i], 255 if i else 0)))

    def save(name, im):
        path = 'ui/'+name+'.rgba'
        (stage/path).parent.mkdir(parents=True, exist_ok=True)
        (stage/path).write_bytes(im.tobytes())
        art[name] = {'file':path, 'width':im.width, 'height':im.height}

    def tiles(im):
        return [im.crop((x,y,x+8,y+8)) for y in range(0,im.height,8) for x in range(0,im.width,8)]

    def bg(name, graphic, tilemap, pal):
        ts = tiles(rgba(Image.open(source/graphic), palette(pal)))
        raw=(source/tilemap).read_bytes()
        words = struct.unpack('<%dH'%(len(raw)//2),raw)
        assert len(words) in (640,1024),tilemap
        im = Image.new('RGBA', (256,256))
        for i,w in enumerate(words):
            tile = ts[w & 1023]
            if w & 1024: tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if w & 2048: tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            im.paste(tile, (i%32*8,i//32*8))
        save(name, im)

    root = 'graphics/pokenav/'
    for name, graphic, tilemap in [('gearDots','bg_dots.png','bg_dots.bin'),('gearDevice','device_outline.png','device_outline_map.bin'),('gearHeader','header.png','header.bin')]:
        bg(name,root+'hns/'+graphic,root+'hns/'+tilemap,root+'hns/'+graphic.replace('.png','.pal'))
    bg('gearMessage',root+'hns/message.png',root+'message.bin',root+'hns/message.pal')
    # Four 32x16 OBJ subsprites laid out horizontally, per DrawOptionLabelGfx.
    for name,path,bank in [('MAP','hns/options/hoenn_map.png',0),('PHONE','hns/options/match_call.png',4),('RADIO','hns/options/radio.png',0),('CONDITION','options/condition.png',1),('RIBBONS','options/ribbons.png',2),('SWITCH OFF','options/switch_off.png',3)]:
        src = rgba(Image.open(source/(root+path)),palette(root+'hns/options/options.pal',bank))
        im = Image.new('RGBA',(128,16))
        for j in range(4):im.paste(src.crop((0,j*16,32,j*16+16)),(j*32,0))
        label='gearButton'+name.replace(' ','')
        save(label,im)
        # Task_CurrentMenuOptionGlow selects a sine-based BLDY coefficient
        # from 0 through 8. GBA brightness operates on five-bit OBJ colors.
        for coefficient in range(1,9):
            pixels=[]
            for r,g,b,a in im.get_flattened_data():
                channels=[round(v*31/255)for v in (r,g,b)]
                pixels.append(tuple(round((v+((31-v)*coefficient//16))*255/31)for v in channels)+(a,))
            glow=Image.new('RGBA',im.size);glow.putdata(pixels);save(label+'Glow'+str(coefficient),glow)
    # Main header is two 64x32 OBJ sprites, rather than a BG tile sheet.
    src = rgba(Image.open(source/(root+'left_headers/main_menu.png')),palette(root+'hns/left_headers/palette.pal',3))
    im=Image.new('RGBA',(128,32));im.paste(src.crop((0,0,64,32)),(0,0));im.paste(src.crop((0,32,64,64)),(64,0));save('gearTitle',im)
    save('gearIcon',rgba(Image.open(source/(root+'hns/nav_icon.png')),palette(root+'hns/nav_icon.pal')))
    save('moveHint',rgba(Image.open(source/'graphics/battle_interface/move_info_window_start.png'),palette('graphics/battle_interface/hns/ability_pop_up.pal')))
    save('moveCategory',rgba(Image.open(source/'graphics/interface/category_icons.png'),palette('graphics/interface/category_icons.pal')))
    return art
