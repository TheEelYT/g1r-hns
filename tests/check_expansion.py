"""Independent source pixel checks and a compiled C time-tint oracle."""
import argparse,json,re,struct,subprocess,tempfile
from pathlib import Path
from PIL import Image
from check_battle_entry import check_entry


def colors(path):
    if not path.exists():
        p=Image.open(path.with_suffix('.png')).getpalette()
        return [tuple((v>>3)*255//31+int(((v>>3)*255)%31>=16)for v in p[i:i+3])for i in range(0,len(p),3)]
    lines=path.read_text().splitlines()
    return [tuple((int(v)>>3)*255//31+int(((int(v)>>3)*255)%31>=16) for v in row.split()) for row in lines[3:3+int(lines[2])]]


def tile_pixel(im,tile,x,y):
    return im.getpixel(((tile%(im.width//8))*8+x,(tile//(im.width//8))*8+y))


def map_pixels(im,words,pal,w,h,bank=0,nibble=False):
    raw=bytearray(w*h*4)
    for y in range(h):
        for x in range(w):
            word=words[y//8*32+x//8];px=7-x%8 if word&1024 else x%8;py=7-y%8 if word&2048 else y%8
            n=tile_pixel(im,word&1023,px,py)
            if nibble:n &= 15
            n+=max(0,(word>>12)-bank)*16
            raw[(y*w+x)*4:(y*w+x+1)*4]=bytes(pal[n]+(255,))
    return raw


def check(source,engine,mod,luajit):
    world=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')],text=True))
    count={};terrains=world['battleVisuals']['terrains']
    # Audit the source entry set independently, rather than only comparing
    # pixels for whatever subset the importer happened to emit.
    envcode=(source/'src/data/battle_environment.h').read_text().split('static const struct ModernBattleGfx sModernBattleGfx',1)[0]
    entries=re.findall(r'^    \[BATTLE_ENVIRONMENT_(\w+)\]\s*=\s*\{(.*?)\n    \}',envcode,re.S|re.M)
    environments={name for name,body in entries if '.background' in body}
    assert len(environments)==35 and 'GRASS' in environments and 'COUNT' not in environments
    assert set(terrains)=={e+'_'+s+'_'+t for e in environments for s in ('old','modern')for t in ('Day','Twilight','Night')}
    assert terrains['GRASS_modern_Day']['sourceTiles']=='graphics/battle_environment/tall_grass_modern/tiles.png'
    for key,row in terrains.items():
        raw=(source/row['sourceMap']).read_bytes();words=struct.unpack('<'+str(len(raw)//2)+'H',raw)
        pal=colors(source/row['sourcePalette']);pal += [(0,0,0)]*max(0,48-len(pal))
        expected=map_pixels(Image.open(source/row['sourceTiles']),words,pal,256,160,2)
        assert (mod/row['full']['file']).read_bytes()==expected,key
        if 'entry' in row:
            raw=(source/row['sourceEntryMap']).read_bytes();words=struct.unpack('<'+str(len(raw)//2)+'H',raw)
            im=Image.open(source/row['sourceEntryTiles']);expected=map_pixels(im,words,pal,256,256,2,True)
            for y in range(256):
                for x in range(256):
                    word=words[y//8*32+x//8];px=7-x%8 if word&1024 else x%8;py=7-y%8 if word&2048 else y%8
                    if tile_pixel(im,word&1023,px,py)%16==0:expected[(y*256+x)*4+3]=0
            assert (mod/row['entry']['file']).read_bytes()==expected,key
            raw=(source/row['sourceMap']).read_bytes();words=struct.unpack('<'+str(len(raw)//2)+'H',raw)
            im=Image.open(source/row['sourceTiles']);global_pal=colors(source/'graphics/battle_interface/hns/textbox.pal')[:16]*2+pal;expected=bytearray()
            for y in range(160):
                for x in range(512):
                    word=words[x//256*1024+y//8*32+(x%256)//8];px=7-x%8 if word&1024 else x%8;py=7-y%8 if word&2048 else y%8
                    n=tile_pixel(im,word&1023,px,py)+(word>>12)*16
                    expected.extend(global_pal[n]+(255 if n%16 else 0,))
            assert (mod/row['introBackground']['file']).read_bytes()==expected,key
    count.update(battle_terrain_configurations=len(terrains),battle_terrain_pixels=len(terrains)*256*160)
    count['source_modern_entry_pixels']=sum('entry' in row for row in terrains.values())*256*256
    count['source_modern_scroll_pixels']=sum('entry' in row for row in terrains.values())*512*160
    count['source_c_entry_frames']=check_entry(source,mod,luajit)
    # Reconstruct status strips from the source OAM stream and dynamic palettes.
    status_colors=[(24,12,24),(23,23,3),(20,20,17),(17,22,28),(28,14,10)]
    for style,d in [('gen3','hns'),('gen4','gen4')]:
        root=source/'graphics/battle_interface'/d;pal=colors(root/'healthbox_singles_player.pal')[:16]
        for name,h in [('healthbox_singles_player',64),('healthbox_singles_opponent',32),('healthbox_doubles_player',32),('healthbox_doubles_opponent',32),('healthbox_safari',64)]:
            im=Image.open(root/(name+'.png'));raw=bytearray();bg=2
            for y in range(h):
                for x in range(128):
                    tile=(x//64)*(h//8*8)+(y//8)*8+(x%64)//8;n=tile_pixel(im,tile,x%8,y%8)&15
                    # Source writes 55px nickname + 24px level; opponent
                    # windows end at x=88, player windows at x=96. Gen4
                    # TextIntoHealthboxObject uses BG index 2, not HP BG 3.
                    if 5<=y<16 and (16 if 'player'in name else 8)<=x<(96 if 'player'in name else 88):n=bg
                    if name=='healthbox_singles_player'and 24<=y<32 and 40<=x<96:n=3 if style=='gen4'else bg
                    raw.extend(pal[n]+(255 if n else 0,))
            a=world['battleVisuals']['ui'][style][name];assert (mod/a['file']).read_bytes()==raw,(style,name)
        for battler in range(4):
            im=Image.open(root/('status'+('' if battler==0 else str(battler+1))+'.png'))
            for status,c in enumerate(status_colors):
                p=pal.copy();p[12+battler]=tuple((v*255+15)//31 for v in c);raw=bytearray()
                for y in range(8):
                    for x in range(24):
                        n=tile_pixel(im,status*3+x//8,x%8,y)&15;raw.extend(p[n]+(255 if n else 0,))
                a=world['battleVisuals']['ui'][style]['statusIcons'][battler][status]
                assert (mod/a['file']).read_bytes()==raw,(style,battler,status)
    count['source_status_strips']=40
    count['source_healthbox_composites']=10
    for style,d in [('gen3','hns'),('gen4','gen4')]:
        root=source/'graphics/battle_interface'/d;im=Image.open(root/'last_used_ball_r_cycle.png');original=colors(root/'ability_pop_up.pal')
        for name,idle in [('ballPrompt',False),('ballPromptIdle',True)]:
            p=original.copy()
            if idle:p[10]=p[11]=p[13]
            raw=bytearray()
            for y in range(64):
                for x in range(32):
                    n=tile_pixel(im,y//8*4+x//8,x%8,y%8)&15;raw.extend(p[n]+(255 if n else 0,))
            a=world['battleVisuals']['ui'][style][name]
            assert a['height']==64 and (mod/a['file']).read_bytes()==raw
    count['source_ball_prompt_pixels']=4*32*64
    root=source/'graphics/expansion_intro';credits=world['bootPresentation']['credits'];p=colors(root/'credits.pal')[:48]+[(0,0,0)]*208
    for name,bpp in [('powered_by',4),('rhh_credits',8)]:
        im=Image.open(root/(name+'.png'));blob=(root/(name+'.bin')).read_bytes();words=struct.unpack('<'+str(len(blob)//2)+'H',blob);raw=bytearray()
        for y in range(160):
            for x in range(256):
                word=words[y//8*32+x//8];px=7-x%8 if word&1024 else x%8;py=7-y%8 if word&2048 else y%8
                n=tile_pixel(im,word&1023,px,py)+(word>>12)*16*(bpp==4);raw.extend(p[n]+(0 if bpp==8 and n==0 else 255,))
        assert (mod/credits[name]['file']).read_bytes()==raw,name
    for name,size,num,palette in [('dizzy_egg',32,8,'dizzy_egg'),('porygon',64,3,'porygon'),('porygon_shiny',64,3,'shiny')]:
        im=Image.open(root/'sprites'/('porygon.png'if name=='porygon_shiny'else name+'.png'));p=colors(root/'sprites'/(palette+'.pal'));raw=bytearray()
        for y in range(size*num):
            for x in range(size):
                tile=y//size*(size*size//64)+(y%size//8)*(size//8)+x//8;n=tile_pixel(im,tile,x%8,y%8)&15;raw.extend(p[n]+(255 if n else 0,))
        assert (mod/credits[name]['file']).read_bytes()==raw,name
    count['source_credits_pixels']=2*256*160+32*32*8+2*64*64*3
    # Full affine logo and normal backdrop indices, independent of converter.
    root=source/'graphics/title_screen/hns';title=world['boot']['title'] if 'boot' in world else world['bootPresentation']['title']
    # Check displayed color banks as well as image indices: a padded 8bpp
    # logo palette previously placed this backdrop beyond BG palette RAM.
    raw_lines=(root/'rayquaza_and_clouds.pal').read_text().splitlines()
    expected=[(r>>3)|((g>>3)<<5)|((b>>3)<<10)for r,g,b in(map(int,line.split())for line in raw_lines[3:19])]
    assert title['palettes']['bg'][224:240]==expected
    assert len(title['palettes']['bg'])==240
    for name,png,binfile,w,h,affine in [('logo','pokemon_logo.png','pokemon_logo.bin',256,256,True),('rayquaza','rayquaza.png','rayquaza.bin',256,160,False)]:
        im=Image.open(root/png);blob=(root/binfile).read_bytes();words=list(blob) if affine else struct.unpack('<'+str(len(blob)//2)+'H',blob);raw=bytearray()
        for y in range(h):
            for x in range(w):
                word=words[y//8*32+x//8];px=x%8;py=y%8
                if not affine:
                    if word&1024:px=7-px
                    if word&2048:py=7-py
                n=tile_pixel(im,word if affine else word&1023,px,py)+(0 if affine else (word>>12)*16)
                raw.extend((n,0,0,255))
        assert (mod/title['layers'][name]['file']).read_bytes()==raw,name
    count['source_title_pixels']=256*256+256*160
    # Every imported map preserves the source escape flag, not a guessed type.
    srcmaps={m['id']:m for p in (source/'data/maps').glob('*/map.json')for m in [json.loads(p.read_text())]}
    for m in world['maps'].values():assert m['allowEscaping']==int(srcmaps[m['hnsSourceId']]['allow_escaping']),m['hnsSourceId']
    count['source_escape_flags']=len(world['maps'])
    assert len(world['followers']['species'])==413
    count['follower_species_and_forms']=413;count['follower_normal_shiny_sheets']=826
    art=world['followers']['emotes'];im=Image.open(source/'graphics/misc/emotes.png');pal=colors(source/'graphics/misc/emotes.pal')
    raw=bytes(v for n in im.tobytes()for v in pal[n]+(255 if n else 0,))
    assert (mod/art['file']).read_bytes()==raw
    assert art['durations']==[30,25,30]
    anim=(source/'src/trainer_see.c').read_text()
    for n in range(11):
        block=re.search(r'sSpriteAnim_Emotes'+str(n)+r'\[\]\s*=\s*\{(.*?)\};',anim,re.S)[1]
        assert re.findall(r'ANIMCMD_FRAME\([^,]+,\s*(\d+)\)',block)==['30','25','30']
    count['source_follower_emote_frames']=22
    # Compile the actual source function; compare all 32768 ordinary colors
    # at six transition points against the actual installed Lua arithmetic.
    code=(source/'src/palette.c').read_text();a=code.index('void TimeMixPalettes(');b=code.index('\n// Apply weighted average',a);fn=code[a:b]
    pre='#include <stdint.h>\n#include <stdio.h>\ntypedef uint32_t u32;typedef int32_t s32;typedef uint16_t u16;typedef uint8_t bool8;\nstruct BlendSettings {u16 coeff;u32 blendColor;bool8 isTint;};\n#define DEFAULT_LIGHT_COLOR 0\n#define RGB2(r,g,b) ((r)|((g)<<5)|((b)<<10))\n'
    cases=[([116,116,157],[116,116,157],256),([116,116,157],[224,176,168],128),([224,176,168],[256,256,256],128),([256,256,256],[256,256,256],256),([256,256,256],[224,176,168],128),([224,176,168],[116,116,157],128)]
    def blend(v):return '{0,0,0}' if v==[256]*3 else '{16,'+str(v[0]|v[1]<<8|v[2]<<16)+',1}'
    main='\nint main(void){u16 src[16]={0},dst[16];\n'
    for i,(v0,v1,weight) in enumerate(cases):main+='struct BlendSettings a%d=%s,b%d=%s;for(int n=0;n<32768;n++){src[1]=n;TimeMixPalettes(1,src,dst,&a%d,&b%d,%d);fwrite(&dst[1],2,1,stdout);}\n'%(i,blend(v0),i,blend(v1),i,i,weight)
    main+='return 0;}\n'
    with tempfile.TemporaryDirectory()as temp:
        tmp=Path(temp);(tmp/'oracle.c').write_text(pre+fn+main);subprocess.run(['gcc','-std=c99','-O2',str(tmp/'oracle.c'),'-o',str(tmp/'oracle')],check=True)
        expected=subprocess.check_output([str(tmp/'oracle')])
        script="package.path='./?.lua;./?/init.lua;'..package.path;love=require('tests.love_stub');require('src.core.GameVersion').set('emerald');local g={_hnsRules={rules={own=function()return false end}}};local m={hooks={wrap=function()end}};assert(loadfile(arg[1]..'/time_cycle.lua'))()(m,{},g);local T=g._hnsTime.time;for _,t in ipairs({{0,0},{7,0},{9,0},{10,0},{18,30},{19,30}})do local a,b,w=T.blend({hours=t[1],minutes=t[2]});for n=0,32767 do local r=T.channel(n%32,a[1],b[1],w);local g=T.channel(math.floor(n/32)%32,a[2],b[2],w);local b=T.channel(math.floor(n/1024)%32,a[3],b[3],w);local v=r+g*32+b*1024;io.write(string.char(v%256,math.floor(v/256)))end end"
        (tmp/'actual.lua').write_text(script);actual=subprocess.check_output([str(luajit),str(tmp/'actual.lua'),str(mod)],cwd=engine)
        assert actual==expected,'Lua tint differs from compiled source TimeMixPalettes'
    count['source_c_tint_colors']=len(cases)*32768
    moves=world['expandedMoves']['moves'];omitted=world['expandedMoves']['omitted'];assert len(moves)>150
    # All source expanded move declarations are either supported or explained.
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "config/contest.h"\n#include "data/moves_info.h"\n',text=True)
    native=set(re.findall(r'MOVE_(\w+)',(engine/'src/core/game3/constants/emerald/moves.lua').read_text()))|{'NONE','VISE_GRIP','HIGH_JUMP_KICK','FEINT_ATTACK','SMELLING_SALTS'}
    allnames=set(re.findall(r'\[MOVE_(\w+)\]',body))-native
    assert set(moves)|{r['move']for r in omitted}==allnames
    assert not set(moves)&{r['move']for r in omitted}
    for i,(name,row)in enumerate(re.findall(r'\[MOVE_(\w+)\]\s*=\s*(.*?)(?=\n    \[MOVE_|\Z)',body,re.S)):
        if name not in moves:continue
        m=moves[name];assert m['id']==(world['campaign']['roostMove']if name=='ROOST'else 1000+i)
        display=world['pokedex']['moveInfo'][name]
        assert m['power']==display['power'] and m['accuracy']==display['accuracy'] and m['category']==display['category'],name
        assert m['description']==display['description'],name
    count['expanded_supported_moves']=len(moves);count['expanded_explicit_omissions']=len(omitted)
    # Compile the HnS branch of FOREACH_TM/HM independently. In particular,
    # POKEMON_HNS alone does not define IS_HNS until global.h is included.
    machines=world['teaching']['machines']
    code='#include <stdio.h>\n#define POKEMON_HNS 1\n#define TRUE 1\n#define FALSE 0\n#include "constants/global.h"\n#include "constants/items.h"\n#define ROW_TM(x) {"TM",#x,ITEM_TM_##x},\n#define ROW_HM(x) {"HM",#x,ITEM_HM_##x},\nstruct Machine{const char *kind,*move;int id;} machines[]={FOREACH_TM(ROW_TM) FOREACH_HM(ROW_HM)};\nint main(void){for(unsigned i=0;i<sizeof(machines)/sizeof(*machines);i++)printf("%s %s %d\\n",machines[i].kind,machines[i].move,machines[i].id);}\n'
    with tempfile.TemporaryDirectory()as temp:
        tmp=Path(temp);(tmp/'oracle.c').write_text(code)
        subprocess.run(['gcc','-std=c99','-I'+str(source/'include'),str(tmp/'oracle.c'),'-o',str(tmp/'oracle')],check=True)
        actual=[line.split()for line in subprocess.check_output([str(tmp/'oracle')],text=True).splitlines()]
    assert len(actual)==100 and len(machines)==100
    assert [(r['kind'],r['move'])for r in machines]==[(r[0],r[1])for r in actual]
    assert machines[50]['move']=='ROOST'and machines[-1]['move']=='WHIRLPOOL'
    assert len({r['itemId']for r in machines})==100
    assert all(r['itemId']==(288+r['number']if r['number']<=50 else 901 if r['number']==51 else 852+r['number'])for r in machines if r['kind']=='TM')
    count['source_c_machine_catalogue']=100
    assembly=(source/'data/battle_scripts_1.s').read_text()
    scripts={'HONE_CLAWS':'AttackAccUp','WORK_UP':'AttackSpAttackUp','QUIVER_DANCE':'QuiverDance','COIL':'Coil','SHELL_SMASH':'ShellSmash','COTTON_GUARD':'DefenseUp3','VICTORY_DANCE':'VictoryDance'}
    names={'attack':'ATK','defense':'DEF','speed':'SPEED','spAtk':'SPATK','spDef':'SPDEF','accuracy':'ACC','evasion':'EVASION'}
    for move,script in scripts.items():
        block=assembly.split('BattleScript_Effect'+script+'::',1)[1].split('\nBattleScript_Effect',1)[0]
        expected=re.findall(r'setstatchanger STAT_(\w+), (\d+), (TRUE|FALSE)',block)
        assert [(names[r['stat']],str(abs(r['delta'])),'TRUE'if r['delta']<0 else'FALSE')for r in moves[move]['stageChanges']]==expected,move
    count['source_ordered_setup_scripts']=len(scripts)
    for pickup in world['teaching']['pickups']:
        original=srcmaps[world['maps'][pickup['map']]['hnsSourceId']]['object_events'][pickup['localId']-1]
        assert original['flag']==pickup['sourceFlag']
        body=(source/'data/maps'/world['maps'][pickup['map']]['hnsSourceId'].removeprefix('MAP_')/'scripts.inc')
        # Source scripts may be shared from another map. Match the defining
        # label across the source without relying on importer label tables.
        definition=next(p.read_text().split(original['script']+'::',1)[1]for p in (source/'data/maps').glob('*/scripts.inc')if original['script']+'::'in p.read_text())
        assert re.match(r'\s*finditem '+pickup['sourceItem']+r'\s+end\b',definition),pickup
        rows=world['scripts'][pickup['script']]
        grant=next(r for r in rows if r['op']=='additem');assert grant['item']==pickup['itemId']and grant['quantity']==1
    count['source_machine_pickups']=len(world['teaching']['pickups'])
    return {'result':'pass','counts':count,'limits':['Tint oracle covers ordinary 5-bit colors; source palette-bank light immunity and alternate-light high bits remain pending.','Modern entry maps/scroll registers match source; battler/sprite orchestration and blend effects retain native integration. Distinct expanded move animations and full expanded effects/abilities are unfinished.']}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('source','engine','mod','luajit'):p.add_argument('--'+n,type=Path,required=True)
    p.add_argument('--report',type=Path);a=p.parse_args();r=check(a.source.resolve(),a.engine.resolve(),a.mod.resolve(),a.luajit.resolve())
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps(r))
