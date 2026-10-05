"""HnS regional order, source entries and HGSS Plus background conversion."""
import json
import re
import struct
import subprocess
import dex_moves
from PIL import Image

def build(source,stage,known):
    header=(source/'include/constants/pokedex.h').read_text()
    part=header[header.index('    JOHTO_DEX_NONE,'):header.index('#define JOHTO_DEX_COUNT')]
    names=re.findall(r'JOHTO_DEX_(\w+),',part)[1:]
    assert len(names)==282 and names[:9]==['CHIKORITA','BAYLEEF','MEGANIUM','CYNDAQUIL','QUILAVA','TYPHLOSION','TOTODILE','CROCONAW','FERALIGATR']
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "metaprogram.h"\n#undef COMPOUND_STRING\n#undef COMPOUND_STRING_SIZE_LIMIT\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/battle.h"\n#include "config/pokemon.h"\n#include "constants/pokemon.h"\n#include "config/species_enabled.h"\n#include "config/pokedex_plus_hgss.h"\n'
    def preprocess(path):
        return subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "'+path+'"\n',text=True)
    infos=preprocess('data/pokemon/species_info.h')
    graphics=preprocess('data/graphics/pokemon.h')
    # Stats A-toggle switches from battle data to source contest information.
    def contest_pp(path):
        return subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "config/contest.h"\n#include "constants/contest.h"\n#include "'+path+'"\n',text=True)
    contest_effects={}
    for name,b in re.findall(r'\[(\d+)\]\s*=\s*\{(.*?)(?=\n\s*\[\d+\]|\n};)',contest_pp('data/contest_moves.h'),re.S):
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',b,re.S)
        if desc:contest_effects[name]={'description':''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',desc[1])),'appeal':int(re.search(r'\.appeal\s*=\s*(\d+)',b)[1])//10,'jam':int(re.search(r'\.jam\s*=\s*(\d+)',b)[1])//10}
    def symbol(expr):
        expr=expr.strip()
        if '?' not in expr:return expr
        m=re.fullmatch(r'\(*\s*(\d+)\s*\)*\s*>=\s*\(*\s*(\d+)\s*\)*\s*\?\s*(\w+)\s*:\s*(\w+)',expr)
        assert m,expr
        return m[3]if int(m[1])>=int(m[2])else m[4]
    contest_moves={}
    for name,b in re.findall(r'\[MOVE_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[MOVE_|\n};)',contest_pp('data/moves_info.h'),re.S):
        e=re.search(r'\.contestEffect\s*=\s*([^,]+)',b);c=re.search(r'\.contestCategory\s*=\s*([^,]+)',b)
        if e and c and name!='NONE':
            name={'VISE_GRIP':'VICE_GRIP','HIGH_JUMP_KICK':'HI_JUMP_KICK','FEINT_ATTACK':'FAINT_ATTACK','SMELLING_SALTS':'SMELLING_SALT'}.get(name,name)
            contest_moves[name]={**contest_effects[symbol(e[1])],'category':symbol(c[1]).removeprefix('CONTEST_CATEGORY_')}
    abilities={}
    for name,b in re.findall(r'\[ABILITY_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[ABILITY_|\Z)',preprocess('data/abilities.h'),re.S):
        n=re.search(r'\.name\s*=\s*_\("([^"]+)"\)',b);d=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',b,re.S)
        if n and d:abilities[name]={'name':n[1],'description':''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',d[1]))}
    learnsets={}
    modern_generation=int(re.search(r'#define\s+P_LVL_UP_LEARNSETS\s+GEN_(\d+)',(source/'include/config/pokemon.h').read_text())[1])
    for gen in (3,modern_generation):
        pp=preprocess('data/pokemon/level_up_learnsets/gen_'+str(gen)+'.h')
        learnsets[str(gen)]={name:[{'level':int(level),'move':move}for move,level in re.findall(r'\.move\s*=\s*MOVE_(\w+)\s*,\s*\.level\s*=\s*(\d+)',b)]for name,b in re.findall(r'static const struct LevelUpMove (\w+)\[\]\s*=\s*\{(.*?)\n};',pp,re.S)}
    teachables,eggsets,legacy_refs,machine_labels=dex_moves.build(source,preprocess,modern_generation)
    move_aliases=dex_moves.aliases(source)
    for arrays in learnsets.values():
        for rows in arrays.values():
            for row in rows:row['move']=move_aliases.get(row['move'],row['move'])
    display_moves=dex_moves.move_info(contest_pp('data/moves_info.h'))
    aliases={'CASTFORM':'CASTFORM_NORMAL','DEOXYS':'DEOXYS_NORMAL'}
    named={name:body for name,body in re.findall(r'const u8 (\w+)\[\]\s*=\s*_\((.*?)\);',infos,re.S)}
    def quoted(body):return ''.join(json.loads('"'+v+'"') for v in re.findall(r'"((?:[^"\\]|\\.)*)"',body))
    egg_names={n:json.loads('"'+s+'"')for n,s in re.findall(r'sText_Stats_eggGroup_(\w+)\[\]\s*=\s*_\("([^"]+)"\)',(source/'src/pokedex_plus_hgss.c').read_text())}
    egg_ids={int(i):n for n,i in re.findall(r'#define\s+EGG_GROUP_(\w+)\s+(\d+)',(source/'include/constants/pokemon.h').read_text())}
    def entry(name,i,assets=True):
        row={'number':i,'speciesName':name,'name':name.replace('_','-'),'supported':name in known}
        match=re.search(r'\[SPECIES_'+aliases.get(name,name)+r'\]\s*=\s*\{(.*?)(?=\n\s*\[SPECIES_|\n\s*};|\Z)',infos,re.S)
        if match:
            b=match[1]
            for field in ('height','weight'):
                m=re.search(r'\.'+field+r'\s*=\s*(\d+)',b)
                if m:row[field]=int(m[1])
            row['stats']={}
            for field,key in [('baseHP','hp'),('baseAttack','atk'),('baseDefense','def'),('baseSpeed','spe'),('baseSpAttack','spa'),('baseSpDefense','spd'),('catchRate','catchRate'),('expYield','expYield'),('friendship','friendship'),('eggCycles','eggCycles')]:
                m=re.search(r'\.'+field+r'\s*=\s*([^,]+)',b)
                if m:
                    value=m[1].strip()
                    ternary=re.fullmatch(r'\(*\s*(\d+)\s*>=\s*(\d+)\s*\)*\s*\?\s*(\d+)\s*:\s*(\d+)\)*',value)
                    if ternary:value=ternary[3]if int(ternary[1])>=int(ternary[2])else ternary[4]
                    if value.isdigit():row['stats'][key]=int(value)
            for field in ('dexNotRequired','isMythical','dexForceRequired'):
                m=re.search(r'\.'+field+r'\s*=\s*([01])',b)
                row[field]=bool(m and m[1]=='1')
            m=re.search(r'\.growthRate\s*=\s*GROWTH_(\w+)',b)
            if m:row['growthRate']=m[1].replace('_',' ').title()
            m=re.search(r'\.eggGroups\s*=\s*\{([^}]+)',b)
            if m:
                row['eggGroups']=[egg_names.get(egg_ids.get(int(n)),'???')for n in re.findall(r'\d+',m[1])]
                assert len(row['eggGroups'])==2,(name,m[1])
            m=re.search(r'\.abilities\s*=\s*\{([^}]+)',b)
            if m:row['abilityNames']=re.findall(r'ABILITY_(\w+)',m[1])
            m=re.search(r'\.levelUpLearnset\s*=\s*(\w+)',b)
            if m:row['learnsetRef']=m[1]
            for field,key in [('teachableLearnset','teachableRef'),('eggMoveLearnset','eggRef')]:
                m=re.search(r'\.'+field+r'\s*=\s*(\w+)',b)
                if m:row[key]=m[1]
            row['legacyLearnsetRef']=legacy_refs['level'].get(aliases.get(name,name),row.get('learnsetRef'))
            row['legacyEggRef']=legacy_refs['egg'].get(aliases.get(name,name),row.get('eggRef'))
            row['evYield']={}
            for field,key in [('HP','hp'),('Attack','atk'),('Defense','def'),('Speed','spe'),('SpAttack','spa'),('SpDefense','spd')]:
                m=re.search(r'\.evYield_'+field+r'\s*=\s*(\d+)',b)
                row['evYield'][key]=int(m[1])if m else 0
            m=re.search(r'\.genderRatio\s*=\s*([^\n]+)',b)
            if m:
                value=m[1].strip().rstrip(',');row['genderRatio']=value
                pct=re.search(r'\(\(([.\d]+)\s*\*\s*255',value)
                if pct:row['femalePercent']=float(pct[1])
                elif value=='0':row['femalePercent']=0
                elif value=='254':row['femalePercent']=100
            m=re.search(r'\.eggGroups\s*=\s*\{([^}]+)',b)
            row['noEggs']=bool(m and any(egg_ids.get(int(n))=='NO_EGGS_DISCOVERED'for n in re.findall(r'\d+',m[1])))
            m=re.search(r'\.categoryName\s*=\s*_\("([^"\n]*)"\)',b)
            if m:row['category']=m[1].upper()
            m=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',b,re.S)
            if not m:
                ref=re.search(r'\.description\s*=\s*(\w+)',b)
                body=named.get(ref[1]) if ref else None
            else:body=m[1]
            if body:
                original=quoted(body)
                row['description']=original.replace('\n',' ')
                row['descriptionLines']=original
            m=re.search(r'(?:\.footprint\s*=\s*gMonFootprint_|FOOTPRINT\()(\w+)',b)
            if m and assets:
                ref=re.search(r'gMonFootprint_'+m[1]+r'\[\].*?INCBIN_U8\(\s*"([^"]+)"\)',graphics)
                if ref:
                    path=source/ref[1].replace('.1bpp','.png')
                    if path.exists():
                        im=Image.open(path);raw=bytes(v for n in im.tobytes() for v in ((0,0,0,255) if n&1 else (0,0,0,0)))
                        fp='pokedex/footprint_'+name.lower()+'.rgba';(stage/fp).parent.mkdir(exist_ok=True);(stage/fp).write_bytes(raw)
                        row['footprint']={'file':fp,'width':im.width,'height':im.height,'graphic':str(path.relative_to(source))}
            pic=re.search(r'\.frontPic\s*=\s*(gMonFrontPic_\w+)',b)
            pal=re.search(r'\.palette\s*=\s*(gMonPalette_\w+)',b)
            if assets and pic and pal:
                gfx=re.search(pic[1]+r'\[\].*?INCBIN_U32\("([^"]+)"\)',graphics)
                colors=re.search(pal[1]+r'\[\].*?INCBIN_U16\("([^"]+)"\)',graphics)
                if gfx and colors:
                    graphic=source/gfx[1].replace('.4bpp.smol','.png');palette=source/colors[1].replace('.gbapal','.pal')
                    if graphic.exists() and palette.exists():
                        im=Image.open(graphic).crop((0,0,64,64))
                        rgb=[tuple(round(int(c)//8*255/31) for c in line.split()) for line in palette.read_text().splitlines()[3:]]
                        raw=bytes(v for n in im.tobytes() for v in ((*rgb[n&15],255) if n&15 else (0,0,0,0)))
                        fp='pokedex/front_'+name.lower()+'.rgba';(stage/fp).parent.mkdir(exist_ok=True);(stage/fp).write_bytes(raw)
                        row['front']={'file':fp,'width':64,'height':64,'graphic':gfx[1],'palette':colors[1]}
            pic=re.search(r'\.iconSprite\s*=\s*(gMonIcon_\w+)',b)
            index=re.search(r'\.iconPalIndex\s*=\s*(\d+)',b)
            if assets and pic and index:
                gfx=re.search(pic[1]+r'\[\].*?INCBIN_U8\(\s*"([^"]+)"\)',graphics)
                if gfx:
                    path=gfx[1].replace('.4bpp','.png');im=Image.open(source/path)
                    pal='graphics/pokemon/icon_palettes/pal'+index[1]+'.pal'
                    rgb=[tuple(round(int(c)//8*255/31)for c in line.split())for line in (source/pal).read_text().splitlines()[3:]]
                    raw=bytes(v for n in im.tobytes()for v in ((*rgb[n&15],255)if n&15 else(0,0,0,0)))
                    fp='pokedex/icon_'+name.lower()+'.rgba';(stage/fp).write_bytes(raw)
                    row['icon']={'file':fp,'width':im.width,'height':im.height,'graphic':path,'palette':pal}
        return row
    entries=[entry(name,i) for i,name in enumerate(names,1)]
    unknown=entry('NONE',0)
    regional={name:i for i,name in enumerate(names,1)}
    nat_names=re.findall(r'^\s*NATIONAL_DEX_(\w+),',header,re.M)
    registration=[entry(name,regional.get(name,0)) for name in nat_names if name in known and name!='NONE']
    for row in registration:row['nationalNumber']=nat_names.index(row['speciesName'])
    # Completion ratings must retain unsupported entries too, so they cannot
    # falsely declare completion after catching just the bridged species.
    obtainable=re.findall(r'^\s*OBTAINABLE_DEX_(\w+),',preprocess('constants/pokedex.h'),re.M)
    rating_national=[entry(name,regional.get(name,0),False) for name in obtainable if name!='NONE']
    assert len(rating_national)==482,len(rating_national)
    obtainable_order={name:i for i,name in enumerate(obtainable)}
    for row in registration:row['obtainableNumber']=obtainable_order.get(row['speciesName'],row['nationalNumber'])
    for row in rating_national:row['obtainableNumber']=obtainable_order[row['speciesName']]
    for row in rating_national:
        for key in ('front','footprint','description','descriptionLines','stats','category','height','weight','abilityNames','growthRate','learnsetRef','evYield','genderRatio'):row.pop(key,None)
    directory=stage/'pokedex';directory.mkdir(exist_ok=True)
    base=source/'graphics/pokedex/hgss'
    colors=[tuple(round((int(c)>>3)*255/31) for c in v.split())+(255,) for v in (base/'palette_default.pal').read_text().splitlines()[3:]]
    def render(tiles_name,maps,transparent=False):
        tiles=Image.open(base/tiles_name);assert tiles.mode=='P'
        result=Image.new('RGBA',(240,160),(0,0,0,0)if transparent else colors[1])
        cols=tiles.width//8
        for filename in maps:
            raw=(base/filename).read_bytes();words=struct.unpack('<'+'H'*(len(raw)//2),raw)
            for pos,word in enumerate(words):
                x,y=(pos%32)*8,(pos//32)*8
                if x>=240 or y>=160:continue
                tid,pal=word&1023,word>>12
                assert tid*64<tiles.width*tiles.height,(filename,tid)
                tile=tiles.crop(((tid%cols)*8,(tid//cols)*8,(tid%cols)*8+8,(tid//cols)*8+8))
                if word&1024:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                if word&2048:tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                pixels=[]
                for index in tile.tobytes():
                    if not index:pixels.append((0,0,0,0));continue
                    n=pal*16+index;assert n<len(colors),(filename,n)
                    pixels.append(colors[n])
                tile=Image.new('RGBA',(8,8));tile.putdata(pixels);result.alpha_composite(tile,(x,y))
        return result
    backgrounds={}
    for name,tiles,tm in [('list','tileset_menu_list.png',['tilemap_list_screen_underlay.bin','tilemap_list_screen.bin']),('info','tileset_menu1.png',['tilemap_info_screen.bin']),('stats','tileset_menu1.png',['tilemap_stats_screen.bin']),('evo','tileset_menu2.png',['tilemap_evo_screen_PE.bin']),('cry','tileset_menu3.png',['tilemap_cry_screen.bin']),('size','tileset_menu3.png',['tilemap_size_screen.bin'])]:
        image=render(tiles,tm);(directory/(name+'.rgba')).write_bytes(image.tobytes());image.save(directory/(name+'.png'))
        backgrounds[name]='pokedex/'+name+'.rgba'
    for name,tm in [('listUnderlay','tilemap_list_screen_underlay.bin'),('listOverlay','tilemap_list_screen.bin')]:
        image=render('tileset_menu_list.png',[tm],name=='listOverlay')
        file='pokedex/'+name+'.rgba';(stage/file).write_bytes(image.tobytes());backgrounds[name]=file
    # The select bar is a BG1 overlay onto the source detail-page top bar.
    image=render('tileset_menu1.png',['SelectBar.bin']);(directory/'select.rgba').write_bytes(image.tobytes())
    art={}
    for name,filename in [('interface','hgss/tileset_interface_hns.png'),('caught','caught_ball.png')]:
        im=Image.open(source/'graphics/pokedex'/filename);raw=bytes(v for n in im.tobytes()for v in (colors[n&15]if n&15 else (0,0,0,0)))
        file='pokedex/'+name+'.rgba';(stage/file).write_bytes(raw);art[name]={'file':file,'width':im.width,'height':im.height}
    # OBJ sheets are tile-linear; a rectangular crop of the PNG is incorrect
    # whenever a sprite spans more than one sheet row.
    sheet=Image.open(base/'tileset_interface_hns.png');cols=sheet.width//8
    for name,tid,w,h in [('scrollBall',16,32,32),('scrollArrow',1,16,8),('scrollBar',3,8,8),('johto',160,32,16),('national',168,32,16),('seen',64,64,32),('owned',96,64,32)]+[('digit'+str(i),176+i*2,8,16)for i in range(10)]:
        out=Image.new('P',(w,h));out.putpalette(sheet.getpalette())
        for y in range(h//8):
            for x in range(w//8):
                tile=tid+y*(w//8)+x;out.paste(sheet.crop(((tile%cols)*8,(tile//cols)*8,(tile%cols)*8+8,(tile//cols)*8+8)),(x*8,y*8))
        raw=bytes(v for n in out.tobytes()for v in (colors[n&15]if n&15 else (0,0,0,0)))
        file='pokedex/'+name+'.rgba';(stage/file).write_bytes(raw);art[name]={'file':file,'width':w,'height':h}
    art['unknown']=unknown['front']
    def move_item(name,graphic,palette):
        im=Image.open(source/graphic)
        rgb=[tuple(round(int(c)//8*255/31)for c in line.split())for line in (source/palette).read_text().splitlines()[3:]]
        raw=bytes(v for n in im.tobytes()for v in ((*rgb[n&15],255)if n&15 else(0,0,0,0)))
        file='pokedex/item_'+name.lower()+'.rgba';(stage/file).write_bytes(raw)
        art[name]={'file':file,'width':im.width,'height':im.height,'graphic':graphic,'palette':palette}
    for name,file in [('egg','lucky_egg'),('candy','rare_candy'),('tutor','teachy_tv')]:
        move_item(name,'graphics/items/icons/'+file+'.png','graphics/items/icon_palettes/'+file+'.pal')
    for kind in ('TM','HM'):
        for type_name in {v['type']for v in display_moves.values()}:
            palette='graphics/items/icon_palettes/'+type_name.lower()+'_tm_hm.pal'
            if (source/palette).exists():move_item(kind+type_name,'graphics/items/icons/'+kind.lower()+'.png',palette)
    bar_colors=[(0,0,0,0),(255,255,255,255)]+[tuple(round(c*255/31)for c in rgb)+(255,)for rgb in ((2,25,25),(13,27,27),(11,25,2),(19,27,13),(22,25,2),(26,27,13),(25,22,2),(27,26,13),(25,17,2),(27,22,13),(25,4,2),(27,15,13),(0,0,0),(22,22,22))]
    im=Image.open(base/'stat_bars.png');raw=bytes(v for n in im.tobytes()for v in bar_colors[n&15]);file='pokedex/bars.rgba';(stage/file).write_bytes(raw);art['bars']={'file':file,'width':im.width,'height':im.height}
    refs={r.get(k)for r in registration for k in ('learnsetRef','legacyLearnsetRef')}
    learnsets={k:{n:rows for n,rows in v.items()if n in refs}for k,v in learnsets.items()}
    refs={r.get('teachableRef')for r in registration}
    teachables={n:rows for n,rows in teachables.items()if n in refs}
    refs={r.get(k)for r in registration for k in ('eggRef','legacyEggRef')}
    eggsets={gen:{n:rows for n,rows in sets.items()if n in refs}for gen,sets in eggsets.items()}
    # Explicit HnS text, rather than relying on an Emerald cached battle string.
    battle=(source/'src/battle_message.c').read_text()
    nickname=re.search(r'\[STRINGID_GIVENICKNAMECAPTURED\]\s*=\s*COMPOUND_STRING\("([^"]+)"\)',battle)[1]
    return {'modernGeneration':modern_generation,'entries':entries,'registrationEntries':registration,'ratingNationalEntries':rating_national,'abilities':abilities,'contestMoves':contest_moves,'moveInfo':display_moves,'teachables':teachables,'eggsets':eggsets,'machineLabels':machine_labels,'learnsets':learnsets,'art':art,'count':len(entries),'source':'HnS JOHTO_DEX / HGSS Plus','backgrounds':backgrounds,'selectBar':'pokedex/select.rgba','nicknamePrompt':nickname,'limits':'Source list/info/stats and caught-registration layout for supported species. Expanded species retain reserved numbers; evolution/forms, size comparison and cry visualizer remain unfinished. Complete source egg/level-up/TM/tutor move information is display data; expanded battle effects and move-learning bridges remain pending.'}
