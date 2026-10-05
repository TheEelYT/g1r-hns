"""Reviewed HnS opening gates and source UI assets, append-only namespaces."""
import re
import json
import struct
from PIL import Image
import opening
import quest
import scenes
import settings
import world_trainers

GEAR=0x6025
ELM_PHONE=0x6026
ELM_CALL=0x6027
EXP_OFF=0x6028
WINDOW_HIDDEN=0x602A
RADIO=0x602B
ELM_PENDING=0x7009
CALL_PENDING=0x700A
EXP_ITEM=903
CALL_NATIVE=0x484E5307

def image(source,stage,path,out,palette_parser,pal=None):
    im=Image.open(source/path);assert im.mode=='P'
    if pal and (source/pal).exists():colors=palette_parser(source/pal)
    else:
        rgb=im.getpalette();colors=[(rgb[i*3]//8)|((rgb[i*3+1]//8)<<5)|((rgb[i*3+2]//8)<<10) for i in range(16)]
    pixels=bytearray()
    for v in im.tobytes():
        c=colors[v];pixels.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if v else 0))
    (stage/out).parent.mkdir(parents=True,exist_ok=True);(stage/out).write_bytes(pixels)
    return {'file':out,'width':im.width,'height':im.height}

def build(source,engine,stage,maps,source_maps,labels,text,scripts,ow,palette_parser,q,Q):
    Q['conditionFlag']=0x602F
    before_objects=sum(len(m['objects']) for m in maps.values())
    for filename in ('data/text/match_call.inc','data/text/pokedex_rating.inc','data/scripts/players_house.inc'):
        current=None
        for line in (source/filename).read_text().splitlines():
            m=re.match(r'^(\w+)::?\s*$',line)
            if m:current=m[1];labels[current]=[]
            elif current:labels[current].append(line.strip())
    def r(op,**kw):return {'op':op,**kw}
    def k(s):return 'HNS_FIDELITY_'+s
    def script(s,rows):scripts[k(s)]=rows;return k(s)
    def msg(label,prompt=False):
        tid=k(label);text[tid]=opening.source_text(label,labels)
        return [r('message',ptr=tid),r('waitmessage'),r('yesnobox' if prompt else 'waitbuttonpress'),r('closemessage')]
    def branch(flag,s,on=True):return [r('checkflag',flag=flag),r('goto_if',cond=1 if on else 0,target=k(s))]
    def move(lid,names):return [r('applymovement',localId=lid,movementNames=['MOVEMENT_ACTION_'+x for x in names]+['MOVEMENT_ACTION_STEP_END']),r('waitmovement',localId=lid)]
    done=[r('releaseall'),r('end')]
    script('END',[r('end')]);script('FINISH',done)
    Q.update(gearFlag=GEAR,elmPhoneFlag=ELM_PHONE,elmCallFlag=ELM_CALL,expOffFlag=EXP_OFF,expItem=EXP_ITEM,windowHiddenFlag=WINDOW_HIDDEN,radioFlag=RADIO,elmPendingVar=ELM_PENDING,callPendingVar=CALL_PENDING,callNative=CALL_NATIVE,settings=settings.build(source),oakSong='MUS_HG_NEW_GAME')
    # Native save flags/vars persist contacts, settings and key-item toggles.
    q['items']['HNS_EXP_SHARE']={'id':'HNS_EXP_SHARE','index':EXP_ITEM,'name':'EXP. SHARE','price':0,'pocket':'KEY_ITEMS','fieldUse':'none','importance':1,'description':'Shares experience with the whole party. Use to switch it on or off.'}
    Q['start'].update(x=1,y=6,facing='down')
    # Exact source information window, using native paged text for accessibility.
    text[k('CLOCK_HELP')]='Information: More Options\n\nThe clock can be changed from any\nPOKéMON CENTER with no penalty.\nMake sure to check your BAG\'s KEY ITEMS\nand your OPTIONS MENU for even more\nways to customize your experience.\nEnjoy!'
    for key in ('HNS_STARTUP_CLOCK1','HNS_STARTUP_CLOCK2'):
        rows=scripts[key];rows[-2:-2]=[r('message',ptr=k('CLOCK_HELP')),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
    mom=scripts['HNS_STARTUP_MOM'];pos=next(i for i,v in enumerate(mom)if v.get('ptr')=='HNS_STARTUP_NewBarkTown_PlayersHouse_1F_Text_WearTheseRunningShoes')
    scripts['HNS_STARTUP_MOM']=mom[:pos]+[r('playfanfare',songName='MUS_HG_POKEGEAR_REGISTERED')]+msg('NewBarkTown_PlayersHouse_1F_Text_ObtainedPokeGear')+[r('waitfanfare'),r('setflag',flag=GEAR),r('setflag',engineFlagName='FLAG_SYS_POKENAV_GET')]+msg('NewBarkTown_PlayersHouse_1F_Text_ExplainPokeGear')+mom[pos:]
    town='EM_HNS_NEW_BARK_TOWN_HNS';raw=source_maps[maps[town]['hnsSourceId']]['object_events']
    for lid,name,flag in [(2,'LASS',0),(3,'WINDOW',WINDOW_HIDDEN)]:
        world_trainers.add_object(source,stage,maps,town,raw[lid-1],lid-1,k(name),ow,palette_parser,scripted_movement=lid==3,flag=flag)
    script('LASS',[r('lockall'),r('faceplayer')]+branch(opening.RECEIVED,'LASS_AFTER')+msg('NewBarkTown_Text_LassState2')+done)
    script('LASS_AFTER',msg('NewBarkTown_Text_LassState3')+done)
    script('WINDOW',[r('lockall')]+msg('NewBarkTown_Text_Silver1')+move(3,['EMOTE_EXCLAMATION_MARK'])+[r('faceplayer')]+msg('NewBarkTown_Text_Silver2')+done)
    # Short transitions only position actors. Long scenes stay in the field VM.
    init=[{'op':'setobjectxyperm','localId':2,2:0,3:11}]+branch(opening.RECEIVED,'TOWN_AFTER')+[r('clearflag',flag=WINDOW_HIDDEN),r('end')]
    script('TOWN_INIT',init)
    script('TOWN_AFTER',[{'op':'setobjectxyperm','localId':2,2:9,3:16}]+branch(quest.EGG_RECEIVED,'WINDOW_HIDE')+[r('clearflag',flag=WINDOW_HIDDEN),r('end')])
    script('WINDOW_HIDE',[r('setflag',flag=WINDOW_HIDDEN),r('end')]);maps[town]['mapScripts']['onTransition']=k('TOWN_INIT')
    for y in (12,13,14):maps[town]['coordEvents'].append({'x':0,'y':y,'elevation':0,'var':0,'value':0,'scriptKey':k('BLOCK_EXIT')})
    script('BLOCK_EXIT',branch(opening.RECEIVED,'END')+[r('lockall')]+move(2,['EMOTE_EXCLAMATION_MARK','FACE_DOWN'])+msg('NewBarkTown_Text_LassState2')+move(255,['WALK_NORMAL_RIGHT'])+done)
    route='EM_HNS_ROUTE29_HNS';raw=source_maps[maps[route]['hnsSourceId']]['object_events']
    maps[route]['objects']=[o for o in maps[route]['objects'] if o['localId']!=1]
    world_trainers.add_object(source,stage,maps,route,raw[0],0,k('GRASS_MAN'),ow,palette_parser)
    script('GRASS_MAN',[r('lockall'),r('faceplayer')]+branch(quest.EGG_DELIVERED,'GRASS_TUTORIAL')+msg('Route29_Text_OldMan1')+done)
    script('GRASS_TUTORIAL',msg('Route29_Text_OldMan2',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('GRASS_YES'))]+msg('Route29_Text_OldManDeclined')+done)
    script('GRASS_YES',msg('Route29_Text_OldManExplanation')+done)
    lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS'
    # Elm must stay at his initial mark until he registers his number.
    prev=scripts[scenes.PREFIX+'LAB_COMPUTER'];scripts[scenes.PREFIX+'LAB_COMPUTER']=branch(ELM_PHONE,'LAB_COMPUTER_DONE')+[r('setvar',var=ELM_PENDING,value=1),r('end')]
    script('LAB_COMPUTER_DONE',prev)
    scripts[scenes.PREFIX+'LAB_INIT'].insert(0,r('setvar',var=ELM_PENDING,value=0))
    for x in (5,6,7):maps[lab]['coordEvents'].append({'x':x,'y':8,'elevation':0,'var':ELM_PENDING,'value':1,'scriptKey':k('ELM_WAIT')})
    script('ELM_WAIT',[r('lockall')]+msg('NewBarkTown_Lab_Text_ElmWhereGoing')+move(255,['WALK_NORMAL_UP'])+[r('goto',target=k('ELM_DIRECTIONS'))])
    directions=msg('NewBarkTown_Lab_Text_ElmDirections1_Register')+[r('playfanfare',songName='MUS_HG_POKEGEAR_REGISTERED')]+msg('NewBarkTown_Lab_Text_RegisteredElm')+[r('waitfanfare'),r('setflag',flag=ELM_PHONE),r('setvar',var=ELM_PENDING,value=0)]+msg('NewBarkTown_Lab_Text_ElmDirections2')+move(2,['WALK_NORMAL_UP','WALK_NORMAL_LEFT','WALK_NORMAL_LEFT','WALK_NORMAL_LEFT','FACE_UP'])+[r('compare_var_to_value',var=0x800C,value=4),r('goto_if',cond=1,target=k('FINISH')),r('setflag',flag=Q['conditionFlag'])]+done
    script('ELM_DIRECTIONS',directions)
    old=scripts['HNS_OPENING_ELM_AFTER'];scripts['HNS_OPENING_ELM_AFTER']=branch(ELM_PHONE,'ELM_AFTER_DONE')+[r('goto',target=k('ELM_DIRECTIONS'))];script('ELM_AFTER_DONE',old)
    q.setdefault('changedPriorScripts',[]).append('HNS_OPENING_ELM_AFTER')
    # Starter scripts arm the exit independently of map re-entry.
    for key,rows in scripts.items():
        if key.startswith('HNS_OPENING_') and key.endswith('_GIFT') and any(v.get('flag')==opening.RECEIVED for v in rows):
            at=next(i for i,v in enumerate(rows)if v.get('flag')==opening.RECEIVED)
            rows.insert(at+1,r('setvar',var=ELM_PENDING,value=1));q['changedPriorScripts'].append(key)
    # Incoming disaster call on returning from Mr. Pokémon, exact source Route30.
    route='EM_HNS_ROUTE30_HNS';oldinit=maps[route]['mapScripts'].get('onTransition')
    script('CALL_INIT',([r('call',target=oldinit)] if oldinit else [])+[r('setvar',var=CALL_PENDING,value=0)]+branch(ELM_CALL,'END')+branch(quest.EGG_RECEIVED,'CALL_ARM')+[r('end')])
    script('CALL_ARM',[r('setvar',var=CALL_PENDING,value=1),r('end')])
    maps[route]['mapScripts']['onTransition']=k('CALL_INIT');maps[route]['mapScripts'].setdefault('onFrame',[]).append({'var':CALL_PENDING,'value':1,'script':k('ELM_DISASTER')})
    script('ELM_DISASTER',[r('lockall'),r('setvar',var=CALL_PENDING,value=0),r('callnative',fn=CALL_NATIVE),r('waitstate'),r('setflag',flag=ELM_CALL)]+done)
    Q['disasterText']=opening.source_text('Route30_Text_Elm_Disaster',labels)
    Q['momCall']=opening.source_text('MatchCall_Text_Mom3',labels)
    Q['elmCalls']={name:opening.source_text('gElmDexRatingText_'+name,labels) for name in ('GoFindMrPokemon','Robbery','AreYouCurious')}
    Q['elmCalls']['AreYouCuriousNational']=opening.source_text('gElmDexRatingText_AreYouCuriousNational',labels)
    Q['elmRatingTexts']={name:opening.source_text(name,labels) for name in labels if name.startswith(('gJohtoDexRatingText_','gNationalDexRatingText_'))}
    Q['elmCountTexts']={name:opening.source_text('gBirchDexRatingText_'+name,labels) for name in ('SoYouveSeenAndCaught','OnANationwideBasis')}
    Q['elmAckDexFlag']=0x602E
    Q['resetClockNative']=0x484E5308
    script('RESET_CLOCK',[r('lockall')]+msg('PlayersHouse_2F_Text_ClockChange')+[r('callnative',fn=Q['resetClockNative']),r('waitstate')]+done)
    Q['centerClockCount']=0
    for mid,m in maps.items():
        if 'POKEMON_CENTER' not in mid:continue
        for ev in source_maps[m['hnsSourceId']].get('bg_events',[]):
            if 'WallClock' in ev.get('script',''):
                m['bgEvents']=[b for b in m['bgEvents'] if (b['x'],b['y'])!=(ev['x'],ev['y'])]
                m['bgEvents'].append({'x':ev['x'],'y':ev['y'],'elevation':ev['elevation'],'kind':0,'scriptKey':k('RESET_CLOCK')});Q['centerClockCount']+=1

    # Actual source title themes, palette and index bitmaps feed native renderer.
    popup=(source/'src/map_name_popup.c').read_text();theme_sections=dict(re.findall(r'\[(MAPSEC_\w+)\]\s*=\s*(MAPPOPUP_THEME_\w+)',popup.split('#if IS_HNS\nstatic const u8 sMapSectionToThemeId')[1].split('#else')[0]))
    tables={}
    for table in ('Table','OutlineTable','PaletteTable'):
        block=popup.split('sMapPopUp_'+table)[1].split('\n};')[0]
        tables[table]=dict(re.findall(r'\[(MAPPOPUP_THEME_\w+)\]\s*=\s*INCBIN_U\d+\("([^"]+)"\)',block))
    Q['areaThemes']={};Q['popupPalettes']={};Q['popupFiles']={}
    for mid,m in maps.items():
        sec=source_maps[m['hnsSourceId']]['region_map_section'];theme=theme_sections.get(sec,'MAPPOPUP_THEME_WOOD');name='hns_'+theme.removeprefix('MAPPOPUP_THEME_').lower();Q['areaThemes'][str(m['regionMapSectionId'])]=name
        if name in Q['popupPalettes']:continue
        palpath=tables['PaletteTable'][theme].replace('.gbapal','.pal');palette_file=source/palpath
        if palette_file.exists():pal=palette_parser(palette_file)
        else:
            rgb=Image.open(palette_file.with_suffix('.png')).getpalette();pal=[(rgb[i*3]//8)|((rgb[i*3+1]//8)<<5)|((rgb[i*3+2]//8)<<10) for i in range(16)]
        Q['popupPalettes'][name]=pal
        for tab,suffix in [('Table',''),('OutlineTable','_outline')]:
            im=Image.open(source/tables[tab][theme].replace('.4bpp','.png'));assert im.size==(80,24) and im.mode=='P'
            out='popup/'+name+suffix+'.idx';(stage/out).parent.mkdir(exist_ok=True);(stage/out).write_bytes(im.tobytes());Q['popupFiles']['chrome/map_popup/'+name+suffix+'.idx']=out
    Q['portraits']['oak']=image(source,stage,'graphics/oak_speech_hns/oak_hns.png','startup_oak.rgba',palette_parser,'graphics/oak_speech_hns/oak_hns.pal')
    Q['backdrops']=backdrops(source,stage,palette_parser)
    Q['battleBacks']={}
    for gender,name in [(0,'gold'),(1,'kris')]:
        info=image(source,stage,'graphics/trainers/back_pics/'+name+'_hns.png','startup_back_'+str(gender)+'.rgba',palette_parser,'graphics/trainers/back_pics/'+name+'_hns.pal');assert info['width']==64 and info['height']==256
        Q['battleBacks'][str(gender)]=info
    # HnS is Pokenav-backed: map, phone, condition/ribbons, unlocked radio.
    Q['gearMaps']={name:region_map(source,stage,name) for name in ('johto','kanto')}
    section_data=json.loads((source/'src/data/region_map/region_map_sections.json').read_text())
    sections={s['id']:s for s in section_data['map_sections']}
    sections.update({s['id']:s for s in section_data['hns_map_sections']})
    Q['sections']=[s for s in sections.values() if all(k in s for k in ('x','y','width','height'))]
    Q['sectionRegions']={}
    for m in maps.values():
        raw=source_maps[m['hnsSourceId']]
        m['hnsSection']=raw['region_map_section'];m['hnsRegion']=raw.get('region','')
        if m['hnsRegion'] in ('REGION_JOHTO','REGION_KANTO'):
            Q['sectionRegions'][m['hnsSection']]=m['hnsRegion'].removeprefix('REGION_').lower()
    for m in maps.values():
        if not m['hnsRegion'] and m['hnsSection'] in Q['sectionRegions']:
            m['hnsRegion']='REGION_'+Q['sectionRegions'][m['hnsSection']].upper()
    # Radio has its source Goldenrod quiz gate, not a free startup unlock.
    radio='EM_HNS_GOLDENROD_CITY_RADIO_TOWER_1F_HNS';raw=source_maps[maps[radio]['hnsSourceId']]['object_events'];idx=next(i for i,o in enumerate(raw)if o['script']=='RadioTower1F_EventScript_Reception')
    maps[radio]['objects']=[o for o in maps[radio]['objects'] if o['localId']!=idx+1]
    world_trainers.add_object(source,stage,maps,radio,raw[idx],idx,k('RADIO_QUIZ'),ow,palette_parser)
    script('RADIO_QUIZ',[r('lockall'),r('faceplayer')]+msg('RadioTower1F_Text_ReceptionistWelcome')+branch(RADIO,'RADIO_DONE')+msg('RadioTower1F_Text_RadioCardWomanOfferQuiz',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('QUIZ1'))]+msg('RadioTower1F_Text_DeclineQuiz')+done)
    for i,answer in enumerate((1,1,0,1,0),1):
        script('QUIZ'+str(i),msg('RadioTower1F_Text_QuizQuestion'+str(i),True)+[r('compare_var_to_value',var=opening.RESULT,value=answer),r('goto_if',cond=1,target=k('QUIZ'+str(i+1) if i<5 else 'QUIZ_SUCCESS'))]+msg('RadioTower1F_Text_WrongAnswer')+done)
    # Labels audited below against the source, no invented quiz text.
    script('QUIZ_SUCCESS',msg('RadioTower1F_Text_QuizWin')+[r('setflag',flag=RADIO),r('playfanfare',songName='MUS_HG_POKEGEAR_REGISTERED')]+msg('RadioTower1F_Text_PokegearRadio')+[r('waitfanfare')]+done)
    script('RADIO_DONE',msg('RadioTower1F_Text_ReceptionistNoTours')+done)
    radio_src=(source/'src/pokenav_radio.c').read_text();radio_text=(source/'src/data/text/radio_strings.h').read_text()
    literals={name:json.loads('"'+value+'"') for name,value in re.findall(r'static const u8 (\w+)\[\]\s*=\s*_\("((?:\\.|[^"\\])*)"\)',radio_text)}
    songs=dict(re.findall(r'\[(RADIO_STATION_\w+)\]\s*=\s*(MUS_\w+)',radio_src))
    Q['radioStations']=[]
    for pos,station,name in re.findall(r'\.tuningPos\s*=\s*(\d+),\s*\.station\s*=\s*(RADIO_STATION_\w+),\s*\.name\s*=\s*(\w+)',radio_src):
        token=station.removeprefix('RADIO_STATION_');region='johto' if token in ('POKEMON_TALK','POKEMON_MUSIC','LUCKY_CHANNEL','BUENAS_PASSWORD','UNOWN') else 'later'
        message=literals.get('sRadioText_OPT_Intro','') if token=='POKEMON_TALK' else 'Station rewards and encounter effects are still being ported.'
        Q['radioStations'].append({'id':token,'position':int(pos),'name':literals[name],'song':songs[station],'region':region,'text':message})
    Q['limits']=['All source challenge/options pages are present; pending effects are labeled and saved.','Pokégear map/clock, Mom/Elm calls and initial incoming story call are functional. Later contacts/rematches and radio reward/encounter effects remain in progress.','Source party experience ratios are implemented; expanded HnS scaling/battle rules remain in progress.']
    ow['limits']='Source opening and initial Pokégear story calls are implemented. Nicknames, followers, expanded challenge/battle rules and later phone/story services remain in progress; unsupported encounters/teams are audited intact.'
    import polish
    polish.build(source,stage,maps,source_maps,labels,text,scripts,ow,palette_parser,q,Q)
    import gameplay
    Q['rules']=gameplay.build(source,engine,stage,maps,labels,text,scripts,q,Q)
    Q['extraObjectCount']=sum(len(m['objects']) for m in maps.values())-before_objects
    q['changedPriorScripts']=sorted(set(q.get('changedPriorScripts',[]))|{'HNS_SCENE_LAB_INIT','HNS_SCENE_LAB_COMPUTER','HNS_STARTUP_CLOCK1','HNS_STARTUP_CLOCK2','HNS_STARTUP_MOM'})
    experience_module(source,engine,stage)
    clock=(engine/'src/ui/game3/rse/wall_clock.lua').read_text().replace('data/generated/gba/wallclock/manifest.lua missing from the cache','native wall clock assets are missing from the imported game')
    clock=clock.replace('if inp.new.a or inp.new.b then self.state = "view_fade_out" end','if inp.new.r then self.mode=WallClock.MODE.SET;self.state="set_input" elseif inp.new.a or inp.new.b then self.state = "view_fade_out" end')
    (stage/'hns_wall_clock.lua').write_text('-- Derived from native wall_clock.lua; see GEN1RECOMP_LICENSE.md.\n'+clock)

def experience_module(source,engine,stage):
    src=(engine/'src/core/game3/battle/experience.lua').read_text()
    cfg=(source/'include/config/battle.h').read_text();nums={k:int(v) for k,v in re.findall(r'#define B_EXPALL_(\w+)\s+(\d+)',cfg)}
    src=src.replace('return mon and (tonumber(mon.species or mon.speciesId)', 'return mon and not (mon.isEgg or mon.egg or mon.isBadEgg) and (tonumber(mon.species or mon.speciesId)')
    start=src.index('  local function has_share(mon)');end=src.index('  local viaSentIn',start)
    src=src[:start]+'''  local function has_share(mon) return alive(mon) and not (mon.isEgg or mon.egg) end
'''+src[end:]
    start=src.index('  local exp, shareExp');end=src.index('\n  local friendshipCtx',start)
    src=src[:start]+f'''  if isTrainer then calculated=math.floor(calculated*150/100) end
  local exp=math.max(1,math.floor(calculated*{nums['PARTICIPANT_NUM']}/math.max(1,viaSentIn*{nums['PARTICIPANT_DEN']})))
  if viaSentIn==1 and viaExpShare<=1 then exp=math.max(1,calculated) end
  local shareExp=math.floor(calculated*{nums['NONPARTICIPANT_NUM']}/{nums['NONPARTICIPANT_DEN']})
  if shareExp==0 and calculated~=0 then shareExp=1 end
'''+src[end:]
    src=src.replace('if share then amount = amount + shareExp end','if share and not sentIn[pi] then amount = shareExp end')
    src=src.replace('if isTrainer then amount = math.floor(amount * 150 / 100) end','-- Trainer multiplier applied before source splitting.')
    (stage/'hns_experience.lua').write_text('-- Derived from native experience.lua; see GEN1RECOMP_LICENSE.md.\n'+src)


def backdrops(source,stage,palette_parser):
    root=source/'graphics/oak_speech_hns';im=Image.open(root/'shadow_hns.png');pix=im.tobytes();cols=im.width//8
    tiles=[]
    for ty in range(im.height//8):
        for tx in range(cols):tiles.append(bytes(pix[(ty*8+y)*im.width+tx*8+x] for y in range(8) for x in range(8)))
    cells=struct.unpack('<640H',(root/'map_hns.bin').read_bytes())
    pals=palette_parser(root/'bg0_hns.pal')+palette_parser(root/'bg1_hns.pal');grad=palette_parser(root/'bg2_hns.pal')
    result={}
    for state in range(9):
        pal=pals[:];pal[1:9]=grad[state:state+8];raw=bytearray()
        for y in range(160):
            for x in range(256):
                cell=cells[y//8*32+x//8];tile=tiles[cell&1023];xx=x%8;yy=y%8
                if cell&0x400:xx=7-xx
                if cell&0x800:yy=7-yy
                v=tile[yy*8+xx]+(cell>>12)*16;c=pal[v]
                raw.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255))
        filename='startup_bg_'+str(state)+'.rgba';(stage/filename).write_bytes(raw);result[str(state)]={'file':filename,'width':256,'height':160}
    return result


def region_map(source,stage,name):
    root=source/'graphics/pokenav/region_map';im=Image.open(root/('map_'+name+'.png'));raw=im.tobytes();cols=im.width//8
    tiles=[bytes(raw[(ty*8+y)*im.width+tx*8+x] for y in range(8) for x in range(8)) for ty in range(im.height//8) for tx in range(cols)]
    cells=(root/('map_'+name+'.bin')).read_bytes();assert len(cells)==4096
    rows=(root/('map_'+name+'.pal')).read_text().splitlines();rgb=[tuple(map(int,l.split()))for l in rows[3:3+int(rows[2])]];assert len(rgb)==int(rows[2])
    pal=[(0,0,0)]*112+rgb+[(0,0,0)]*(144-len(rgb))
    rgba=bytearray()
    for y in range(160):
        for x in range(240):
            v=tiles[cells[y//8*64+x//8]][y%8*8+x%8];c=pal[v];rgba.extend((*[round((v//8)*255/31)for v in c],255))
    filename='gear/map_'+name+'.rgba';(stage/filename).parent.mkdir(exist_ok=True);(stage/filename).write_bytes(rgba)
    return {'file':filename,'width':240,'height':160}
