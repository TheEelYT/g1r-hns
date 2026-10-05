"""Small source UI assets, independent of the host game's field font/cache."""
import re
from PIL import Image

def build(source, stage, palette_parser):
    import fidelity
    glyphs={c:int(h,16) for c,h in re.findall(r"^'(.+)'\s*=\s*([0-9A-F]{2})\s*$",(source/'charmap.txt').read_text(),re.M) if len(c)==1}
    glyphs.update({"'":glyphs['’'], '"':glyphs['“'], '-':glyphs.get('−',glyphs.get('-',174))})
    glyphs['▶']=int(re.search(r'^RIGHT_ARROW\s*=\s*([0-9A-F]{2})',(source/'charmap.txt').read_text(),re.M)[1],16)
    # CHAR_EXTRA_SYMBOL followed by NO; this is one bitmap, not three letters.
    glyphs['№']=256+int(re.search(r'^NO\s*=\s*F9 ([0-9A-F]{2})',(source/'charmap.txt').read_text(),re.M)[1],16)
    tokens={name:(256 if bank else 0)+int(code,16)for name,bank,code in re.findall(r'^([A-Z][A-Z_0-9]+)\s*=\s*(F9 )?([0-9A-F]{2})\s*$',(source/'charmap.txt').read_text(),re.M)}
    fonts={}
    for name in ('normal','small','narrow','small_narrower'):
        im=Image.open(source/f'graphics/fonts/latin_{name}.png')
        widths=list(map(int,re.search(r'gFont'+''.join(v.title()for v in name.split('_'))+r'LatinGlyphWidths\[\]\s*=\s*\{(.*?)\};',(source/'src/fonts.c').read_text(),re.S)[1].replace('\n','').split(',')[:-1]))
        assert len(widths)==512 and im.size==(256,512)
        info={'widths':widths,'width':im.width,'height':im.height}
        for layer,index in [('fg',1),('shadow',2)]:
            path=f'ui/font_{name}_{layer}.rgba';(stage/path).parent.mkdir(exist_ok=True)
            (stage/path).write_bytes(b''.join(bytes((255,255,255,255 if p==index else 0)) for p in im.tobytes()))
            info[layer]=path
        fonts[name]=info
    art={}
    keypad=Image.open(source/'graphics/fonts/keypad_icons.png');cols=keypad.width//8
    for name,off,w in [('A_BUTTON',0,8),('B_BUTTON',1,8),('L_BUTTON',2,16),('R_BUTTON',4,16),('START_BUTTON',6,24),('SELECT_BUTTON',9,24),('DPAD_UPDOWN',32,8)]:
        out=Image.new('P',(w,16));out.putpalette(keypad.getpalette())
        for ty in range(2):
            for tx in range(w//8):
                tid=off+ty*16+tx;out.paste(keypad.crop(((tid%cols)*8,(tid//cols)*8,(tid%cols+1)*8,(tid//cols+1)*8)),(tx*8,ty*8))
        rgb=keypad.getpalette();file='ui/keypad_'+name+'.rgba'
        (stage/file).write_bytes(bytes(v for i in out.tobytes()for v in ((*[round((rgb[i*3+j]//8)*255/31)for j in range(3)],255)if i else(0,0,0,0))))
        art[name]={'file':file,'width':w,'height':16}
    for name,path,pal in [('frame','graphics/text_window/1.png',None),('callFrame','graphics/pokenav/hns/match_call/window.png','graphics/pokenav/hns/match_call/window.pal'),('callIcon','graphics/pokenav/hns/match_call/nav_icon.png','graphics/pokenav/hns/match_call/nav_icon.pal'),('callName','graphics/pokenav/name_box.png','graphics/pokenav/hns/match_call/window.pal')]:
        art[name]=fidelity.image(source,stage,path,'ui/'+name+'.rgba',palette_parser,pal)
    for name in ('question','exclamation'):
        art[name]=fidelity.image(source,stage,f'graphics/field_effects/pics/emotion_{name}.png',f'ui/{name}.rgba',palette_parser)
    for frame in range(2,21):
        art[f'frame{frame}']=fidelity.image(source,stage,f'graphics/text_window/{frame}.png',f'ui/frame{frame}.rgba',palette_parser)
    for name in ('chikorita','cyndaquil','totodile'):
        im=Image.open(source/f'graphics/pokemon/{name}/anim_front.png').crop((0,0,64,64))
        pal=palette_parser(source/f'graphics/pokemon/{name}/normal.pal');pixels=bytearray()
        for v in im.tobytes():
            c=pal[v];pixels.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if v else 0))
        path=f'ui/{name}.rgba';(stage/path).write_bytes(pixels);art[name]={'file':path,'width':64,'height':64}
    import menu_assets
    art.update(menu_assets.build(source,stage))
    import presentation_assets
    extra,presentation=presentation_assets.build(source,stage)
    art.update(extra)
    colors=palette_parser(source/'graphics/interface/option_menu_text_custom.pal')
    rgb=lambda c:[round((c&31)*255/31)/255,round((c>>5&31)*255/31)/255,round((c>>10&31)*255/31)/255,1]
    palette=Image.open(source/'graphics/pokenav/hns/match_call/window.png').getpalette()
    callcolors=[(palette[i*3]//8)|((palette[i*3+1]//8)<<5)|((palette[i*3+2]//8)<<10) for i in range(16)]
    # The namebox has its own indexed tiles but uses match-call palette 14,
    # not the green palette embedded in its standalone PNG.
    im=Image.open(source/'graphics/pokenav/name_box.png');(stage/art['callName']['file']).write_bytes(bytes(v for i in im.tobytes() for v in (*[round(x*255) for x in rgb(callcolors[i])[:3]],255 if i else 0)))
    palette=Image.open(source/'graphics/pokenav/hns/match_call/nav_icon.png').getpalette()
    iconcolors=[(palette[i*3]//8)|((palette[i*3+1]//8)<<5)|((palette[i*3+2]//8)<<10) for i in range(16)]
    return {'fonts':fonts,'glyphs':glyphs,'tokens':tokens,'art':art,'presentation':presentation,'colors':[rgb(c) for c in colors], 'callColors':[rgb(c) for c in callcolors], 'iconColors':[rgb(c) for c in iconcolors]}
