"""Independent source checks for settings, opening art and Pokégear maps."""
import argparse
import json
import re
import struct
import subprocess
from pathlib import Path
from PIL import Image


def palette(path):
    return [tuple(round((int(v) // 8) * 255 / 31) for v in row.split())
            for row in path.read_text().splitlines()[3:]]


def image_palette(path):
    rgb=Image.open(path).getpalette()
    return [tuple(round((rgb[i+j] // 8) * 255 / 31) for j in range(3))
            for i in range(0,len(rgb),3)]


def check(source,engine,mod,luajit):
    w=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')],text=True))
    q=w['startup'];counts={}
    rows=0
    for filename,kind in [('challenge_menu.c','challenge'),('option_menu.c','option')]:
        c=(source/'src'/filename).read_text()
        pages=[p for p in q['settings']['pages'] if p['kind']==kind]
        arrays=re.findall(r'static const struct (?:Challenge|Option)MenuItem sTabItems_(\w+)\[\]\s*=\s*\{(.*?)\n\};',c,re.S)
        assert [p['id'] for p in pages]==[name.upper() for name,_ in arrays]
        for p,(_,body) in zip(pages,arrays):
            ids=re.findall(r'^    \[(ITEM_\w+)\] =',body,re.M)
            assert [r['id'] for r in p['rows']]==ids,(filename,p['id'])
            for r in p['rows']:
                match=re.search(r'\['+r['id']+r'\]\s*=\s*\{\s*\.name\s*=\s*COMPOUND_STRING\("((?:\\.|[^"\\])*)"\)',body)
                assert r['name']==json.loads('"'+match[1]+'"').replace('{PKMN}','POKéMON')
                assert r['var']==0x7100+rows
                assert not r['choices'] or 0<=r['default']<len(r['choices'])
                policy=dict(re.findall(r'\[TAB_\w+\s*\*\s*MAX_ITEMS_PER_TAB\s*\+\s*(\w+)\]\s*=\s*LOCK_(\w+)',c))
                assert r['lock']==policy.get(r['id'],'FREE')
                rows+=1
    counts['source_settings_pages']=len(q['settings']['pages']);counts['source_settings_rows']=rows
    assert (len(q['settings']['pages']),rows)==(9,88)
    assert q['oakSong']=='MUS_HG_NEW_GAME'
    bed=json.loads((source/'data/maps/NewBarkTown_PlayersHouse_2F_hns/map.json').read_text())['warp_events'][1]
    assert (q['start']['x'],q['start']['y'])==(bed['x'],bed['y'])==(1,6)
    art=[('graphics/oak_speech_hns/oak_hns.png',q['portraits']['oak']),
         ('graphics/trainers/back_pics/gold_hns.png',q['battleBacks']['0']),
         ('graphics/trainers/back_pics/kris_hns.png',q['battleBacks']['1'])]
    count=0
    for path,info in art:
        p=source/path;im=Image.open(p);pal=palette(p.with_suffix('.pal')) if p.with_suffix('.pal').exists() else image_palette(p)
        expected=bytes(v for index in im.tobytes() for v in (*pal[index],255 if index else 0))
        assert (info['width'],info['height'])==im.size
        assert (mod/info['file']).read_bytes()==expected,path
        count+=im.width*im.height
    counts['source_portrait_back_pixels']=count
    # Decode the source GBA tilemap directly at each pixel, including flip bits.
    root=source/'graphics/oak_speech_hns';atlas=Image.open(root/'shadow_hns.png');cells=struct.unpack('<640H',(root/'map_hns.bin').read_bytes())
    base=palette(root/'bg0_hns.pal')+palette(root/'bg1_hns.pal');grad=palette(root/'bg2_hns.pal')
    for state in range(9):
        colors=base[:];colors[1:9]=grad[state:state+8];info=q['backdrops'][str(state)];raw=(mod/info['file']).read_bytes()
        assert len(raw)==256*160*4
        for y in range(160):
            for x in range(256):
                cell=cells[(y//8)*32+x//8];tile=cell&1023
                dx=7-x%8 if cell&1024 else x%8;dy=7-y%8 if cell&2048 else y%8
                index=atlas.getpixel(((tile%(atlas.width//8))*8+dx,(tile//(atlas.width//8))*8+dy))+(cell>>12)*16
                offset=(y*256+x)*4
                assert raw[offset:offset+4]==bytes((*colors[index],255))
    counts['source_backdrop_pixels']=9*256*160
    popup=(source/'src/map_name_popup.c').read_text()
    themed=popup.split('#if IS_HNS\nstatic const u8 sMapSectionToThemeId')[1].split('#else')[0]
    themes=dict(re.findall(r'\[(MAPSEC_\w+)\]\s*=\s*(MAPPOPUP_THEME_\w+)',themed))
    srcmaps={m['id']:m for p in (source/'data/maps').glob('*/map.json') for m in [json.loads(p.read_text())]}
    for m in w['maps'].values():
        sec=srcmaps[m['hnsSourceId']]['region_map_section']
        theme='hns_'+themes.get(sec,'MAPPOPUP_THEME_WOOD').removeprefix('MAPPOPUP_THEME_').lower()
        assert q['areaThemes'][str(m['regionMapSectionId'])]==theme
    for table,suffix in [('Table',''),('OutlineTable','_outline')]:
        block=popup.split('sMapPopUp_'+table)[1].split('\n};')[0]
        paths=dict(re.findall(r'\[(MAPPOPUP_THEME_\w+)\]\s*=\s*INCBIN_U\d+\("([^"]+)"\)',block))
        for name in q['popupPalettes']:
            theme='MAPPOPUP_THEME_'+name.removeprefix('hns_').upper()
            png=source/paths[theme].replace('.4bpp','.png')
            assert (mod/q['popupFiles']['chrome/map_popup/'+name+suffix+'.idx']).read_bytes()==Image.open(png).tobytes()
    counts['source_banner_themes']=len(q['popupPalettes'])
    for name,info in q['gearMaps'].items():
        root=source/'graphics/pokenav/region_map';atlas=Image.open(root/f'map_{name}.png');cells=(root/f'map_{name}.bin').read_bytes()
        colors=[(0,0,0)]*112+palette(root/f'map_{name}.pal');raw=(mod/info['file']).read_bytes()
        assert len(cells)==64*64 and len(raw)==240*160*4
        for y in range(160):
            for x in range(240):
                tile=cells[(y//8)*64+x//8]
                index=atlas.getpixel(((tile%(atlas.width//8))*8+x%8,(tile//(atlas.width//8))*8+y%8))
                offset=(y*240+x)*4
                assert raw[offset:offset+4]==bytes((*colors[index],255)),(name,x,y,index)
    counts['source_gear_map_pixels']=2*240*160
    for sec in ('MAPSEC_NEW_BARK_TOWN','MAPSEC_PALLET_TOWN'):
        assert q['sectionRegions'][sec]==('johto' if 'NEW_BARK' in sec else 'kanto')
    source_sections=json.loads((source/'src/data/region_map/region_map_sections.json').read_text())
    expected={r['id']:r for r in source_sections['map_sections']}
    expected.update({r['id']:r for r in source_sections['hns_map_sections']})
    expected={k:r for k,r in expected.items() if all(t in r for t in ('x','y','width','height'))}
    assert {r['id']:r for r in q['sections']}==expected
    counts['source_map_sections']=len(expected)
    # Source bitmap masks retain foreground/shadow indices and char advances.
    fonts=(source/'src/fonts.c').read_text();pixels=0
    for name,info in q['ui']['fonts'].items():
        im=Image.open(source/f'graphics/fonts/latin_{name}.png')
        values=re.search(r'gFont'+''.join(v.title()for v in name.split('_'))+r'LatinGlyphWidths\[\]\s*=\s*\{(.*?)\};',fonts,re.S)[1]
        assert info['widths']==list(map(int,re.findall(r'\d+',values)))
        for layer,index in [('fg',1),('shadow',2)]:
            data=(mod/info[layer]).read_bytes()
            assert data==bytes(v for p in im.tobytes() for v in (255,255,255,255 if p==index else 0))
        pixels+=im.width*im.height
    counts['source_font_pixels']=pixels
    keypad=Image.open(source/'graphics/fonts/keypad_icons.png');pal=image_palette(source/'graphics/fonts/keypad_icons.png');buttons=0
    for name,first,width in [('A_BUTTON',0,8),('B_BUTTON',1,8),('L_BUTTON',2,16),('R_BUTTON',4,16),('START_BUTTON',6,24),('SELECT_BUTTON',9,24),('DPAD_UPDOWN',32,8)]:
        row=q['ui']['art'][name];data=(mod/row['file']).read_bytes();assert (row['width'],row['height'])==(width,16)
        for y in range(16):
            for x in range(width):
                tile=first+y//8*16+x//8;i=keypad.getpixel((tile%(keypad.width//8)*8+x%8,tile//(keypad.width//8)*8+y%8));off=(y*width+x)*4
                assert tuple(data[off:off+4])==(*pal[i],255)if i else tuple(data[off:off+4])==(0,0,0,0)
                buttons+=1
    counts['source_keypad_pixels']=buttons
    for name,path in [('frame','graphics/text_window/1.png'),('callFrame','graphics/pokenav/hns/match_call/window.png'),('callIcon','graphics/pokenav/hns/match_call/nav_icon.png'),('callName','graphics/pokenav/name_box.png'),('question','graphics/field_effects/pics/emotion_question.png'),('exclamation','graphics/field_effects/pics/emotion_exclamation.png')]:
        im=Image.open(source/path);pal=image_palette(source/'graphics/pokenav/hns/match_call/window.png') if name=='callName' else image_palette(source/path)
        assert (mod/q['ui']['art'][name]['file']).read_bytes()==bytes(v for p in im.tobytes() for v in (*pal[p],255 if p else 0)),name
    assert q['speech']['gText_ThisIsAPokemon']=='This is what we call a “POKéMON.”{PAUSE 96}\\p'
    assert q['speech']['gText_HnsChallengeWarning'].endswith('easier, not harder.')
    counts['source_field_ui_art']=6
    for name in ('chikorita','cyndaquil','totodile'):
        im=Image.open(source/f'graphics/pokemon/{name}/anim_front.png').crop((0,0,64,64));pal=palette(source/f'graphics/pokemon/{name}/normal.pal')
        assert (mod/q['ui']['art'][name]['file']).read_bytes()==bytes(v for p in im.tobytes() for v in (*pal[p],255 if p else 0))
    counts['source_starter_preview_pixels']=3*64*64
    menu_pixels=0
    # Pixel-by-pixel GBA BG decoding, independent of the converter's tile paste.
    art=q['ui']['art'];base=source/'graphics/pokenav'
    for name,graphic,tilemap in [('gearDots','hns/bg_dots.png','hns/bg_dots.bin'),('gearDevice','hns/device_outline.png','hns/device_outline_map.bin'),('gearHeader','hns/header.png','hns/header.bin'),('gearMessage','hns/message.png','message.bin')]:
        atlas=Image.open(base/graphic);p=(base/graphic).with_suffix('.pal')
        pal=palette(p) if p.exists() else image_palette(base/graphic)
        raw=(base/tilemap).read_bytes();words=struct.unpack('<%dH'%(len(raw)//2),raw)
        im=Image.frombytes('RGBA',(256,256),(mod/art[name]['file']).read_bytes())
        for y in range(160):
            for x in range(240):
                cell=words[y//8*32+x//8];tile=cell&1023;dx=x%8;dy=y%8
                if cell&1024:dx=7-dx
                if cell&2048:dy=7-dy
                index=atlas.getpixel((tile%(atlas.width//8)*8+dx,tile//(atlas.width//8)*8+dy))
                assert im.getpixel((x,y))==(*pal[index],255 if index else 0),(name,x,y)
        menu_pixels+=240*160
    pal=palette(base/'hns/options/options.pal')
    for name,path,bank in [('MAP','hns/options/hoenn_map.png',0),('PHONE','hns/options/match_call.png',4),('RADIO','hns/options/radio.png',0),('CONDITION','options/condition.png',1),('RIBBONS','options/ribbons.png',2),('SWITCHOFF','options/switch_off.png',3)]:
        src=Image.open(base/path);im=Image.frombytes('RGBA',(128,16),(mod/art['gearButton'+name]['file']).read_bytes())
        for y in range(16):
            for x in range(128):
                index=src.getpixel((x%32,y+x//32*16));assert im.getpixel((x,y))==(*pal[bank*16+index],255 if index else 0),(name,x,y)
        menu_pixels+=128*16
    for name,path,palpath in [('moveHint','graphics/battle_interface/move_info_window_start.png','graphics/battle_interface/hns/ability_pop_up.pal'),('moveCategory','graphics/interface/category_icons.png','graphics/interface/category_icons.pal')]:
        src=Image.open(source/path);p=source/palpath;pal=palette(p) if p.exists() else image_palette(source/path)
        assert (mod/art[name]['file']).read_bytes()==bytes(v for index in src.tobytes() for v in (*pal[index],255 if index else 0)),name
        menu_pixels+=src.width*src.height
    counts['source_gear_battle_ui_pixels']=menu_pixels
    return {'result':'pass','counts':counts}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','engine','mod','luajit'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--report',type=Path)
    a=p.parse_args();result=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
