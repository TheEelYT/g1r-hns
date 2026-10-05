"""Reviewed 0.6.5 opening scene and presentation corrections."""
import re
import opening
import scenes
import residents
import quest
import world_trainers
import source_ui

HELP=0x484E5309
NICKNAME=0x484E530A
PC=0x484E530B
GUIDE_HIDDEN=0x602C
GUIDE_STATE=0x700B

def build(source,stage,maps,source_maps,labels,text,scripts,ow,palette_parser,q,Q):
    def r(op,**kw):return {'op':op,**kw}
    def k(s):return 'HNS_POLISH_'+s
    def script(s,rows):scripts[k(s)]=rows;return k(s)
    def msg(label,prompt=False):
        text[k(label)]=opening.source_text(label,labels)
        return [r('message',ptr=k(label)),r('waitmessage'),r('yesnobox' if prompt else 'waitbuttonpress'),r('closemessage')]
    def apply(label,lid):
        names=[]
        for line in labels[label]:
            n=line.split('@')[0].strip().upper()
            if not n:continue
            if n in ('WALK_UP','WALK_DOWN','WALK_LEFT','WALK_RIGHT'):n=n.replace('WALK_','WALK_NORMAL_',1)
            names.append('MOVEMENT_ACTION_'+n)
        return r('applymovement',localId=lid,movementNames=names)
    def move(label,lid):return [apply(label,lid),r('waitmovement',localId=lid)]
    def together(a,b):return [apply(a,1),apply(b,255),r('waitmovement',localId=1),r('waitmovement',localId=255)]
    done=[r('releaseall'),r('end')]
    Q.update(helpNative=HELP,nicknameNative=NICKNAME,pcNative=PC,guideHiddenFlag=GUIDE_HIDDEN,guideStateVar=GUIDE_STATE,ui=source_ui.build(source,stage,palette_parser))
    disclaimer=re.search(r'sText_Disclaimer\[\].*?=\s*_\("(.*?)"\);',(source/'src/oak_speech_hns.c').read_text(),re.S)[1]
    Q['speech']['gText_HnsChallengeWarning']=disclaimer.split('{COLOR RED}',1)[1]
    # The source help screen is a single modal overlay, not a message box.
    Q['clockHelp']={'header':'Information: More Options','body':"The clock can be changed from any\nPOKéMON CENTER with no penalty.\nMake sure to check your BAG's KEY ITEMS\nand your OPTIONS MENU for even more\nways to customize your experience.\nEnjoy!"}
    for name in ('HNS_STARTUP_CLOCK1','HNS_STARTUP_CLOCK2'):
        rows=scripts[name];assert rows[-6].get('ptr')=='HNS_FIDELITY_CLOCK_HELP'
        scripts[name]=rows[:-6]+[r('callnative',fn=HELP),r('waitstate')]+done
    # Wait, then allow the player to approach Elm for the errand briefing.
    name='HNS_FIDELITY_ELM_WAIT';rows=scripts[name];scripts[name]=rows[:-1]+[r('turnobject',localId=255,direction=2)]+done
    name=scenes.PREFIX+'ELM_ACCEPT';rows=scripts[name]
    pos=next(i for i,v in enumerate(rows)if v.get('movementNames')==apply('Common_Movement_QuestionMark',2)['movementNames'])
    rows[pos:pos+2]=[r('delay',frames=30),r('playse',seName='SE_PC_LOGIN'),r('waitse'),r('playse',seName='SE_PIN'),apply('Common_Movement_QuestionMark',2),r('delay',frames=55),r('waitmovement',localId=2)]
    for a,b in [('NewBarkTown_Lab_Movement_CheckEmail','NewBarkTown_Lab_Movement_Look_Left'),('NewBarkTown_Lab_Movement_ReturnFromEmail','NewBarkTown_Lab_Movement_Look_Up')]:
        pos=next(i for i,v in enumerate(rows)if v.get('movementNames')==apply(a,2)['movementNames'])
        rows[pos:pos+4]=[apply(a,2),apply(b,255),r('waitmovement',localId=2),r('waitmovement',localId=255)]
    # Preview closes on BOTH answers. Receipt stays one-time even if naming is cancelled.
    for name in ('CHIKORITA','CYNDAQUIL','TOTODILE'):
        key=opening.PREFIX+name;rows=scripts[key];pos=next(i for i,v in enumerate(rows)if v.get('op')=='bufferstring')
        rows.insert(pos,r('showmonpic',speciesName=name,x=10,y=3))
        rows=scripts[key+'_GIFT'];rows.insert(0,r('hidemonpic'))
        pos=next(i for i,v in enumerate(rows)if v.get('op')=='givemon')
        rows.insert(pos+1,{'op':'copyvar',1:0x8005,2:opening.RESULT})
        pos=next(i for i,v in enumerate(rows)if v.get('ptr')==opening.PREFIX+'NewBarkTown_Lab_Text_ElmLetYourMonBattle')
        scripts[key+'_GIFT']=rows[:pos]+[r('compare_var_to_value',var=0x8005,value=0),r('goto_if',cond=0,target=k('FINISH'))]+msg('NewBarkTown_Lab_Text_Nickname',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('NICKNAME'))]+done
    scripts[opening.PREFIX+'DECLINE'].insert(0,r('hidemonpic'))
    script('NICKNAME',[r('callnative',fn=NICKNAME),r('waitstate')]+done)
    # Silver's source walk out / shove / return, with both actors moving together.
    scripts['HNS_FIDELITY_WINDOW']=[r('lockall')]+msg('NewBarkTown_Text_Silver1')+[r('delay',frames=60),r('playse',seName='SE_PIN')]+move('Common_Movement_ExclamationMark',3)+[r('faceplayer')]+msg('NewBarkTown_Text_Silver2')+[r('playse',seName='SE_BANG'),apply('NewBarkTown_Movement_SilverPushesPlayer',3),apply('NewBarkTown_Movement_PlayerPushedBySilver',255),r('waitmovement',localId=3),r('waitmovement',localId=255)]+move('Common_Movement_FaceOriginalDirection',3)+done
    # Cherrygrove's guide, all three entry lanes and all five tour stops.
    city='EM_HNS_CHERRYGROVE_CITY_HNS';raw=source_maps[maps[city]['hnsSourceId']]
    world_trainers.add_object(source,stage,maps,city,raw['object_events'][0],0,k('GUIDE_TALK'),ow,palette_parser,scripted_movement=True,flag=GUIDE_HIDDEN)
    for ev in raw['coord_events'][:3]:
        suffix=ev['script'].rsplit('_',1)[1].upper()
        maps[city]['coordEvents'].append({'x':ev['x'],'y':ev['y'],'elevation':0,'var':GUIDE_STATE,'value':0,'scriptKey':k('GUIDE_'+suffix)})
        intro=[r('lockall'),r('setflag',flag=residents.GUIDE_HIDDEN),r('playse',seName='SE_PIN'),apply('Common_Movement_ExclamationMark',1),r('delay',frames=55),r('waitmovement',localId=1),r('turnobject',localId=255,direction=2)]+msg('CherrygroveCity_Text_GuideGentIntro',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('GUIDE_CANCEL'))]+msg('CherrygroveCity_Text_GuideGentTourStart')
        if suffix=='TOP':intro+=move('CherryGroveCity_Movement_Trigger_Top',255)+move('CherryGroveCity_Movement_Trigger_Gent',1)
        else:
            intro+=move('CherryGroveCity_Movement_Trigger_Gent',1)
            intro+=move('CherryGroveCity_Movement_Trigger_Bottom',255) if suffix=='BOTTOM' else [r('turnobject',localId=255,direction=3)]
        script('GUIDE_'+suffix,intro+[r('goto',target=k('GUIDE_TOUR'))])
    # Talking to him from any side aligns safely to the top tour starting mark.
    script('GUIDE_TALK',[r('lockall'),r('faceplayer')]+msg('CherrygroveCity_Text_GuideGentIntro',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('GUIDE_CANCEL')),r('setvar',var=0x8004,value=3),r('callnative',fn=q['alignNative']),r('waitstate'),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('FINISH'))]+msg('CherrygroveCity_Text_GuideGentTourStart')+move('CherryGroveCity_Movement_Trigger_Top',255)+move('CherryGroveCity_Movement_Trigger_Gent',1)+[r('goto',target=k('GUIDE_TOUR'))])
    script('GUIDE_CANCEL',msg('CherrygroveCity_Text_GuideGentDecline')+[r('setvar',var=GUIDE_STATE,value=1)]+done)
    tour=[r('playbgm',songName='MUS_HG_FOLLOW_ME_2')]
    for stop,label in [('Pokecenter','Pokecenter'),('Pokemart','Mart'),('Route30','Route30'),('Sea','Sea')]:tour+=together('CherryGroveCity_Movement_'+stop,'CherryGroveCity_Movement_'+stop)+msg('CherrygroveCity_Text_GuideGent'+label)
    tour+=together('CherryGroveCity_Movement_House_Gent','CherryGroveCity_Movement_House_Player')+[r('delay',frames=20)]+msg('CherrygroveCity_Text_GuideGentMap')
    tour+=[apply('CherryGroveCity_Movement_Gent_Leave',1),r('turnobject',localId=255,direction=2),r('delay',frames=20),{'op':'opendoor',1:42,2:14},r('waitdooranim'),r('waitmovement',localId=1),r('removeobject',localId=1),{'op':'closedoor',1:42,2:14},r('waitdooranim'),r('clearflag',flag=residents.GUIDE_HIDDEN),r('setflag',flag=GUIDE_HIDDEN),r('setvar',var=GUIDE_STATE,value=1),r('fadedefaultbgm')]+done
    script('GUIDE_TOUR',tour);script('FINISH',done)
    # Existing saves past Mr. Pokémon have already bypassed the first-visit tour.
    prev=maps[city]['mapScripts'].get('onTransition');script('CITY_INIT',([r('call',target=prev)]if prev else [])+[r('checkflag',flag=quest.EGG_RECEIVED),r('goto_if',cond=0,target=k('END')),r('setflag',flag=GUIDE_HIDDEN),r('setvar',var=GUIDE_STATE,value=1),r('end')]);maps[city]['mapScripts']['onTransition']=k('CITY_INIT')
    house='EM_HNS_CHERRYGROVE_CITY_HOUSE2_HNS'
    script('GUIDE_HOUSE_INIT',[r('checkflag',flag=GUIDE_HIDDEN),r('goto_if',cond=1,target=k('GUIDE_HOUSE_SHOW')),r('setflag',flag=residents.GUIDE_HIDDEN),r('end')])
    script('GUIDE_HOUSE_SHOW',[r('clearflag',flag=residents.GUIDE_HIDDEN),r('end')]);maps[house]['mapScripts']['onTransition']=k('GUIDE_HOUSE_INIT');script('END',[r('end')])
    # Add challenge settings to source PC terminals; existing storage remains accessible.
    script('PC',[r('lockall'),r('callnative',fn=PC),r('waitstate')]+done)
    for mid,m in maps.items():
        if not ('POKECENTER_1F' in mid or mid==Q['start']['map']):continue
        for ev in source_maps[m['hnsSourceId']].get('bg_events',[]):
            if 'PC' in ev.get('script','').upper():
                existing=next((e for e in m['bgEvents'] if e['x']==ev['x'] and e['y']==ev['y']),None)
                if existing:existing['scriptKey']=k('PC')
                else:m['bgEvents'].append({'x':ev['x'],'y':ev['y'],'elevation':0,'kind':0,'scriptKey':k('PC')})
    Q['limits'][0]='Source settings dependencies, confirmation and PC difficulty locks are implemented; pending battle/rule effects are saved.'
    ow['limits']=ow['limits'].replace('Nicknames, followers','Followers')
