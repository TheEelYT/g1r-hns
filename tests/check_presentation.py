"""Independent pixel and source-C timing checks for HnS presentation."""
import argparse
import collections
import json
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))

def pal(path):
    if path.exists():values=[tuple(map(int,r.split())) for r in path.read_text().splitlines()[3:]]
    else:
        raw=Image.open(path.with_suffix('.png')).getpalette();values=[tuple(raw[i:i+3])for i in range(0,len(raw),3)]
    return [tuple(round((v//8)*255/31)for v in row)+(255,)for row in values]

def check(source,engine,mod,luajit):
    w=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')]))
    art=w['startup']['ui']['art'];counts=collections.Counter()
    # Decode Dex backgrounds and tile-linear OBJ labels independently of the
    # converter's render routine. Transparent BG tiles retain the underlay.
    dex=w['pokedex'];base=source/'graphics/pokedex/hgss';colors=pal(base/'palette_default.pal')
    for name,tiles,maps in [('list','tileset_menu_list.png',['tilemap_list_screen_underlay.bin','tilemap_list_screen.bin']),('info','tileset_menu1.png',['tilemap_info_screen.bin']),('stats','tileset_menu1.png',['tilemap_stats_screen.bin']),('evo','tileset_menu2.png',['tilemap_evo_screen_PE.bin']),('cry','tileset_menu3.png',['tilemap_cry_screen.bin']),('size','tileset_menu3.png',['tilemap_size_screen.bin'])]:
        tiles=Image.open(base/tiles);out=Image.frombytes('RGBA',(240,160),(mod/dex['backgrounds'][name]).read_bytes())
        words=[struct.unpack('<%dH'%((base/f).stat().st_size//2),(base/f).read_bytes())for f in maps]
        for y in range(160):
            for x in range(240):
                expected=colors[1]
                for layer in words:
                    v=layer[y//8*32+x//8];tid=v&1023;dx=x%8;dy=y%8
                    if v&1024:dx=7-dx
                    if v&2048:dy=7-dy
                    n=tiles.getpixel((tid%(tiles.width//8)*8+dx,tid//(tiles.width//8)*8+dy))&15
                    if n:expected=colors[(v>>12)*16+n]
                assert out.getpixel((x,y))==expected,(name,x,y)
                counts['dex_background_pixels']+=1
    # Keep the list foreground separate so it masks scrolling text/portraits.
    tiles=Image.open(base/'tileset_menu_list.png')
    for name,path,transparent in [('listUnderlay','tilemap_list_screen_underlay.bin',False),('listOverlay','tilemap_list_screen.bin',True)]:
        words=struct.unpack('<%dH'%((base/path).stat().st_size//2),(base/path).read_bytes())
        out=Image.frombytes('RGBA',(240,160),(mod/dex['backgrounds'][name]).read_bytes())
        for y in range(160):
            for x in range(240):
                word=words[y//8*32+x//8];dx=x%8;dy=y%8
                if word&1024:dx=7-dx
                if word&2048:dy=7-dy
                tid=word&1023;n=tiles.getpixel((tid%(tiles.width//8)*8+dx,tid//(tiles.width//8)*8+dy))&15
                expected=colors[(word>>12)*16+n]if n else(0,0,0,0)if transparent else colors[1]
                assert out.getpixel((x,y))==expected,(name,x,y)
                counts['dex_list_layer_pixels']+=1
    sheet=Image.open(base/'tileset_interface_hns.png')
    for name,tid in [('scrollBall',16),('scrollArrow',1),('scrollBar',3),('johto',160),('national',168),('seen',64),('owned',96)]+[('digit'+str(i),176+i*2)for i in range(10)]:
        a=dex['art'][name];out=Image.frombytes('RGBA',(a['width'],a['height']),(mod/a['file']).read_bytes())
        for y in range(out.height):
            for x in range(out.width):
                tile=tid+y//8*(out.width//8)+x//8
                n=sheet.getpixel((tile%(sheet.width//8)*8+x%8,tile//(sheet.width//8)*8+y%8))&15
                assert out.getpixel((x,y))==(colors[n]if n else (0,0,0,0)),(name,x,y)
                counts['dex_obj_pixels']+=1
    # Decode each destination pixel directly from source tilemap and tile sheet.
    for name,a in art.items():
        if not a.get('source'):continue
        p=a['source'];out=Image.frombytes('RGBA',(a['width'],a['height']),(mod/a['file']).read_bytes())
        if p['kind']=='card':
            stem='graphics/trainer_card/';graphic=source/(stem+'tiles.png');tilemap=source/(stem+p['side']+'.bin')
            colors=pal(source/(stem+'hns/'+['green','bronze','copper','silver','gold'][p['stars']]+'.pal'))
            if p['female']:colors[16:32]=pal(source/(stem+'hns/female_bg.pal'))
            banks={n:colors[n*16:n*16+16]for n in (0,1,2)};cols=30;offset=0
        elif p['kind']=='background':
            graphic=source/p['graphic'];tilemap=source/p['tilemap'];ps=p['palettes'];items=enumerate(ps,1)if isinstance(ps,list)else ps.items()
            banks={int(n):pal(source/f)for n,f in items};cols=p['columns'];offset=p['offset']
        else:
            src=Image.open(source/p['graphic']);colors=pal(source/(p.get('palette') or p['graphic'].replace('.png','.pal')))[p['bank']*16:p['bank']*16+16]
            for y in range(out.height):
                for x in range(out.width):
                    sx,sy=(x%64,y+x//64*32) if p['header']else (x,y)
                    raw=src.getpixel((sx,sy));n=raw&15 if src.mode=='P'else 15-(raw>>4)
                    expected=colors[n]if n else (0,0,0,0)
                    assert out.getpixel((x,y))==expected,(name,x,y)
                    counts['source_screen_pixels']+=1
            continue
        src=Image.open(graphic);words=struct.unpack('<%dH'%(tilemap.stat().st_size//2),tilemap.read_bytes())
        for y in range(160):
            for x in range(240):
                v=words[y//8*cols+x//8];tile=(v&1023)-offset;dx=x%8;dy=y%8
                if v&1024:dx=7-dx
                if v&2048:dy=7-dy
                n=src.getpixel((tile%(src.width//8)*8+dx,tile//(src.width//8)*8+dy))&15
                assert out.getpixel((x,y))==(banks[v>>12][n]if n else (0,0,0,0)),(name,x,y)
                counts['source_screen_pixels']+=1
    # Source-selected GBA pictures and footprints, independent of runtime font/UI.
    assert len(w['pokedex']['registrationEntries'])==386
    for r in w['pokedex']['registrationEntries']:
        assert all(k in r for k in ('height','weight','category','description','footprint','front'))
        f=r['front'];im=Image.open(source/f['graphic'].replace('.4bpp.smol','.png')).crop((0,0,64,64));colors=pal(source/f['palette'].replace('.gbapal','.pal'))
        expected=bytes(v for n in im.tobytes()for v in (colors[n&15]if n&15 else (0,0,0,0)))
        assert (mod/f['file']).read_bytes()==expected,r['speciesName']
        counts['registration_portrait_pixels']+=4096
        f=r['footprint'];im=Image.open(source/f['graphic'])
        expected=bytes(v for n in im.tobytes()for v in ((0,0,0,255)if n&1 else (0,0,0,0)))
        assert (mod/f['file']).read_bytes()==expected,r['speciesName']+' footprint'
        counts['registration_footprint_pixels']+=im.width*im.height
        icon=r['icon'];im=Image.open(source/icon['graphic']);colors=pal(source/icon['palette'])
        expected=bytes(v for n in im.tobytes()for v in (colors[n&15]if n&15 else (0,0,0,0)))
        assert (mod/icon['file']).read_bytes()==expected,r['speciesName']+' icon'
        assert im.size==(32,64)
        counts['stats_icon_pixels']+=im.width*im.height
    for name,a in dex['art'].items():
        if not a.get('graphic') or not a.get('palette'):continue
        im=Image.open(source/a['graphic'].replace('.4bpp.smol','.png'));im=im.crop((0,0,a['width'],a['height']))
        colors=pal(source/a['palette'].replace('.gbapal','.pal'))
        expected=bytes(v for n in im.tobytes()for v in (colors[n&15]if n&15 else (0,0,0,0)))
        assert (mod/a['file']).read_bytes()==expected,name
        counts['move_item_and_unknown_pixels']+=im.width*im.height
    for name,a in art.items():
        m=re.fullmatch(r'(gearButton.+)Glow([1-8])',name)
        if not m:continue
        original=art[m[1]];rgba=(mod/original['file']).read_bytes();out=(mod/a['file']).read_bytes();coefficient=int(m[2])
        expected=bytes(v if i%4==3 else round((round(v*31/255)+(31-round(v*31/255))*coefficient//16)*255/31)for i,v in enumerate(rgba))
        assert out==expected,name
        counts['gear_glow_pixels']+=len(rgba)//4
    # Execute pinned C callbacks as an oracle for every bank and source offset.
    import tile_animation
    with tempfile.TemporaryDirectory()as tmp:
        exe,frames=tile_animation.compile_callbacks(source,Path(tmp))
        for key,p in w['pairs'].items():
            if not p.get('animationFiles'):continue
            man=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'native'/key/'anim_manifest.lua')]))
            # Primary tile-count choice is part of the original stable pair hash.
            from hashlib import sha256
            n=next(n for n in (512,640)if 'hns_'+sha256((p['primary']+'|'+p['secondary']+'|'+str(n)).encode()).hexdigest()[:16]==key)
            trace=subprocess.check_output([str(exe),*p['animations'],str(n)],text=True).splitlines()
            pm,sm,_,_=map(int,trace[0].split()[1:]);assert man['counters']['primary']['max']==pm and man['counters']['secondary']['max']==sm
            grouped=collections.defaultdict(list)
            for line in trace[1:]:
                kind,ch,t,f,off,dest,size=line.split();grouped[kind,int(ch),int(dest),int(size)].append((int(t),int(f),int(off)))
            for row in man['banks']:
                kind='P'if row.get('kind')=='palette'else'F';ch=1 if row['counter']=='secondary'else 0
                events=grouped[kind,ch,row['sourceDestination'],row['sourceSize']]
                expected=[None]*(sm if ch else pm)
                for t,f,off in events:expected[t]=(list(frames[f][1]),off)
                for t,index in enumerate(row['timeline']):
                    if index<0:assert expected[t]is None
                    else:assert (row['sourceFrames'][index]['paths'],row['sourceFrames'][index]['offset'])==expected[t],(key,t)
                for field,mids in [('file','mids'),('overFile','overMids'),('middleFile','middleMids')]:
                    if field in row and mids in row:assert (mod/'native'/key/row[field]).stat().st_size==row['frames']*len(row[mids])*256
                counts['callback_events']+=len(events);counts['callback_banks']+=1
            counts['animated_pairs']+=1
    assert counts['callback_banks']==w['animations']['banks']
    assert counts['animated_pairs']==w['animations']['animated_pairs']
    return {'result':'pass','counts':dict(counts)}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','engine','mod','luajit'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--report',type=Path);a=p.parse_args()
    r=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps(r))
