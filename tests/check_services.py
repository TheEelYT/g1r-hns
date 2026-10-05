"""Independent source-pixel, source-object and C-expression checks for 0.7.0."""
import argparse,collections,json,re,struct,subprocess,tempfile
from pathlib import Path
from PIL import Image

def check(source,engine,mod,luajit):
    w=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')]))
    S=w['services'];count=collections.Counter()
    def palette(path):
        p=source/path
        if p.exists():rgb=[tuple(map(int,line.split()))for line in p.read_text().splitlines()[3:]]
        else:
            im=Image.open(p.with_suffix('.png'));rgb=list(zip(*[iter(im.getpalette())]*3))[:16]
        return [tuple(round(c//8*255/31)for c in row)+(255,)for row in rgb]
    def rgba(a):return Image.frombytes('RGBA',(a['width'],a['height']),(mod/a['file']).read_bytes())
    def indexed(a,path,pal):
        out=rgba(a);raw=Image.open(source/path)
        assert out.size==raw.size
        for y in range(out.height):
            for x in range(out.width):
                i=raw.getpixel((x,y))&15;assert out.getpixel((x,y))==(pal[i]if i else(0,0,0,0)),(path,x,y)
        count['source_sprite_pixels']+=out.width*out.height
    for gender in('male','female'):
        colors=palette('graphics/bag/hns/menu_'+gender+'.pal');out=rgba(S['bag']['images']['bg_'+gender]);tiles=Image.open(source/'graphics/bag/menu.png')
        tm=(source/'graphics/bag/menu_6.bin').read_bytes();words=struct.unpack('<%dH'%(len(tm)//2),tm)
        for y in range(160):
            for x in range(240):
                word=words[y//8*32+x//8];tid=word&1023;dx=x%8;dy=y%8
                if word&1024:dx=7-dx
                if word&2048:dy=7-dy
                v=tiles.getpixel((tid%(tiles.width//8)*8+dx,tid//(tiles.width//8)*8+dy))&15
                assert out.getpixel((x,y))==colors[(word>>12)*16+v],(gender,x,y)
        count['bag_background_pixels']+=240*160
        indexed(S['bag']['images']['bag_'+gender],'graphics/bag/hns/bag_'+gender+'.png',palette('graphics/bag/hns/bag.pal'))
    for gender,name in enumerate(('gold','kris')):indexed(S['arrow'][str(gender)],'graphics/field_effects/pics/arrow.png',palette('graphics/object_events/palettes/'+name+'_hns.pal'))
    indexed(S['bag']['images']['arrows'],'graphics/interface/scroll_indicator.png',palette('graphics/interface/red.pal'))
    indexed(S['bag']['images']['ball'],'graphics/bag/rotating_ball.png',palette('graphics/bag/rotating_ball.pal'))
    body=(source/'src/field_door.c').read_text();paths=dict(re.findall(r'\b(\w+)\[\].*?INCBIN_U8\("([^"]+)"',body))
    for pair,rows in S['doors'].items():
        colors=struct.unpack('<256H',(mod/'native'/pair/'palettes.bin').read_bytes()[8:])
        for key,a in rows.items():
            out=rgba(a);pic=Image.open(source/a['graphic']);width,height=a['w'],a['h'];slots=a['paletteSlots'];tilesPerFrame=width*height//64
            for f in range(3):
                for y in range(height):
                    for x in range(width):
                        tile=(x//16*8+y//16*4+(y%16)//8*2+(x%16)//8)if width==32 else(y//8*2+x//8)
                        src=f*tilesPerFrame+tile;index=pic.getpixel((src%(pic.width//8)*8+x%8,src//(pic.width//8)*8+y%8))&15
                        c=colors[slots[tile%len(slots)]*16+index]
                        expected=(round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255)if index else(0,0,0,255)
                        assert out.getpixel((x,f*height+y))==expected,(pair,key,f,x,y)
            count['door_frames']+=3;count['door_pixels']+=out.width*out.height
    sourceMaps={m['id']:m for p in(source/'data/maps').glob('*/map.json')for m in[json.loads(p.read_text())]}
    names={n:int(i)for n,i in re.findall(r'#define\s+(BERRY_TREE_\w+)\s+(\d+)',(source/'include/constants/berry.h').read_text())}
    found=[]
    for mid,m in w['maps'].items():
        for i,o in enumerate(sourceMaps[m['hnsSourceId']].get('object_events',[]),1):
            if o['graphics_id']!='OBJ_EVENT_GFX_BERRY_TREE'or o['flag']!='0'or not(0<=o['x']<m['width']and 0<=o['y']<m['height']):continue
            n=next(n for n in m['objects']if n['localId']==i)
            assert (n['x'],n['y'],n['elevation'],n['rangeX'],n['rangeY'])==(o['x'],o['y'],o['elevation'],o['movement_range_x'],o['movement_range_y'])
            assert n['berryTreeId']==names[o['trainer_sight_or_berry_tree_id']]
            assert n['hnsMovementType']==o['movement_type']and n['scriptKey']=='HNS_BERRY_INTERACT'
            found.append((mid,i,n['berryTreeId']))
    assert len(found)==35 and len({e[2]for e in found})==33;count['berry_objects']=len(found)
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/item.h"\n#include "config/overworld.h"\n#include "config/battle.h"\n'
    def pp(t):return subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+t,text=True)
    graphics=pp('#include "data/object_events/object_event_graphics.h"\n');paths=dict(re.findall(r'\b(\w+)\[\].*?INCBIN_U\d+\("([^"]+)"',graphics))
    table=pp('#include "data/object_events/berry_tree_graphics_tables.h"\n')
    native={n:int(i)for i,n in re.findall(r'\[(\d+)\]\s*=\s*"ITEM_(\w+)"',(engine/'src/core/game3/constants/emerald/items.lua').read_text())};reverse={i:n for n,i in native.items()}
    for id,r in S['berries'].items():
        name=reverse[r['item']];pics=re.search(r'\[ITEM_'+name+r' - FIRST_BERRY_INDEX\]\s*=\s*(sPicTable_\w+)',table)[1]
        frames=re.findall(r'overworld_frame\((\w+),\s*(\d+),\s*(\d+),\s*(\d+)\)',re.search(pics+r'\[\]\s*=\s*\{(.*?)\};',table,re.S)[1])
        slotname=re.search(r'\[ITEM_'+name+r' - FIRST_BERRY_INDEX\]\s*=\s*(gBerryTreePaletteSlotTable_\w+)',table)[1]
        slots=list(map(int,re.findall(r'\d+',re.search(slotname+r'\[\]\s*=\s*\{([^}]+)',table)[1])))
        stageSlots={f:s for s,fs in enumerate(((0,),(1,2),(3,4),(5,6),(7,8)))for f in fs};out=rgba(r['tree'])
        for f,(g,cw,ch,index)in enumerate(frames):
            pic=Image.open(source/paths[g].replace('.4bpp','.png'));a=r['tree']['frames'][f];fw,fh=int(cw)*8,int(ch)*8;index=int(index)
            colors=palette('graphics/object_events/palettes/'+['npc_white_hns','npc_pink_hns','npc_blue_hns','npc_green_hns'][slots[stageSlots[f]]-2]+'.pal')
            for y in range(fh):
                for x in range(fw):
                    i=pic.getpixel((index%(pic.width//fw)*fw+x,index//(pic.width//fw)*fh+y))&15
                    assert out.getpixel((x,a['y']+y))==(colors[i]if i else(0,0,0,0)),(name,f,x,y)
            count['berry_pixels']+=fw*fh
    # GCC independently evaluates the source config expressions, including
    # the nested growth-duration ternaries handled by the converter.
    raw=(source/'src/berry.c').read_text();data=pp(raw[raw.index('#define GROWTH_DURATION'):raw.index('const struct BerryCrushBerryData')])
    entries=dict(re.findall(r'\[ITEM_(\w+) - FIRST_BERRY_INDEX\]\s*=\s*\{(.*?)(?=\n\s*\[ITEM_|\n};)',data,re.S));code=['#include <stdio.h>\nint main(void){']
    ids=sorted(S['berries'],key=int)
    for id in ids:
        b=entries[reverse[S['berries'][id]['item']]];expr=[re.search(r'\.'+f+r'\s*=\s*([^,]+)',b)[1]for f in('growthDuration','minYield','maxYield')]
        code.append('printf("%d %d %d\\n",'+','.join('('+e+')'for e in expr)+');')
    code.append('return 0;}')
    with tempfile.TemporaryDirectory()as td:
        c=Path(td)/'oracle.c';exe=Path(td)/'oracle';c.write_text('\n'.join(code));subprocess.check_call(['gcc',str(c),'-o',str(exe)])
        for id,line in zip(ids,subprocess.check_output([str(exe)],text=True).splitlines()):
            r=S['berries'][id];assert list(map(int,line.split()))==[r['stageDuration'],r['minYield'],r['maxYield']]
    count['c_berry_stat_rows']=len(ids)
    assert S['bag']['pockets']==['ITEMS','MEDICINE','POKE_BALLS','TM_CASE','BERRY_POUCH','KEY_ITEMS']
    return {'result':'pass','counts':dict(count)}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for k in('source','engine','mod','luajit'):p.add_argument('--'+k,type=Path,required=True)
    p.add_argument('--report',type=Path);a=p.parse_args();r=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps(r))
