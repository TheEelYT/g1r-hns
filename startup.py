"""Reviewed HnS startup and corrective opening triggers."""
import json
import re
import opening
import quest
import world_trainers

HOUSE_STATE=0x7008
NEW_GAME=0x6022
CLOCK_SET=0x6023
SHOES=0x6024
CLOCK_NATIVE=0x484E5306
GB_ITEM=902
PREFIX='HNS_STARTUP_'

def build(source,engine,stage,maps,source_maps,labels,text,scripts,ow,palette_parser,q):
    def r(op,**kw):return {'op':op,**kw}
    def key(n):return PREFIX+n
    def script(n,rows):scripts[key(n)]=rows;return key(n)
    def msg(label):
        text[key(label)]=opening.source_text(label,labels)
        return [r('message',ptr=key(label)),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
    def move(label,lid):
        names=[]
        for line in labels[label]:
            token=line.split('@')[0].strip().upper()
            if not token:continue
            if token.startswith('WALK_') and not any(x in token for x in ('NORMAL','FAST','SLOW','IN_PLACE')):token=token.replace('WALK_','WALK_NORMAL_',1)
            names.append('MOVEMENT_ACTION_'+token)
        return [r('applymovement',localId=lid,movementNames=names),r('waitmovement',localId=lid)]
    def flag(f,n,yes=True):return [r('checkflag',flag=f),r('goto_if',cond=1 if yes else 0,target=key(n))]
    done=[r('releaseall'),r('end')]
    # Emerald RIVAL is gendered MAY/BRENDAN. A live string variable has no such substitution.
    for k,v in list(text.items()):
        if k.startswith(('HNS_SCENE_','HNS_QUEST_')):text[k]=v.replace('{RIVAL}','{STR_VAR_3}')
    lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS'
    # Doorway x6,y12 is the actual source potion/ball trigger. Existing Elm
    # coordinate events are state 0; this event is unconditional and checks flags.
    maps[lab]['coordEvents'].append({'x':6,'y':12,'elevation':0,'var':0,'value':0,'scriptKey':key('AIDE_CHECK')})
    script('AIDE_CHECK',flag(quest.EGG_DELIVERED,'AIDE_BALLS')+flag(opening.RECEIVED,'AIDE_POTION')+[r('end')])
    for suffix,gift,flagid in [('POTION','AIDE_POTION',quest.POTION_GIFT),('BALLS','AIDE_BALLS',quest.BALLS_GIFT)]:
        target=quest.PREFIX+gift
        # The reviewed gift core already handles full bags and one-time flags.
        original=scripts[target]
        intro_end=next(i for i,row in enumerate(original) if row['op']=='message')
        new=original[:intro_end]+move('NewBarkTown_Lab_Movement_Aide1WalkToPlayer',1)+[r('turnobject',localId=255,direction=3)]+original[intro_end:]
        # Both success and full-bag paths must return the aide to its source mark.
        new=[dict(row,target=key('AIDE_BAG_FULL')) if row.get('target')==quest.PREFIX+'BAG_FULL' else row for row in new]
        new=new[:-2]+move('NewBarkTown_Lab_Movement_Aide1LeavePlayer',1)+[r('turnobject',localId=255,direction=1)]+done
        receipt=quest.PREFIX+('POTION_RECEIVED' if suffix=='POTION' else 'BALLS_RECEIVED')
        for i,row in enumerate(new):
            if row.get('op')=='message' and row.get('ptr')==receipt:
                new.insert(i,r('playfanfare',songName='MUS_HG_OBTAIN_ITEM'))
                new.insert(i+5,r('waitfanfare'))
                break
        scripts[key('AIDE_'+suffix)]=flag(flagid,'END')+new
    script('AIDE_BAG_FULL',[r('message',ptr=quest.PREFIX+'BAG_FULL'),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]+move('NewBarkTown_Lab_Movement_Aide1LeavePlayer',1)+done)
    script('END',[r('end')])
    h2='EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_2F_HNS';h1='EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS'
    for event in source_maps[maps[h2]['hnsSourceId']]['coord_events']:
        suffix='CLOCK1' if event['x']==9 else 'CLOCK2'
        maps[h2]['coordEvents'].append({'x':event['x'],'y':event['y'],'elevation':0,'var':HOUSE_STATE,'value':0,'scriptKey':key(suffix)})
        script(suffix,flag(NEW_GAME,'END',False)+[r('lockall')]+move('NewBarkTown_PlayersHouse_2F_Movement_PlayerWalkToClock'+('1' if event['x']==9 else '2'),255)
          +msg('PlayersHouse_2F_Text_ClockIsStopped')+[r('callnative',fn=CLOCK_NATIVE),r('waitstate'),r('setflag',flag=CLOCK_SET),r('setvar',var=HOUSE_STATE,value=1)]+done)
    script('VIEW_CLOCK',[r('lockall'),r('setvar',var=0x8004,value=1),r('callnative',fn=CLOCK_NATIVE),r('waitstate'),r('setflag',flag=CLOCK_SET)]+done)
    maps[h2]['bgEvents'].append({'x':10,'y':1,'elevation':0,'kind':0,'scriptKey':key('VIEW_CLOCK')})
    for event in source_maps[maps[h1]['hnsSourceId']]['coord_events']:
        suffix='MOM1' if event['x']==9 else 'MOM2'
        maps[h1]['coordEvents'].append({'x':event['x'],'y':event['y'],'elevation':0,'var':HOUSE_STATE,'value':1,'scriptKey':key(suffix)})
        script(suffix,[r('lockall')]+move('NewBarkTown_PlayersHouse_1F_PlayerIntroMovement'+('1' if event['x']==9 else '2'),255)+[r('goto',target=key('MOM'))])
    # Source introduction places Mom at the table; retain existing old-save talk.
    script('HOUSE_INIT',flag(NEW_GAME,'HOUSE_POS')+[r('end')])
    script('HOUSE_POS',[{'op':'setobjectxyperm','localId':1,2:8,3:4},r('turnobject',localId=1,direction=3),r('end')])
    maps[h1]['mapScripts']['onTransition']=key('HOUSE_INIT')
    mom_intro=move('NewBarkTown_PlayersHouse_1F_MomMovement_1',1)+msg('NewBarkTown_PlayersHouse_1F_Text_ElmsLookingForYou')
    mom_intro+=msg('NewBarkTown_PlayersHouse_1F_Text_WearTheseRunningShoes')
    mom_intro+=[r('playfanfare',songName='MUS_HG_OBTAIN_ITEM')]+msg('NewBarkTown_PlayersHouse_1F_Text_SwitchShoesWithRunningShoes')+[r('waitfanfare'),r('setflag',engineFlagName='FLAG_SYS_B_DASH'),r('setflag',flag=SHOES)]
    mom_intro+=msg('NewBarkTown_PlayersHouse_1F_Text_ExplainRunningShoes')+move('NewBarkTown_PlayersHouse_1F_MomMovement_2',1)+[r('setvar',var=HOUSE_STATE,value=2)]+done
    script('MOM',flag(SHOES,'END')+mom_intro)
    # Allocate player sheets only after the stable 0.6.2 NPC IDs.
    avatar=[];gid=max(map(int,ow['sprites']))+1
    for state in ('NORMAL','MACH_BIKE','ACRO_BIKE','SURFING','UNDERWATER','FIELD_MOVE','FISHING','WATERING'):
        row={'state':state}
        for gender,name in [('male','GOLD'),('female','KRIS')]:
            gfx='OBJ_EVENT_GFX_'+name+'_'+state+'_HNS'
            info=opening.sprite(source,gfx,gid,stage,palette_parser)
            ow['sprites'][str(gid)]=info;row[gender]=gid;gid+=1
        avatar.append(row)
    sections=json.loads((source/'src/data/region_map/region_map_sections.json').read_text())['map_sections']
    names={x['id']:x['name'] for x in sections if 'name' in x};area={}
    for i,sec in enumerate(sorted({m['region_map_section'] for m in source_maps.values()})):
        area[sec]={'id':0x1000+i,'name':names.get(sec,sec.removeprefix('MAPSEC_').replace('_',' '))}
    for mid,m in maps.items():
        raw=source_maps[m['hnsSourceId']];sec=area[raw['region_map_section']]
        m['regionMapSectionId']=sec['id'];m['showMapName']=int(raw.get('show_map_name',False));m['hnsAreaName']=sec['name']
    # Source portraits converted without changing native trainers' IDs.
    portraits={}
    for name,pic in [('oak','PROFESSOR_OAK_FRLG'),('male','GOLD_HNS'),('female','KRIS_HNS')]:
        info=world_trainers.portrait(source,pic,60000+len(portraits),stage,palette_parser)
        portraits[name]=info
    # Oak's startup strings are outside map script includes.
    current=None
    for line in (source/'data/text/oak_speech_hns.inc').read_text().splitlines():
        match=re.match(r'^(\w+)::?\s*$',line)
        if match:current=match[1];labels[current]=[]
        elif current:labels[current].append(line.strip())
    from PIL import Image
    im=Image.open(source/'graphics/pokemon/wooper/anim_front.png')
    colors=palette_parser(source/'graphics/pokemon/wooper/normal.pal')
    pixels=bytearray()
    # Native front-animation consumes two vertical 64px frames.
    frames=im.width*im.height//4096
    for f in range(frames):
        x=f%(im.width//64)*64;y=f//(im.width//64)*64
        for v in im.crop((x,y,x+64,y+64)).tobytes():
            c=colors[v];pixels.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if v else 0))
    (stage/'startup_wooper.rgba').write_bytes(pixels)
    portraits['wooper']={'file':'startup_wooper.rgba','width':64,'height':64*frames}
    ball=Image.open(source/'graphics/balls/poke.png')
    assert ball.mode=='P' and ball.size==(16,48)
    rgb=ball.getpalette();pixels=bytearray()
    for v in ball.tobytes():
        pixels.extend((*[round((rgb[v*3+i]//8)*255/31) for i in range(3)],255 if v else 0))
    (stage/'startup_ball.rgba').write_bytes(pixels)
    speech={}
    for tail in ('Welcome','MainSpeech','AndYouAre','BoyOrGirl','WhatsYourName','SoItsPlayer','YourePlayer','AreYouReady'):
        speech['gText_Birch_'+tail]=opening.source_text('gText_Oak_'+tail,labels)
    for tail in ('WhatChallenge','ChallengeSelected'):speech['gText_Oak_'+tail]=opening.source_text('gText_Oak_'+tail,labels)
    speech['gText_ThisIsAPokemon']=json.loads('"'+re.search(r'gText_ThisIsAPokemon\[\]\s*=\s*_\("((?:\\.|[^"\\])*)"\)',(source/'src/strings.c').read_text())[1].replace(r'\p',r'\\p')+'"')
    q['items']['HNS_GB_PLAYER']={'id':'HNS_GB_PLAYER','index':GB_ITEM,'name':'GB SOUNDS','price':0,'pocket':'KEY_ITEMS','fieldUse':'none','importance':1,'description':'The GB music player. Alternate GB tracks are not yet available in this port.'}
    config={'houseState':HOUSE_STATE,'newGameFlag':NEW_GAME,'clockFlag':CLOCK_SET,'shoesFlag':SHOES,'clockNative':CLOCK_NATIVE,'gbItem':GB_ITEM,'avatars':avatar,'areas':{str(v['id']):v['name'] for v in area.values()},'portraits':portraits,'speech':speech,
      'start':{'map':h2,'x':9,'y':4,'facing':'up'},'limits':['Pokegear/phone services remain unported','Expanded HnS challenge/battle rules and alternate GB tracks remain unported; startup exposes supported native options','EXP. SHARE uses the current native held-item rules']}

    import fidelity
    fidelity.build(source,engine,stage,maps,source_maps,labels,text,scripts,ow,palette_parser,q,config)
    return config

def speech_module(engine,stage):
    src=(engine/'src/ui/game3/rse/birch_speech.lua').read_text()
    src=src.replace('data/generated/gba/birch/manifest.lua missing from the cache','native speech backdrop is missing from the imported game')
    src=src.replace('Kit.rgbaImage("data/generated/gba/pokemon/battle/ball_open/balls.rgba", 192, 48)',"HNS.image('ball')")
    src=src.replace('local Birch = {}','local Birch = {}\nlocal HNS\nfunction Birch.configure(config) HNS=config end')
    if 'function Birch.configure' not in src:raise ValueError('native speech module changed')
    src=src.replace('  local pics = man.pics','''  if HNS then
    local own={};for k,v in pairs(man) do own[k]=v end
    own.presetNames={male={'GOLD'},female={'KRIS'}};man=own
  end
  local pics = man.pics''')
    src=src.replace('self.lotadSpecies = pics.lotad.species','''if HNS then
    self.hnsOptions={textSpeed=2,battleScene=0,battleStyle=0,sound=0,buttonMode=0,frameType=0}
    self.hnsConfig=HNS
    self.sprites.birch.img=HNS.image('oak')
    self.sprites.brendan.img=HNS.image('male')
    self.sprites.may.img=HNS.image('female')
    self.sprites.lotad.img=HNS.image('wooper')
    self.sprites.lotad.frames=2
  end
  self.lotadSpecies = HNS and 194 or pics.lotad.species''')
    src=src.replace('self.printer = Kit.printer(key, {','''local speech=self.hnsConfig and self.hnsConfig.speech[key]
  if speech then
    key=require('src.core.game3.scripting.text_ir').fromAscii(speech,{dialect='emerald'})
    for _,seg in ipairs(key)do
      local n=seg.t=='ph' and seg.name:match('^PAUSE (%d+)$')
      if n then seg.t='ext';seg.cmd=8;seg.args={tonumber(n)} end
    end
  end
  self.printer = Kit.printer(key, {''')
    src=src.replace('m.func = "SlidePlatformAway2"','m.func = HNS and "HnsChallengePrompt" or "SlidePlatformAway2"',1)
    insert='''
function F.HnsChallengePrompt(self,m)
  self:print('gText_Oak_WhatChallenge')
  m.func='HnsChallengeWait'
end
function F.HnsChallengeWait(self,m,inp)
  if self:printersActive(inp) then return end
  if not (inp.new.a or inp.new.b) then return end
  self.hnsWarning=true
  self:print('gText_HnsChallengeWarning')
  m.func='HnsWarningWait'
end
function F.HnsWarningWait(self,m,inp)
  if self:printersActive(inp) then return end
  if not (inp.new.a or inp.new.b) then return end
  self.hnsWarning=false
  self.hnsMenu=HNS.settings.new('challenge')
  self.hnsSettingsOpen=true;self.showDialogue=false;self.printer=nil
  m.func='HnsSettings'
end
function F.HnsSettings(self,m,inp)
  if HNS.settings.frame(self.hnsMenu,inp) then
    self.hnsChoices=self.hnsMenu.values
    self.hnsSettingsOpen=false;self.showDialogue=true
    self:print('gText_Oak_ChallengeSelected')
    m.func='HnsChallengeDone'
  end
end
function F.HnsChallengeDone(self,m,inp)
  if self:printersActive(inp) then return end
  if inp.new.a or inp.new.b then m.func='SlidePlatformAway2' end
end
'''
    src=src.replace('function F.SlideOutOldGenderSprite',insert+'\nfunction F.SlideOutOldGenderSprite',1)
    src=src.replace('Audio.playSong(Kit.song("MUS_ROUTE122"), { restart = true })','Audio.playSong(HNS and HNS.oakSong or Kit.song("MUS_ROUTE122"), { restart = true })')
    src=src.replace('trainerIdLower = self.trainerIdLower,','trainerIdLower = self.trainerIdLower,\n    hnsOptions = self.hnsOptions,\n    hnsChoices = self.hnsChoices,')
    src=src.replace('self.printer:draw(w.left * 8, w.top * 8 + 1, { colors = Kit.messageColors(),', 'self.printer:draw(w.left * 8, w.top * 8 + 1, { colors = self.hnsWarning and Kit.messageColors("message_box",4,1,5) or Kit.messageColors(),')
    marker='  if self.ball and not self.ball.invisible and self.ball.img then'
    src=src.replace(marker,"  if self.hnsSettingsOpen then HNS.settings.draw(self.hnsMenu);return end\n"+marker,1)
    src=src.replace('local img = Kit.image(layer.variants[tostring(self.gradState)])',"local img = HNS and HNS.image('bg'..tostring(self.gradState)) or Kit.image(layer.variants[tostring(self.gradState)])")
    src=src.replace('local q = frameQuad(s.img, s.frame or 0, w, h)','local q = frameQuad(s.img, (s.frame or 0) % (s.frames or 1), w, h)')
    (stage/'hns_oak_speech.lua').write_text('-- Derived from native birch_speech.lua; see GEN1RECOMP_LICENSE.md.\n'+src)
