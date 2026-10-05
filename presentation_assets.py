"""Source tilemaps/OBJ art for Pokégear services and the HnS trainer card."""
import json
import re
import struct
from PIL import Image


def build(source, stage):
    art = {}
    def palette(path):
        p = source / path
        if p.exists():
            lines = p.read_text().splitlines()
            values = [tuple(map(int, s.split())) for s in lines[3:3+int(lines[2])]]
        else:
            raw = Image.open(p.with_suffix('.png')).getpalette()
            values = [tuple(raw[i:i+3]) for i in range(0,len(raw),3)]
        out=[tuple(round((v//8)*255/31) for v in c)+(255,) for c in values]
        return out+[(0,0,0,255)]*((16-len(out)) if len(out)<16 else 0)
    def save(name, im, provenance):
        path='ui/'+name+'.rgba';(stage/path).write_bytes(im.tobytes())
        art[name]={'file':path,'width':im.width,'height':im.height,'source':provenance}
    def sprite(name, path, pal=None, bank=0, header=False):
        src=Image.open(source/path);colors=palette(pal or path.replace('.png','.pal'))[bank*16:bank*16+16]
        indices=src.tobytes() if src.mode=='P' else bytes(15-(i>>4) for i in src.convert('L').tobytes())
        out=Image.frombytes('RGBA',src.size,bytes(v for i in indices for v in (colors[i&15] if i&15 else (0,0,0,0))))
        if header:
            joined=Image.new('RGBA',(128,32))
            for i in range(2):joined.paste(out.crop((0,i*32,64,i*32+32)),(i*64,0))
            out=joined
        save(name,out,{'kind':'sprite','graphic':path,'palette':pal,'bank':bank,'header':header})
    def bg(name,path,tilemap,pals,offset=0,cols=32):
        src=Image.open(source/path);tiles=[src.crop((x,y,x+8,y+8)) for y in range(0,src.height,8) for x in range(0,src.width,8)]
        colors={n:palette(p) for n,p in pals.items()};words=struct.unpack('<%dH'%((source/tilemap).stat().st_size//2),(source/tilemap).read_bytes())
        out=Image.new('RGBA',(240,160))
        for i,w in enumerate(words):
            x,y=i%cols*8,i//cols*8
            if x>=240 or y>=160:continue
            tid=(w&1023)-offset;assert 0<=tid<len(tiles),(name,tid)
            tile=tiles[tid]
            if w&1024:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if w&2048:tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            pal=colors[w>>12]
            tile=Image.frombytes('RGBA',(8,8),bytes(v for n in tile.tobytes() for v in (pal[n&15] if n&15 else (0,0,0,0))))
            out.paste(tile,(x,y))
        save(name,out,{'kind':'background','graphic':path,'tilemap':tilemap,'palettes':pals,'offset':offset,'columns':cols})
    root='graphics/pokenav/'
    sprite('gearListCursor',root+'hns/list_arrows.png',root+'hns/list_arrows.pal')
    for label,path,bank in [('Map','hns/left_headers/hoenn_map.png',0),('Phone','hns/left_headers/match_call.png',4),('Condition','left_headers/condition.png',1),('Ribbons','left_headers/ribbons.png',2)]:
        sprite('gearTitle'+label,root+path,root+'hns/left_headers/palette.pal',bank,True)
    # Radio uses the shared header, without a separate left-title OBJ in source.
    bg('gearPhone',root+'match_call/ui.png',root+'match_call/ui.bin',{0:root+'match_call/ui.pal',2:root+'match_call/ui.pal'},128)
    bg('gearRadio',root+'hns/radio/ui_tiles.png',root+'hns/radio/ui_map.bin',{2:root+'hns/radio/ui.pal'})
    sprite('gearRadioDial',root+'hns/radio/dial.png',root+'hns/radio/ui.pal')
    bg('gearCondition',root+'condition/graph.png',root+'condition/graph.bin',{1:root+'condition/graph.pal'})
    sprite('gearConditionBall',root+'condition/pokeball.png',root+'condition/cancel.pal')
    sprite('gearConditionEmpty',root+'condition/pokeball_placeholder.png',root+'condition/cancel.pal')
    for bank in (0,1):sprite('gearConditionCancel'+str(bank),root+'condition/cancel.png',root+'condition/cancel.pal',bank)
    bg('gearRibbons',root+'ribbons/list_bg.png',root+'ribbons/list_bg.bin',{0:root+'ribbons/list_bg.pal',1:root+'ribbons/list_bg.pal'})
    bg('gearRibbonSummary',root+'ribbons/summary_bg.png',root+'ribbons/summary_bg.bin',{1:root+'ribbons/summary_bg.pal'})
    sprite('gearMapCursor',root+'region_map/cursor_small.png',root+'region_map/cursor.pal')
    for gender in ('gold','kris'):
        sprite('gearMap'+gender.title(),root+'region_map/'+gender+'_icon.png')
    for n in range(1,6):sprite('gearRibbonIcons'+str(n),root+'ribbons/icons.png',root+'ribbons/icons'+str(n)+'.pal')
    types=(source/'src/data/types_info.h').read_text()
    for name,block in re.findall(r'\[TYPE_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[TYPE_|\n};)',types,re.S):
        pal=re.search(r'\.palette\s*=\s*(\d+)',block)
        path='graphics/types/'+('fight' if name=='FIGHTING' else name.lower())+'.png'
        if pal and (source/path).exists():sprite('type'+name,path,'graphics/types/move_types_'+str(int(pal[1])-12)+'.pal')
    for name,block in re.findall(r'\[CONTEST_CATEGORY_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[CONTEST_|\n};)',(source/'src/contest.c').read_text(),re.S):
        p=re.search(r'\.palette\s*=\s*(\d+)',block)
        if p:sprite('contest'+name,'graphics/types/contest_'+name.lower()+'.png','graphics/types/move_types_'+str(int(p[1])-12)+'.pal')
    card='graphics/trainer_card/'
    for stars,pal in enumerate(('green','bronze','copper','silver','gold')):
        for female in (False,True):
            # Bank 0/2 are the chosen card palette; bank 1 is the screen backdrop.
            paths={n:card+'hns/'+pal+'.pal' for n in (0,1,2)}
            # Each loaded palette contains three banks. Select source BG banks.
            raw=palette(card+'hns/'+pal+'.pal')
            if female:raw[16:32]=palette(card+'hns/female_bg.pal')[:16]
            for side in ('bg','front','back'):
                src=Image.open(source/(card+'tiles.png'));ts=[src.crop((x,y,x+8,y+8)) for y in range(0,src.height,8) for x in range(0,src.width,8)]
                words=struct.unpack('<600H',(source/(card+side+'.bin')).read_bytes());out=Image.new('RGBA',(240,160))
                for i,w in enumerate(words):
                    t=ts[w&1023]
                    if w&1024:t=t.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    if w&2048:t=t.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                    t=Image.frombytes('RGBA',(8,8),bytes(v for n in t.tobytes() for v in (raw[(w>>12)*16+(n&15)] if n&15 else (0,0,0,0))))
                    out.paste(t,(i%30*8,i//30*8))
                save('card'+side.title()+str(stars)+('Female' if female else 'Male'),out,{'kind':'card','stars':stars,'female':female,'side':side})
    sprite('cardStar',card+'tiles.png',card+'star.pal')
    # Source combined_badges is 16 tiles across: top row Johto, bottom Kanto.
    for label,pal in [('Johto','badges.pal'),('Kanto','frlg/badges.pal')]:sprite('cardBadges'+label,card+'hns/combined_badges.png',card+pal)
    lengths=re.search(r'sConditionToLineLength\[.*?\]\s*=\s*\{(.*?)\};',(source/'src/menu_specialized.c').read_text(),re.S)[1]
    sine=[int(float(v)*256) for v in re.findall(r'Q_8_8\(([-\d.]+)\)',(source/'src/trig.c').read_text())]
    ribbontext=(source/'src/data/text/ribbon_descriptions.h').read_text()
    strings={name:''.join(json.loads('"'+s+'"') for s in re.findall(r'"((?:[^"\\]|\\.)*)"',body)) for name,body in re.findall(r'const u8 (\w+)\[\]\s*=\s*_\((.*?)\);',ribbontext,re.S)}
    descriptions=[[strings[a],strings[b]] for a,b in re.findall(r'=\s*\{(gRibbon\w+),\s*(gRibbon\w+)\}',ribbontext)]
    gfx=(source/'src/pokenav_ribbons_summary.c').read_text()
    block=re.search(r'sRibbonGfxData\[\]\s*=\s*\{(.*?)\};',gfx,re.S)[1]
    tile_names=re.findall(r'^\s*(RIBBONGFX_\w+),',gfx,re.M)
    ribbon_gfx=[{'tile':tile_names.index(a),'palette':int(b)} for a,b in re.findall(r'\{\s*(RIBBONGFX_\w+),\s*TO_PAL_OFFSET\(PALTAG_RIBBON_ICONS_(\d)\)\}',block)]
    colors={name:[list(c) for c in palette(root+path)] for name,path in [('phone','match_call/list_window.pal'),('phoneInfo','match_call/ui.pal'),('radio','hns/radio/ui.pal'),('condition','condition/text.pal'),('graph','condition/graph_data.pal'),('ribbons','ribbons/list_ui.pal')]}
    background=(stage/art['gearCondition']['file']).read_bytes()
    colors['conditionBackdrop']=list(background[(91*240+155)*4:(91*240+155)*4+3])
    return art,{'lineLengths':list(map(int,re.findall(r'\d+',lengths))),'sine':sine,'ribbonDescriptions':descriptions,'ribbonGraphics':ribbon_gfx,'colors':colors}
