"""Source HnS bag, doors, exit arrows and permanent harvestable berry trees."""
import json,re,struct,subprocess
from PIL import Image


def build(source,engine,stage,pairs,maps,source_maps,text,scripts,ow,lua,palette_parser,teaching=None,dex=None):
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/item.h"\n#include "config/overworld.h"\n#include "config/battle.h"\n'
    def pp(path):return subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "'+path+'"\n',text=True,stderr=subprocess.DEVNULL)
    def paths(body):return dict(re.findall(r'\b(\w+)\[\].*?=\s*INCBIN_\w+\("([^"]+)"',body))
    def pngpath(p):return re.sub(r'\.(?:[1248]bpp|gbapal).*$',lambda m:'.pal'if 'gbapal'in m[0]else'.png',p)
    def pal(path):
        p=source/pngpath(path)
        if p.exists():return palette_parser(p)
        im=Image.open(p.with_suffix('.png'));rgb=im.getpalette();return [(rgb[i*3]//8)|((rgb[i*3+1]//8)<<5)|((rgb[i*3+2]//8)<<10)for i in range(16)]
    def color(v):return (round((v&31)*255/31),round((v>>5&31)*255/31),round((v>>10&31)*255/31),255)
    def indexed(path,colors,opaque=False):
        im=Image.open(source/pngpath(path));return Image.frombytes('RGBA',im.size,bytes(c for i in im.tobytes()for c in (color(colors[i&15])if (i&15)or opaque else(0,0,0,0))))
    files={}
    def save(file,im):
        (stage/file).parent.mkdir(parents=True,exist_ok=True);(stage/file).write_bytes(im.tobytes());files[file]={'file':file,'width':im.width,'height':im.height};return files[file]
    def bg(path,tilemap,colors):
        im=Image.open(source/path);ts=[im.crop((x,y,x+8,y+8))for y in range(0,im.height,8)for x in range(0,im.width,8)]
        words=struct.unpack('<%dH'%((source/tilemap).stat().st_size//2),(source/tilemap).read_bytes());out=Image.new('RGBA',(240,160))
        for i,w in enumerate(words):
            if i%32>=30 or i//32>=20:continue
            tile=ts[w&1023]
            if w&1024:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if w&2048:tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            tile=Image.frombytes('RGBA',(8,8),bytes(c for v in tile.tobytes()for c in color(colors[(w>>12)*16+(v&15)])))
            out.paste(tile,(i%32*8,i//32*8))
        return out
    def palettes(path):
        p=source/path;rows=p.read_text().splitlines();return [(int(r)//8)|((int(g)//8)<<5)|((int(b)//8)<<10)for r,g,b in(map(str.split,rows[3:]))]
    bag={'images':{},'pockets':['ITEMS','MEDICINE','POKE_BALLS','TM_CASE','BERRY_POUCH','KEY_ITEMS'],'labels':{'ITEMS':'ITEMS','MEDICINE':'MEDICINE','POKE_BALLS':'POKé BALLS','TM_CASE':'TMs & HMs','BERRY_POUCH':'BERRIES','KEY_ITEMS':'KEY ITEMS'},'frame':{'ITEMS':3,'KEY_ITEMS':3,'MEDICINE':1,'POKE_BALLS':2,'TM_CASE':4,'BERRY_POUCH':5},'items':{}}
    for gender in ('male','female'):
        colors=palettes('graphics/bag/hns/menu_'+gender+'.pal');bag[gender+'Palette']=colors
        bag['images']['bg_'+gender]=save('services/bag_bg_'+gender+'.rgba',bg('graphics/bag/menu.png','graphics/bag/menu_6.bin',colors))
        raw=Image.open(source/'graphics/bag/menu.png');ts=[raw.crop((x,y,x+8,y+8))for y in range(0,raw.height,8)for x in range(0,raw.width,8)];im=Image.new('RGBA',(16,8))
        for i,tid in enumerate((0x17,0x2B)):
            t=ts[tid];t=Image.frombytes('RGBA',(8,8),bytes(c for v in t.tobytes()for c in color(colors[16+(v&15)])));im.paste(t,(i*8,0))
        bag['images']['indicator_'+gender]=save('services/bag_indicator_'+gender+'.rgba',im)
        bag['images']['bag_'+gender]=save('services/bag_'+gender+'.rgba',indexed('graphics/bag/hns/bag_'+gender+'.png',pal('graphics/bag/hns/bag.pal')))
    bag['images']['arrows']=save('services/bag_arrows.rgba',indexed('graphics/interface/scroll_indicator.png',pal('graphics/interface/red.pal')))
    bag['images']['ball']=save('services/bag_ball.rgba',indexed('graphics/bag/rotating_ball.png',pal('graphics/bag/rotating_ball.pal')))
    itembody=pp('data/items.h');itempaths=paths(pp('data/graphics/items.h'));native={name:int(n)for n,name in re.findall(r'\[(\d+)\]\s*=\s*"ITEM_(\w+)"',(engine/'src/core/game3/constants/emerald/items.lua').read_text())}
    native.update({'GB_PLAYER':902,'EXP_SHARE':903,'MYSTERY_EGG':900,'TM_ROOST':901})
    strings={name:''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',b))for name,b in re.findall(r'(?:static )?const u8 (\w+)\[\]\s*=\s*_\((.*?)\);',itembody,re.S)}
    for name,b in re.findall(r'\[ITEM_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[ITEM_|\Z)',itembody,re.S):
        if name not in native:continue
        p=re.search(r'\.pocket\s*=\s*POCKET_(\w+)',b);d=re.search(r'\.description\s*=\s*(\w+)',b);n=re.search(r'\.name\s*=\s*(?:COMPOUND_STRING(?:_SIZE_LIMIT)?|ITEM_NAME)\("([^"]+)"',b)
        row={'source':name,'medicine':bool(p and p[1]=='MEDICINE')}
        if n:row['name']=n[1]
        if d and d[1]in strings:row['description']=strings[d[1]]
        cd=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',b,re.S)
        if cd:row['description']=''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',cd[1]))
        g=re.search(r'\.iconPic\s*=\s*(\w+)',b);p=re.search(r'\.iconPalette\s*=\s*(\w+)',b)
        if g and p and g[1]in itempaths and p[1]in itempaths:row['icon']=save('services/item_'+str(native[name])+'.rgba',indexed(itempaths[g[1]],pal(itempaths[p[1]])))
        bag['items'][str(native[name])]=row
    bag['returnIcon']=save('services/item_return.rgba',indexed(itempaths['gItemIcon_ReturnToFieldArrow'],pal(itempaths['gItemIconPalette_ReturnToFieldArrow'])))
    if teaching:
        for r in teaching['machines']:
            # GetItemIconPalette uses the move's type; the generic disc has
            # no per-item icon pointers in gItemsInfo.
            typ=dex['moveInfo'][r['move']]['type'].title().replace('_','')
            icon=save('services/item_'+str(r['itemId'])+'.rgba',indexed(itempaths['gItemIcon_'+r['kind']],pal(itempaths['gItemIconPalette_'+typ+'TMHM'])))
            bag['items'][str(r['itemId'])]={'source':r['label'],'medicine':False,'name':r['name'],'description':r['description'],'icon':icon}
    # Door lookup retains the exact source pair/metatile, including reused IDs.
    body=(source/'src/field_door.c').read_text();doorpaths=paths(body);palrows={n:list(map(int,re.findall(r'\d+',b)))for n,b in re.findall(r'(sDoorAnimPalettes_\w+)\[\]\s*=\s*\{([^}]+)',body)}
    mids={n:int(v,0)for n,v in re.findall(r'#define\s+(METATILE_\w+)\s+(0x[\da-fA-F]+|\d+)\b',(source/'include/constants/metatile_labels.h').read_text())}
    # Apply the source build switches without expanding metatile symbols.
    table=body[body.index('static const struct DoorGraphics sDoorAnimGraphicsTable'):body.index('#define DOOR_TILE_START_SIZE1')]
    table=subprocess.check_output(['cpp','-P','-DIS_FRLG=0','-DIS_HNS=1','-'],input=table,text=True)
    doorRows=re.findall(r'\{(METATILE_\w+),\s*&?(gTileset_\w+),\s*DOOR_SOUND_(\w+),\s*(\d),\s*(sDoorAnimTiles_\w+),\s*(sDoorAnimPalettes_\w+)\}',table)
    doors={}
    for pairid,pair in sorted(pairs.items()):
        available={pair.primary.spec['dir'],pair.secondary.spec['dir']};pnames={n for n,spec in __import__('build_port').symbols(source).items()if spec['dir']in available}
        for mid,tileset,sound,size,g,p in doorRows:
            if tileset not in pnames or mids[mid] not in maps_mid_set(maps,pairid):continue
            # HnS/FRLG size1 is 16x16; size2 is 16x32. Emerald is 16x32/32x32.
            versions={m['hnsLayoutVersion']for m in maps.values()if m['pair']==pairid}
            for version in versions:
                w,h=(16,16 if size=='1'else 32)if version in('hns','frlg')else(16 if size=='1'else 32,32)
                src=Image.open(source/pngpath(doorpaths[g]));tiles=[src.crop((x,y,x+8,y+8))for y in range(0,src.height,8)for x in range(0,src.width,8)]
                tilecount=w*h//64
                if len(tiles)<tilecount*3:continue
                out=Image.new('RGBA',(w,h*3))
                for f in range(3):
                    for t in range(tilecount):
                        bank=palrows[p][t%len(palrows[p])];tile=tiles[f*tilecount+t]
                        tile=Image.frombytes('RGBA',(8,8),bytes(c for v in tile.tobytes()for c in (color(pair.palettes[bank][v&15])if v&15 else(0,0,0,255))))
                        out.paste(tile,(((t//8)*16+(t%4)%2*8)if w==32 else(t%2*8),f*h+(((t%8)//4)*16+(t%4)//2*8 if w==32 else(t//2*8))))
                key=pairid+'_'+str(mids[mid])+'_'+version
                info=save('services/door_'+key+'.rgba',out);info.update(w=w,h=h,sound=sound.lower(),mid=mids[mid],graphic=pngpath(doorpaths[g]),paletteSlots=palrows[p])
                doors.setdefault(pairid,{})[str(mids[mid])+':'+version]=info
    arrow={str(i):save('services/exit_arrow_'+str(i)+'.rgba',indexed('graphics/field_effects/pics/arrow.png',pal('graphics/object_events/palettes/'+n+'_hns.pal')))for i,n in enumerate(('gold','kris'))}
    # Native saved tree IDs/berry numbers are retained; source items map by name.
    berryconst={n:int(v)for n,v in re.findall(r'#define\s+(BERRY_TREE_\w+)\s+(\d+)\b',(source/'include/constants/berry.h').read_text())}
    initial={n:item for n,item in re.findall(r'setberrytree\s+(BERRY_TREE_\w+),\s*ITEM_TO_BERRY\(ITEM_(\w+)\),\s*BERRY_STAGE_BERRIES',(source/'data/scripts/new_game.inc').read_text())}
    berries={};objects=[];bt=pp('data/object_events/berry_tree_graphics_tables.h');gfxpaths=paths(pp('data/object_events/object_event_graphics.h'))
    berryraw=(source/'src/berry.c').read_text();berrybody=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-'],input=prefix+berryraw[berryraw.index('#define GROWTH_DURATION'):berryraw.index('const struct BerryCrushBerryData')],text=True);stats={name:b for name,b in re.findall(r'\[ITEM_(\w+) - FIRST_BERRY_INDEX\]\s*=\s*\{(.*?)(?=\n\s*\[ITEM_|\n};)',berrybody,re.S)}
    def num(expr):
        toks=re.findall(r'\d+|>=|==|<=|[?:()+*/-]',expr)
        def primary(i):
            if toks[i]=='(':v,i=conditional(i+1);assert toks[i]==')';return v,i+1
            return int(toks[i]),i+1
        def arithmetic(i):
            v,i=primary(i)
            while i<len(toks)and toks[i]in('+','-','*','/'):
                op=toks[i];r,i=primary(i+1);v=v+r if op=='+'else v-r if op=='-'else v*r if op=='*'else v//r
            return v,i
        def conditional(i):
            v,i=arithmetic(i)
            if i<len(toks)and toks[i]in('==','>=','<='):
                op=toks[i];r,i=arithmetic(i+1);v=int(v==r if op=='=='else v>=r if op=='>='else v<=r)
            if i<len(toks)and toks[i]=='?':
                a,i=conditional(i+1);assert toks[i]==':';b,i=conditional(i+1);v=a if v else b
            return v,i
        v,i=conditional(0);assert i==len(toks),(expr,i);return v
    for mapid,m in sorted(maps.items()):
        for index,e in enumerate(source_maps[m['hnsSourceId']].get('object_events',[])):
            if e['graphics_id']!='OBJ_EVENT_GFX_BERRY_TREE' or e['flag']!='0' or not(0<=e['x']<m['width']and 0<=e['y']<m['height']):continue
            name=e['trainer_sight_or_berry_tree_id'];item=initial[name];itemid=native[item];berry=itemid-native['CHERI_BERRY']+1;tid=berryconst[name]
            if str(berry)not in berries:
                picname=re.search(r'\[ITEM_'+item+r' - FIRST_BERRY_INDEX\]\s*=\s*(sPicTable_\w+)',bt)[1];rows=re.search(r'\b'+picname+r'\[\]\s*=\s*\{(.*?)\};',bt,re.S)[1]
                frames=re.findall(r'overworld_frame\((\w+),\s*(\d+),\s*(\d+),\s*(\d+)\)',rows)
                palname=re.search(r'\[ITEM_'+item+r' - FIRST_BERRY_INDEX\]\s*=\s*(gBerryTreePaletteSlotTable_\w+)',bt)[1];slots=list(map(int,re.findall(r'\d+',re.search(r'\b'+palname+r'\[\]\s*=\s*\{([^}]+)',bt)[1])))
                sequences=[[(0,32)],[(1,32),(2,32)],[(3,48),(4,48)],[(5,32),(5,32),(6,32),(6,32)],[(7,48),(7,48),(8,48),(8,48)]]
                frameSlots={f:slots[s]for s,seq in enumerate(sequences)for f,d in seq};out=Image.new('RGBA',(16,sum(int(h)*8 for g,w,h,i in frames)));frs=[];y=0
                for f,(g,w,h,idx)in enumerate(frames):
                    w,h=int(w)*8,int(h)*8;raw=Image.open(source/pngpath(gfxpaths[g]));x=int(idx)%(raw.width//w)*w;fy=int(idx)//(raw.width//w)*h
                    colors=pal('graphics/object_events/palettes/'+['npc_white_hns','npc_pink_hns','npc_blue_hns','npc_green_hns'][frameSlots[f]-2]+'.pal');frame=raw.crop((x,fy,x+w,fy+h));frame=Image.frombytes('RGBA',(w,h),bytes(c for v in frame.tobytes()for c in (color(colors[v&15])if v&15 else(0,0,0,0))))
                    out.paste(frame,(0,y));frs.append({'y':y,'w':w,'h':h});y+=h
                info=save('services/tree_'+str(berry)+'.rgba',out);info['frames']=frs;info['stages']=[{'anim':[{'frame':f,'duration':d}for f,d in seq]}for seq in sequences];info['nativeFile']=str(berry)+'.rgba'
                b=stats[item];entry={'item':itemid,'tree':info,'name':re.search(r'\.name\s*=\s*_\("([^"]+)"',b)[1]}
                for fld,target in [('growthDuration','stageDuration'),('minYield','minYield'),('maxYield','maxYield')]:entry[target]=num(re.search(r'\.'+fld+r'\s*=\s*([^,]+)',b)[1])
                berries[str(berry)]=entry
            obj={'localId':index+1,'x':e['x'],'y':e['y'],'elevation':e['elevation'],'graphicsId':64,'movementType':12,'hnsMovementType':e['movement_type'],'berryTreeId':tid,'trainerRange':tid,'scriptKey':'HNS_BERRY_INTERACT','hnsBerry':True}
            assert not any(o['localId']==index+1 for o in m['objects']);m['objects'].append(obj);objects.append({'map':mapid,'id':tid,'berry':berry,'localId':index+1,'sourceName':name})
    # A source dirt sprite supplies native dimensions before the growth actor
    # initializes. Mature/growing art is drawn by the native berry actor.
    gid=max(map(int,ow['sprites']))+1
    dirt=berries[next(iter(berries))]['tree'];raw=(stage/'services'/('tree_'+next(iter(berries))+'.rgba')).read_bytes()[:16*16*4]
    (stage/'ow'/f'{gid}.rgba').write_bytes(raw)
    (stage/'ow'/f'{gid}.meta').write_bytes(b'SVOW'+struct.pack('<BB6HBHB',2,1,gid,16,16,1,0xFFFF,0xFFFF,4,0xFFFF,0)+bytes(32)+bytes(64))
    ow['sprites'][str(gid)]={'graphicsId':gid,'width':16,'height':16,'frameCount':1,'source':'OBJ_EVENT_GFX_BERRY_TREE','standingOnly':True}
    for r in objects:
        m=maps[r['map']];o=next(o for o in m['objects']if o['localId']==r['localId']);src=source_maps[m['hnsSourceId']]['object_events'][r['localId']-1]
        o.update(graphicsId=gid,hnsGraphicsId=gid,rangeX=src['movement_range_x'],rangeY=src['movement_range_y'],facing='down',radius={'x':src['movement_range_x'],'y':src['movement_range_y']})
    for suffix in ('NotRipe','Picked','BagFull'):
        import opening
        label='BerryTree_Text_Hns_'+suffix;labels={};current=None
        for line in (source/'data/scripts/berry_tree.inc').read_text().splitlines():
            z=re.match(r'^(\w+)::?$',line)
            if z:current=z[1];labels[current]=[]
            elif current:labels[current].append(line)
        text['HNS_BERRY_'+suffix.upper()]=opening.source_text(label,labels)
    scripts['HNS_BERRY_INTERACT']=[{'op':'lockall'},{'op':'callnative','fn':0x484E530C},{'op':'compare_var_to_value','var':0x8004,'value':1},{'op':'goto_if','cond':1,'target':'HNS_BERRY_FULL'},{'op':'compare_var_to_value','var':0x8004,'value':2},{'op':'goto_if','cond':1,'target':'HNS_BERRY_PICKED'},{'op':'message','ptr':'HNS_BERRY_NOTRIPE'},{'op':'waitmessage'},{'op':'waitbuttonpress'},{'op':'closemessage'},{'op':'releaseall'},{'op':'end'}]
    scripts['HNS_BERRY_FULL']=[{'op':'message','ptr':'HNS_BERRY_BAGFULL'},{'op':'waitmessage'},{'op':'waitbuttonpress'},{'op':'closemessage'},{'op':'releaseall'},{'op':'end'}]
    scripts['HNS_BERRY_PICKED']=[{'op':'message','ptr':'HNS_BERRY_PICKED'},{'op':'playfanfare','songName':'MUS_HG_OBTAIN_BERRY'},{'op':'incrementgamestat',1:3},{'op':'waitmessage'},{'op':'waitfanfare'},{'op':'closemessage'},{'op':'releaseall'},{'op':'end'}]
    return {'bag':bag,'doors':doors,'arrow':arrow,'berries':berries,'objects':objects,'files':files,'initializedFlag':0x6030,'harvestNative':0x484E530C}


def maps_mid_set(maps,pair):
    # The pair already contains the imported mid set. Rows without matching
    # behavior are omitted by runtime; retaining declared IDs is harmless.
    return set(range(1024))
