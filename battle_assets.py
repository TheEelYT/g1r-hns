"""Exact source battle terrain maps and healthbox tile layouts."""
import collections
import re
import struct
from PIL import Image
from boot_assets import palette,tiles,text_map


def build(source,engine,stage,maps,source_maps):
    root=stage/'battle';root.mkdir();out={'terrains':{},'ui':{},'scenes':{}}
    paths=dict(re.findall(r'(\w+)\[\]\s*=\s*INCBIN_\w+\("([^\"]+)"\)',(source/'src/data/graphics/battle_environment.h').read_text()))
    code=(source/'src/data/battle_environment.h').read_text()
    regular,modern=code.split('static const struct ModernBattleGfx sModernBattleGfx',1)
    def blocks(src):return dict(re.findall(r'\[BATTLE_ENVIRONMENT_(\w+)\]\s*=\s*\{(.*?)\n    \}',src,re.S))
    old,new=blocks(regular),blocks(modern)
    def path(sym,suffix):return source/re.sub(r'\.(?:4bpp|gbapal|bin).*$',suffix,paths[sym])
    def save(name,w,h,data):
        assert len(data)==w*h*4,(name,w,h,len(data));file='battle/'+name+'.rgba';(stage/file).write_bytes(data)
        return {'file':file,'width':w,'height':h}
    def rgba(index,colors,transparent=False):
        out=bytearray()
        for n in index:
            c=colors[n];out.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),0 if transparent and n%16==0 else 255))
        return out
    for env,body in sorted(old.items()):
        m=re.search(r'\.background\s*=\s*ENVIRONMENT_BACKGROUND\((\w+)\)',body)
        p=re.search(r'\.palette\s*=\s*(\w+)',body)
        if not(m and p):continue
        for style in ('old','modern'):
            b=new.get(env,'')if style=='modern'else '';gfx=re.search(r'\.background\s*=\s*MODERN_BACKGROUND\((\w+)\)',b)
            name=gfx[1]if gfx else m[1];basepal=re.search(r'\.palette\s*=\s*(\w+)',b)
            td=tiles(path('gBattleEnvironmentTiles_'+name,'.png'));raw=path('gBattleEnvironmentTilemap_'+name,'.bin').read_bytes();words=list(struct.unpack('<'+str(len(raw)//2)+'H',raw))
            for period in ('Day','Twilight','Night'):
                pal=re.search(r'\.palette'+(period if period!='Day'else '')+r'\s*=\s*(\w+)',b)
                palname=pal[1]if pal else basepal[1]if basepal else p[1]
                colors=palette(path(palname,'.pal'));colors+=[0]*max(0,48-len(colors))
                # Source loads environment palette at BG bank 2.
                local=[(v&4095)|max(0,(v>>12)-2)<<12 for v in words]
                index=text_map(td,local,256,160);key=env+'_'+style+'_'+period
                full=rgba(index,colors);row={'full':save(key,256,160,full),'sourceTiles':str(path('gBattleEnvironmentTiles_'+name,'.png').relative_to(source)),
                    'sourceMap':str(path('gBattleEnvironmentTilemap_'+name,'.bin').relative_to(source)),'sourcePalette':str(path(palname,'.pal').relative_to(source))}
                # Retain platform motion during the native intro. Background
                # uses the dominant wallpaper tile on each source map row.
                wallpaper=bytearray(index);enemy=bytearray(256*160*4);player=bytearray(256*160*4)
                for ty in range(20):
                    freq=collections.Counter(local[ty*32:(ty+1)*32]);bg=min(freq,key=lambda x:(-freq[x],x))
                    for tx in range(32):
                        word=local[ty*32+tx]
                        if word==bg:continue
                        side=enemy if tx>=10 and ty<=10 else player if tx<=16 and ty>=10 else None
                        if side is None:continue
                        for y in range(8):
                            for x in range(8):
                                pos=(ty*8+y)*256+tx*8+x;side[pos*4:pos*4+4]=full[pos*4:pos*4+4]
                                px=7-x if bg&1024 else x;py=7-y if bg&2048 else y
                                wallpaper[pos]=td[bg&1023][py*8+px]+(bg>>12)*16
                row['wallpaper']=save(key+'_wall',256,160,rgba(wallpaper,colors));row['enemy']=save(key+'_enemy',256,160,enemy);row['player']=save(key+'_player',256,160,player)
                out['terrains'][key]=row
    out['scenes']=dict(re.findall(r'\{(MAP_BATTLE_SCENE_\w+),\s*BATTLE_ENVIRONMENT_(\w+)\}',code))
    for mid,m in maps.items():m['hnsBattleScene']=source_maps[m['hnsSourceId']]['battle_scene']
    graphics=(source/'src/graphics.c').read_text()
    for style,rel in [('gen3','hns'),('gen4','gen4')]:
        d=source/'graphics/battle_interface'/rel;ui={};pal=palette(d/'healthbox_singles_player.pal')[:16];hpPal=palette(d/'hpbar.pal')[:16]
        ui['palette']=pal;ui['hpPalette']=hpPal
        for name,w,h in [('healthbox_singles_player',128,64),('healthbox_singles_opponent',128,32),('healthbox_doubles_player',128,32),('healthbox_doubles_opponent',128,32),('healthbox_safari',128,64)]:
            td=tiles(d/(name+'.png'));idx=bytearray(w*h)
            for y in range(h):
                for x in range(w):
                    # Two separate 64px OAM sprites, with the right half's
                    # tile stream after all left-half rows (source callback).
                    tile=(x//64)*(h//8*8)+(y//8)*8+(x%64)//8
                    idx[y*w+x]=td[tile][y%8*8+x%8]&15
            # Source windows erase placeholder letters with their palette BG.
            player='player'in name;bg=3 if style=='gen4'else 2
            for y in range(5,16):
                for x in range(16 if player else 8,96):idx[y*w+x]=bg
            if name=='healthbox_singles_player':
                for y in range(24,32):
                    for x in range(40,96):idx[y*w+x]=bg
            ui[name]=save(style+'_'+name,w,h,rgba(idx,pal,True))
        pattern=r'gHealthboxElementsGfxTableGen'+('4'if style=='gen4'else'3')+r'\[\]\[32\]\s*=\s*INCBIN_U8\((.*?)\);'
        body=re.search(pattern,graphics,re.S)[1];files=re.findall(r'"([^\"]+)"',body);td=[]
        for file in files:td+=tiles(source/re.sub(r'\.4bpp$','.png',file))
        remap=lambda n:n+(9 if n>=101 else 6 if n>=86 else 3 if n>=36 else 0)
        idx=bytearray(320*24)
        for n in range(116):
            tile=td[remap(n)]
            for y in range(8):
                for x in range(8):idx[(n//40*8+y)*320+n%40*8+x]=tile[y*8+x]&15
        ui['elements']=save(style+'_elements',320,24,rgba(idx,hpPal,True));ui['elementsExp']=save(style+'_elementsExp',320,24,rgba(idx,pal,True))
        ui['statusIcons']=[]
        status_colors=[(24,12,24),(23,23,3),(20,20,17),(17,22,28),(28,14,10)]
        for battler,start in enumerate((21,74,92,110)):
            icons=[]
            for status,(r,g,b) in enumerate(status_colors):
                colors=pal.copy();colors[12+battler]=r|(g<<5)|(b<<10);pixels=bytearray(24*8)
                for y in range(8):
                    for x in range(24):pixels[y*24+x]=td[start+status*3+x//8][y*8+x%8]&15
                icons.append(save(f'{style}_status_{battler}_{status}',24,8,rgba(pixels,colors,True)))
            ui['statusIcons'].append(icons)
        ui['ballPrompt']=save(style+'_ballPrompt',32,32,rgba(bytes(v&15 for tile in tiles(d/'last_used_ball_r_cycle.png')[:16]for v in tile),palette(d/'ability_pop_up.pal'),True))
        # Re-layout the R-prompt's OAM tile stream into one 32px frame.
        td=tiles(d/'last_used_ball_r_cycle.png');idx=bytearray(1024)
        for y in range(32):
            for x in range(32):idx[y*32+x]=td[y//8*4+x//8][y%8*8+x%8]&15
        ui['ballPrompt']=save(style+'_ballPrompt',32,32,rgba(idx,palette(d/'ability_pop_up.pal'),True))
        out['ui'][style]=ui
    d=source/'graphics/battle_interface/hns';raw=(d/'textbox_map.bin').read_bytes();words=list(struct.unpack('<'+str(len(raw)//2)+'H',raw));pal=palette(d/'textbox.pal')[:16]*2
    out['textbox']=save('textbox',256,512,text_map(tiles(d/'textbox.png'),words,256,512,pal))
    code=(engine/'src/core/game3/battle/healthbox.lua').read_text().replace('local FrlgFont = require("src.ui.game3.frlg_font")','local FrlgFont') .replace('local Healthbox = {}','local Source\nlocal Healthbox = {}\nfunction Healthbox.configure(s)Source=s;FrlgFont=s.font end')
    a=code.index('local function draw_name_gender');b=code.index('local function draw_level',a);code=code[:a]+'''local function draw_name_gender(name,gender,x,y)Source.name(name,gender,x,y)end

'''+code[b:]
    a=code.index('local function draw_hp_nums');b=code.index('\nend',a)+4;code=code[:a]+'''local function draw_hp_nums(cur,maxHp,boxX,boxY)Source.hp(cur,maxHp,boxX,boxY)end'''+code[b:]
    for func in ('erase_placeholder_ink','erase_hp_window'):
        a=code.index('local function '+func);b=code.index('\nend',a)+4;signature=code[a:code.index('\n',a)];code=code[:a]+signature+'\nend'+code[b:]
    code=code.replace('SummaryChrome.drawStatusIcon(','Source.statusIcon(')
    code=code.replace('function Healthbox.draw(side, battler, opts)','function Healthbox.draw(side, battler, opts)\n  CREAM,HB_TEXT,HB_MALE,HB_FEMALE=Source.textColors()')
    (stage/'hns_healthbox.lua').write_text(code)
    return out
