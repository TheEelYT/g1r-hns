"""Reviewed source opening choreography; persistent port state remains stable."""
import opening
import struct
import quest
import world_trainers

COP_HIDDEN=0x6013
POLICE_DONE=0x6014
MR_PENDING=0x7004
LAB_STAGE=0x7005
POLICE_PENDING=0x7006
NAME_NATIVE=0x484E5304
ALIGN_NATIVE=0x484E5305
PREFIX='HNS_SCENE_'

def build(source,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,q):
    def k(n):return PREFIX+n
    def r(op,**kw):return {'op':op,**kw}
    def script(n,rows):scripts[k(n)]=rows;return k(n)
    def message(label,prompt=False):
        tid=k(label);text[tid]=opening.source_text(label,labels)
        return [r('message',ptr=tid),r('waitmessage'),r('yesnobox' if prompt else 'waitbuttonpress'),r('closemessage')]
    def branch(flag,name,on=True):return [r('checkflag',flag=flag),r('goto_if',cond=1 if on else 0,target=k(name))]
    def move(label,lid):
        names=[]
        for line in labels[label]:
            name=line.split('@',1)[0].strip().upper()
            if not name:continue
            if name.startswith('WALK_IN_PLACE_') and not any(speed in name for speed in ('NORMAL','FAST','SLOW')):name=name.replace('WALK_IN_PLACE_','WALK_IN_PLACE_NORMAL_',1)
            if name in ('WALK_UP','WALK_DOWN','WALK_LEFT','WALK_RIGHT'):name=name.replace('WALK_','WALK_NORMAL_',1)
            names.append('MOVEMENT_ACTION_'+name)
        return [r('applymovement',localId=lid,movementNames=names),r('waitmovement',localId=lid)]
    def face(lid,d):return r('turnobject',localId=lid,direction={'down':1,'up':2,'left':3,'right':4}[d])
    def xy(lid,x,y):return {'op':'setobjectxyperm','localId':lid,2:x,3:y}
    broken={'op':'setmetatile',1:7,2:1,3:0x32B,4:1}
    finish=[r('releaseall'),r('end')]
    mr='EM_HNS_ROUTE30_MR_POKEMONS_HOUSE_HNS';lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS'
    for mid,lids in ((mr,(1,2,3)),(lab,(2,))):
        for lid in lids:
            event=source_maps[maps[mid]['hnsSourceId']]['object_events'][lid-1]
            gfx=event['graphics_id'];info=next(v for v in opening_data['sprites'].values() if v['source']==gfx)
            opening_data['sprites'][str(info['graphicsId'])]=opening.sprite(source,gfx,info['graphicsId'],stage,palette_parser)
    script('MR_INIT',[r('setvar',var=MR_PENDING,value=0)]+branch(quest.EGG_RECEIVED,'MR_AFTER')+[r('setflag',flag=quest.MR_AFTER_HIDDEN)]
           +branch(opening.RECEIVED,'MR_ARM')+[r('end')])
    script('MR_ARM',[xy(2,7,5),xy(3,8,5),r('setvar',var=MR_PENDING,value=1),r('end')])
    script('MR_AFTER',[r('clearflag',flag=quest.MR_AFTER_HIDDEN),r('end')])
    maps[mr]['mapScripts']={'onTransition':k('MR_INIT'),'onFrame':[{'var':MR_PENDING,'value':1,'script':k('MR_ENTRY')}]}
    script('MR_ENTRY',[r('lockall'),r('setvar',var=MR_PENDING,value=0)]+branch(quest.EGG_RECEIVED,'FINISH')
           +move('Common_Movement_ExclamationMark',2)+[face(2,'down')]+message('MrPokemonHouse_Text_Intro1')
           +[r('setvar',var=0x8004,value=1),r('callnative',fn=ALIGN_NATIVE),r('waitstate'),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('FINISH'))]
           +message('MrPokemonHouse_Text_Intro2')+[r('additem',item=quest.EGG_ITEM,quantity=1),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=quest.PREFIX+'BAG_FULL')]
           +message('MrPokemonHouse_Text_GotEgg')+message('MrPokemonHouse_Text_Intro3')+message('MrPokemonHouse_Text_Intro4')+[face(3,'left')]+message('MrPokemonHouse_Text_Intro5')
           +move('MrPokemonHouse_Movement_OakToPlayer',3)+[face(255,'right')]+message('MrPokemonHouse_Text_OakIntro')+message('MrPokemonHouse_Text_GetDex')
           +[r('setflag',engineFlagName='FLAG_SYS_POKEDEX_GET'),r('callnative',fn=quest.DEX_NATIVE)]
           +message('MrPokemonHouse_Text_OakParting')+move('MrPokemonHouse_Movement_OakLeave',3)+[r('removeobject',localId=3),face(255,'up')]
           +message('MrPokemonHouse_Text_Heal')+[r('callnative',fn=opening.HEAL_NATIVE),r('waitstate')]+message('MrPokemonHouse_Text_DependingOnYou')
           +move('MrPokemonHouse_Movement_MrPokemon_Leave',2)+[r('removeobject',localId=2),r('setflag',flag=quest.EGG_RECEIVED),r('clearflag',flag=quest.MR_AFTER_HIDDEN),r('addobject',localId=1),r('setvar',var=quest.RIVAL_STAGE,value=1)]+finish)
    # Three source walk-in coordinates converge before the email choreography.
    original=struct.unpack_from('<H',(stage/maps[lab]['hnsLayoutFile']).read_bytes(),24+4*(maps[lab]['width']+7))[0]
    intact={'op':'setmetatile',1:7,2:1,3:original,4:1}
    script('LAB_INIT',[intact,xy(2,6,3),face(2,'down'),r('setvar',var=LAB_STAGE,value=1),r('setvar',var=POLICE_PENDING,value=0),r('setflag',flag=COP_HIDDEN)]
           +branch(opening.ELM_READY,'LAB_CHECK_POLICE')+branch(opening.RECEIVED,'LAB_CHECK_POLICE')+[r('setvar',var=LAB_STAGE,value=0),r('end')])
    script('LAB_CHECK_POLICE',branch(quest.RIVAL_DONE,'LAB_POLICE_ARM')+branch(opening.RECEIVED,'LAB_COMPUTER')+[r('end')])
    script('LAB_COMPUTER',[xy(2,3,2),face(2,'up'),r('end')])
    script('LAB_POLICE_ARM',[broken]+branch(POLICE_DONE,'END')+[r('clearflag',flag=COP_HIDDEN),xy(7,6,4),xy(2,6,3),r('setvar',var=POLICE_PENDING,value=1),r('end')])
    maps[lab]['mapScripts']={'onTransition':k('LAB_INIT'),'onFrame':[{'var':POLICE_PENDING,'value':1,'script':k('POLICE_ENTRY')}]}
    for x,n in ((5,'ELM_LEFT'),(6,'ELM_ENTRY'),(7,'ELM_RIGHT')):
        maps[lab]['coordEvents'].append({'x':x,'y':7,'elevation':0,'var':LAB_STAGE,'value':0,'scriptKey':k(n)})
    script('ELM_LEFT',[r('lockall')]+move('NewBarkTown_Lab_Movement_WalkRight',255)+[r('goto',target=k('ELM_ENTRY'))])
    script('ELM_RIGHT',[r('lockall')]+move('NewBarkTown_Lab_Movement_WalkLeft',255)+[r('goto',target=k('ELM_ENTRY'))])
    script('ELM_ENTRY',[r('lockall'),r('setvar',var=LAB_STAGE,value=1)]+move('NewBarkTown_LabMovement_WalkToElm',255)+message('NewBarkTown_Lab_Text_ElmIntro',True)
           +[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('ELM_ACCEPT')),r('goto',target=k('ELM_REFUSE'))])
    script('ELM_REFUSE',message('NewBarkTown_Lab_Text_ElmRefused',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('ELM_ACCEPT')),r('goto',target=k('ELM_REFUSE'))])
    script('ELM_ACCEPT',message('NewBarkTown_Lab_Text_ElmAccepted')+message('NewBarkTown_Lab_Text_ElmResearchAmbitions')+move('Common_Movement_QuestionMark',2)
           +move('NewBarkTown_Lab_Movement_CheckEmail',2)+move('NewBarkTown_Lab_Movement_Look_Left',255)+message('NewBarkTown_Lab_Text_ElmGotAnEmail')
           +move('NewBarkTown_Lab_Movement_ReturnFromEmail',2)+move('NewBarkTown_Lab_Movement_Look_Up',255)+message('NewBarkTown_Lab_Text_ElmMissionFromMrPokemon')
           +[r('setflag',flag=opening.ELM_READY)]+message('NewBarkTown_Lab_Text_ElmChooseAPokemon')+finish)
    cop=source_maps[maps[lab]['hnsSourceId']]['object_events'][6]
    world_trainers.add_object(source,stage,maps,lab,cop,6,k('POLICE_TALK'),opening_data,palette_parser,scripted_movement=True,flag=COP_HIDDEN)
    script('POLICE_ENTRY',[r('lockall'),r('setvar',var=POLICE_PENDING,value=0)]+branch(POLICE_DONE,'FINISH')
           +[r('call',target=k('STOLEN_BALL')),r('setvar',var=0x8004,value=2),r('callnative',fn=ALIGN_NATIVE),r('waitstate'),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('FINISH')),face(7,'left')]+message('NewBarkTown_Lab_Text_Officer1',True)
           +[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('POLICE_NAME')),r('goto',target=k('POLICE_NO'))])
    stolen=[]
    for choice,ball in enumerate((5,6,4)):
        stolen += [r('compare_var_to_value',var=opening.STARTER_VAR,value=choice),r('goto_if',cond=1,target=k('STOLEN_'+str(ball)))]
        script('STOLEN_'+str(ball),[r('setflag',flag=0x6010+ball-4),r('removeobject',localId=ball),r('return')])
    script('STOLEN_BALL',stolen+[r('return')])
    script('POLICE_TALK',[r('lockall'),face(7,'left')]+[r('goto',target=k('POLICE_NAME'))])
    script('POLICE_NO',message('NewBarkTown_Lab_Text_OfficerNo',True)+[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=1,target=k('POLICE_NAME')),r('goto',target=k('POLICE_NO'))])
    script('POLICE_NAME',[r('callnative',fn=NAME_NATIVE),r('waitstate')]+message('NewBarkTown_Lab_Text_Officer2_1',True)
           +[r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=k('POLICE_NAME'))]+message('NewBarkTown_Lab_Text_Officer2')
           +move('NewBarkTown_Lab_Movement_CopLeaves',7)+[r('removeobject',localId=7),r('setflag',flag=COP_HIDDEN),r('setflag',flag=POLICE_DONE)]
           +move('NewBarkTown_Lab_Movement_PlayerStepsToElm',255)+branch(quest.EGG_DELIVERED,'ELM_ALREADY_DELIVERED')
           +[r('checkitem',item=quest.EGG_ITEM,quantity=1),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=quest.PREFIX+'ELM_MISSING_EGG')]
           +message('NewBarkTown_Lab_Text_ElmAfterTheft1')+message('NewBarkTown_Lab_Text_ElmAfterTheft2')+move('NewBarkTown_Lab_Movement_ElmStepBack',2)
           +message('NewBarkTown_Lab_Text_ElmAfterTheft3')+move('NewBarkTown_Lab_Movement_ElmStepForward',2)+message('NewBarkTown_Lab_Text_ElmAfterTheft4')
           +[r('removeitem',item=quest.EGG_ITEM,quantity=1),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=quest.PREFIX+'ELM_MISSING_EGG'),r('setflag',flag=quest.EGG_DELIVERED)]+finish)
    script('ELM_ALREADY_DELIVERED',message('NewBarkTown_Lab_Text_ElmStudyingEgg')+finish)
    script('FINISH',finish);script('END',[r('end')])
    q['flags'].update(policeDone=POLICE_DONE,copHidden=COP_HIDDEN)
    q['vars'].update(mrPending=MR_PENDING,labStage=LAB_STAGE,policePending=POLICE_PENDING)
    q['nameNative']=NAME_NATIVE;q['alignNative']=ALIGN_NATIVE
    q['objects'].append({'map':lab,'localId':7})
    q['limits']='Source Elm entrance/email, automatic Mr Pokemon/Oak meeting and departure, visible Silver battle, officer investigation and rival naming. Prior completed errands can name the rival once without another egg or starter. Phone calls and later campaign are unported.'
