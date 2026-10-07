"""Reviewed Violet/Sprout Tower progression, appended to stable world IDs."""
import json
import opening
import quest
import world_trainers

SILVER_HIDDEN=0x6018
FLASH_GIFT=0x6019
ZEPHYR=0x601A
ROOST_GIFT=0x601B
TOWER_STAGE=0x7007
ROOST_ITEM=901
ROOST_MOVE=901

def build(source,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,trainers,prepared,q):
    def key(name):return 'HNS_CAMPAIGN_'+name
    def r(op,**kw):return {'op':op,**kw}
    finish=[r('releaseall'),r('end')]
    def script(name,rows):scripts[key(name)]=rows;return key(name)
    def msg(label):
        tid=key(label);text[tid]=opening.source_text(label,labels)
        return [r('message',ptr=tid),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
    def branch(flag,target,on=True):return [r('checkflag',flag=flag),r('goto_if',cond=1 if on else 0,target=key(target))]
    def success(target):return [r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=target)]
    def move(label,lid):
        names=[]
        for line in labels[label]:
            token=line.split('@',1)[0].strip().upper()
            if not token:continue
            if token in ('WALK_UP','WALK_DOWN','WALK_LEFT','WALK_RIGHT'):token=token.replace('WALK_','WALK_NORMAL_',1)
            names.append('MOVEMENT_ACTION_'+token)
        return [r('applymovement',localId=lid,movementNames=names),r('waitmovement',localId=lid)]
    objects=[];battles=[]
    def obj(mid,index,name,**extra):
        event=source_maps[maps[mid]['hnsSourceId']]['object_events'][index]
        world_trainers.add_object(source,stage,maps,mid,event,index,key(name),opening_data,palette_parser,**extra)
        objects.append({'map':mid,'localId':index+1})
    def trainer(label,defeat):
        record=world_trainers.roster(label,prepared);tid=prepared['ids'][label]
        record['dialogs']={'defeat':opening.source_text(defeat,labels)}
        trainers['records'][str(tid)]=record
        pid=record['pic']
        if str(pid) not in trainers['portraits']:trainers['portraits'][str(pid)]=world_trainers.portrait(source,prepared['rosters'][label]['header']['Pic'],pid,stage,palette_parser)
        tid_text=key(defeat);text[tid_text]=record['dialogs']['defeat']
        battles.append({'source':label,'trainerId':tid})
        return tid,[r('trainerbattle',type=3,trainer=tid,defeatText=tid_text)]
    healthy=[r('callnative',fn=quest.PARTY_NATIVE)]+success(quest.PREFIX+'RIVAL_NO_PARTY')
    lock=[r('lockall'),r('faceplayer')]
    tower='EM_HNS_SPROUT_TOWER_3F_HNS'
    obj(tower,3,'LI');obj(tower,4,'SILVER_TALK',scripted_movement=True,flag=SILVER_HIDDEN)
    script('SILVER_TALK',finish)
    script('TOWER_INIT',branch(SILVER_HIDDEN,'TOWER_AFTER')+[r('setvar',var=TOWER_STAGE,value=0),r('setobjectxyperm',localId=5,x=11,y=6),r('end')])
    script('TOWER_AFTER',[r('setvar',var=TOWER_STAGE,value=1),r('end')])
    maps[tower]['mapScripts']['onTransition']=key('TOWER_INIT')
    for x,side in [(13,'LEFT'),(14,'RIGHT')]:
        maps[tower]['coordEvents'].append({'x':x,'y':7,'elevation':0,'var':TOWER_STAGE,'value':0,'scriptKey':key('SILVER_'+side)})
        script('SILVER_'+side,[r('lockall'),r('playbgm',songName='MUS_HG_ENCOUNTER_RIVAL')]+move('SproutTower_3F_Movement_Silver1',5)
               +msg('SproutTower_Text_ElderLecturesRival')+move('Common_Movement_ExclamationMark',5)
               +move('SproutTower_3F_Movement_Silver'+side.title(),5)+msg('SproutTower_Text_RivalOnlyCaresStrong')
               +msg('SproutTower_Text_RivalUsedEscapeRope')+move('SproutTower_3F_Movement_EscapeRope',5)
               +[r('fadescreen',mode=1),r('setflag',flag=SILVER_HIDDEN),r('removeobject',localId=5),r('fadescreen',mode=0),r('fadedefaultbgm'),r('setvar',var=TOWER_STAGE,value=1)]+finish)
    li,li_battle=trainer('TRAINER_LI_HNS','SproutTower_Text_SageLi_Beaten')
    script('LI',lock+branch(FLASH_GIFT,'LI_AFTER')+branch(0x500+li,'LI_GIFT')+healthy+msg('SproutTower_Text_SageLi_Seen')+li_battle
           +branch(0x500+li,'FINISH',False)+[r('goto',target=key('LI_GIFT'))])
    script('LI_GIFT',msg('SproutTower_Text_SageLi_TakeFlash')+[r('additem',itemName='ITEM_HM05',quantity=1)]+success(quest.PREFIX+'BAG_FULL')
           +[r('setflag',flag=FLASH_GIFT),r('playfanfare',songName='MUS_HG_OBTAIN_TMHM'),r('waitfanfare')]+msg('SproutTower_Text_SageLi_FlashExplain')+finish)
    script('LI_AFTER',msg('SproutTower_Text_SageLi_AfterBattle')+finish)
    gym='EM_HNS_VIOLET_CITY_GYM_HNS'
    obj(gym,0,'FALKNER');obj(gym,3,'GYM_GUIDE')
    falkner,f_battle=trainer('TRAINER_FALKNER_1_HNS','VioletGym_Text_Falkner_WinLoss')
    script('FALKNER',lock+branch(ROOST_GIFT,'FALKNER_AFTER')+branch(ZEPHYR,'FALKNER_GIFT')+branch(0x500+falkner,'FALKNER_BADGE')+healthy
           +msg('VioletGym_Text_Falkner_Intro')+f_battle+branch(0x500+falkner,'FINISH',False)+[r('goto',target=key('FALKNER_BADGE'))])
    badge=[r('setflag',flag=ZEPHYR),r('setflag',engineFlagName='FLAG_BADGE01_GET')]
    for label in ('TRAINER_ABE_HNS','TRAINER_ROD_HNS'):badge.append(r('setflag',flag=0x500+prepared['ids'][label]))
    script('FALKNER_BADGE',badge+msg('VioletGym_Text_ReceivedZephyrBadge')+[r('playfanfare',songName='MUS_HG_OBTAIN_BADGE'),r('waitfanfare')]
           +msg('VioletGym_Text_Falkner_BadgeExplain')+[r('goto',target=key('FALKNER_GIFT'))])
    text[key('ROOST_RECEIVED')]='{PLAYER} received TM51 ROOST!'
    script('FALKNER_GIFT',[r('additem',item=ROOST_ITEM,quantity=1)]+success(quest.PREFIX+'BAG_FULL')+[r('setflag',flag=ROOST_GIFT),r('message',ptr=key('ROOST_RECEIVED')),r('waitmessage'),r('playfanfare',songName='MUS_HG_OBTAIN_TMHM'),r('waitfanfare'),r('waitbuttonpress'),r('closemessage')]
           +msg('VioletGym_Text_Falkner_TMExplain')+finish)
    script('FALKNER_AFTER',msg('VioletGym_Text_Falkner_AfterFight')+finish)
    script('GYM_GUIDE',lock+branch(ZEPHYR,'GYM_GUIDE_AFTER')+msg('VioletGym_Text_GymGuide_Intro')+finish)
    script('GYM_GUIDE_AFTER',msg('VioletGym_Text_GymGuide_Win')+finish)
    script('STATUE',[r('lockall')]+branch(ZEPHYR,'STATUE_AFTER')+msg('VioletCity_Gym_Text_GymStatue')+finish)
    script('STATUE_AFTER',msg('VioletCity_Gym_Text_GymStatueCertified')+finish)
    maps[gym]['bgEvents'] += [{'x':x,'y':17,'elevation':0,'kind':0,'scriptKey':key('STATUE')} for x in (6,12)]
    # Source ball pickups on all three floors use guarded, persistent grants.
    pickups=[];nextflag=0x601C
    for mid in ('EM_HNS_SPROUT_TOWER_1F_HNS','EM_HNS_SPROUT_TOWER_2F_HNS',tower):
        for i,event in enumerate(source_maps[maps[mid]['hnsSourceId']]['object_events']):
            lines=[line.strip() for line in labels.get(event['script'],[]) if line.strip()]
            if len(lines)!=2 or not lines[0].startswith('finditem ') or lines[1]!='end':continue
            import re
            item=re.fullmatch(r'finditem (ITEM_\w+)',lines[0])[1];flag=nextflag;nextflag+=1
            name='PICKUP_'+str(flag);obj(mid,i,name,flag=flag)
            tid=key(name+'_TEXT');text[tid]='{PLAYER} found '+item.removeprefix('ITEM_').replace('_',' ')+'!'
            script(name,[r('lockall')]+branch(flag,'FINISH')+[r('additem',itemName=item,quantity=1)]+success(quest.PREFIX+'BAG_FULL')+[r('setflag',flag=flag),r('removeobject',localId=i+1),r('playfanfare',songName='MUS_HG_OBTAIN_ITEM'),r('waitfanfare'),r('message',ptr=tid),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]+finish)
            pickups.append({'map':mid,'localId':i+1,'flag':flag,'itemName':item})
    script('FINISH',finish)
    q['items']['HNS_TM_ROOST']={'id':'HNS_TM_ROOST','index':ROOST_ITEM,'name':'TM51 ROOST','price':0,'pocket':'TM_HM','fieldUse':'tm','importance':0,'registrability':0,'battleUsage':0,'description':'Restores half of the maximum HP. The user rests its wings.'}
    learnables=json.loads((source/'src/data/pokemon/all_learnables.json').read_text())
    q['limits']='Source opening scenes, rival naming, Sprout Tower/Silver/Li/Flash and Violet Gym/Falkner/Zephyr/TM51 ROOST are bridged. Later campaign, phone calls and expanded battle data remain in progress.'
    return {'flags':{'silverHidden':SILVER_HIDDEN,'flashGift':FLASH_GIFT,'zephyr':ZEPHYR,'roostGift':ROOST_GIFT},'vars':{'towerStage':TOWER_STAGE},'objects':objects,'battles':battles,'pickups':pickups,
            'roostItem':ROOST_ITEM,'roostMove':ROOST_MOVE,'roostSpecies':[s for s,moves in sorted(learnables.items()) if 'MOVE_ROOST' in moves and s in prepared['known']['species']]}
