"""Additional safe residents, appended after the stable sprite allocation."""
import re
import opening
import quest
import world_trainers

GUIDE_HIDDEN=0x6015
NEIGHBOR_HIDDEN=0x6016
BERRY_GIFT=0x6017

def build(source,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,events,q):
    added=[]
    def r(op,**kw):return {'op':op,**kw}
    finish=[r('releaseall'),r('end')]
    def msg(key,label):
        text[key]=opening.source_text(label,labels)
        return [r('message',ptr=key),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
    for mid,dest in sorted(maps.items()):
        existing={o['localId'] for o in dest['objects']}
        for index,o in enumerate(source_maps[dest['hnsSourceId']].get('object_events',[])):
            if index+1 in existing or o['flag']!='0' or o['trainer_type']!='TRAINER_TYPE_NONE':continue
            if not (0<=o['x']<dest['width'] and 0<=o['y']<dest['height']):continue
            rows=[v for line in labels.get(o['script'],[]) if (v:=line.split('@',1)[0].strip())]
            allowed={'lock','lockall','faceplayer','closemessage','release','releaseall','end','msgbox'}
            targets=[];ok=bool(rows) and rows[-1]=='end'
            for n,line in enumerate(rows):
                op=line.split()[0]
                if op not in allowed or (op=='end' and n!=len(rows)-1):ok=False;break
                if op=='msgbox':
                    m=re.fullmatch(r'msgbox (\w+), MSGBOX_(?:DEFAULT|NPC|SIGN|AUTOCLOSE)',line)
                    if not m:ok=False;break
                    targets.append(m[1])
            if not ok or not targets:continue
            # Import only newly accepted straight-line text, preserving all
            # prior script bytes and sprite IDs rather than reallocating them.
            key='HNS_RESIDENT_'+mid+'_'+str(index)
            script=[r('lockall'),r('faceplayer')]
            try:
                values=[opening.source_text(label,labels) for label in targets]
                if '+' in o['graphics_id']:continue
                world_trainers.add_object(source,stage,maps,mid,o,index,key,opening_data,palette_parser)
            except (ValueError,AttributeError):continue
            for n,value in enumerate(values):
                tid=key+'_TEXT_'+str(n);text[tid]=value
                script += [r('message',ptr=tid),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
            scripts[key]=script+finish
            events['dialogueScripts'].append(key);events['dialogueNpcCount']+=1
            added.append({'map':mid,'localId':index+1,'kind':'source dialogue'})
    for mid,lid,hide,label in [('EM_HNS_CHERRYGROVE_CITY_HOUSE2_HNS',1,GUIDE_HIDDEN,'CherrygroveCity_GuideHouse_Text_GuideGent'),('EM_HNS_NEW_BARK_TOWN_HOUSE1_HNS',2,NEIGHBOR_HIDDEN,'NewBarkTown_House1_Text_Neighbor')]:
        o=source_maps[maps[mid]['hnsSourceId']]['object_events'][lid-1];key='HNS_RESIDENT_'+mid+'_'+str(lid-1)
        scripts[key]=[r('lockall'),r('faceplayer')]+msg(key+'_TEXT',label)+finish
        world_trainers.add_object(source,stage,maps,mid,o,lid-1,key,opening_data,palette_parser,flag=hide)
        events['dialogueScripts'].append(key);events['dialogueNpcCount']+=1
        trigger=quest.EGG_RECEIVED if lid==1 else quest.EGG_DELIVERED
        init=key+'_INIT';after=init+'_AFTER'
        scripts[init]=[r('checkflag',flag=trigger),r('goto_if',cond=1,target=after),r('setflag',flag=hide),r('end')]
        scripts[after]=[r('clearflag',flag=hide),r('end')]
        maps[mid]['mapScripts']['onTransition']=init
        added.append({'map':mid,'localId':lid,'kind':'opening-state resident'})
    mid='EM_HNS_ROUTE30_HOUSE_HNS';o=source_maps[maps[mid]['hnsSourceId']]['object_events'][0];key='HNS_RESIDENT_ROUTE30_BERRY';after=key+'_AFTER'
    scripts[key]=[r('lockall'),r('faceplayer'),r('checkflag',flag=BERRY_GIFT),r('goto_if',cond=1,target=after)]+msg(key+'_INTRO','Route30_BerryHouse_Text_MonEatBerries')
    scripts[key]+=[r('additem',itemName='ITEM_CHERI_BERRY',quantity=1),r('compare_var_to_value',var=opening.RESULT,value=1),r('goto_if',cond=0,target=quest.PREFIX+'BAG_FULL'),r('setflag',flag=BERRY_GIFT),r('goto',target=after)]
    scripts[after]=msg(key+'_AFTER_TEXT','Route30_BerryHouse_Text_CheckTrees')+finish
    world_trainers.add_object(source,stage,maps,mid,o,0,key,opening_data,palette_parser)
    added.append({'map':mid,'localId':1,'kind':'one-time source CHERI BERRY'})
    # Mom's friend returns to her own house after delivery, as in the source.
    house=maps['EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS']
    for obj in house['objects']:
        if obj['localId']==2:obj['flag']=quest.EGG_DELIVERED
    q['flags'].update(guideHidden=GUIDE_HIDDEN,neighborHidden=NEIGHBOR_HIDDEN,berryGift=BERRY_GIFT)
    mid='EM_HNS_NEW_BARK_TOWN_HNS';source_objects=source_maps[maps[mid]['hnsSourceId']]['object_events']
    key='HNS_RESIDENT_NEWBARK_MAN';before=key+'_BEFORE'
    scripts[key]=[r('lockall'),r('faceplayer'),r('checkflag',flag=opening.RECEIVED),r('goto_if',cond=0,target=before)]+msg(key+'_AFTER_TEXT','NewBarkTown_Text_FatManState3')+finish
    scripts[before]=msg(key+'_BEFORE_TEXT','NewBarkTown_Text_FatManState2')+finish
    world_trainers.add_object(source,stage,maps,mid,source_objects[0],0,key,opening_data,palette_parser)
    key='HNS_RESIDENT_NEWBARK_WOOPER'
    scripts[key]=[r('lockall'),r('faceplayer'),r('playmoncry',speciesName='WOOPER',mode=0)]+msg(key+'_TEXT','NewBarkTown_Text_Wooper')+[r('waitmoncry')]+finish
    world_trainers.add_object(source,stage,maps,mid,source_objects[3],3,key,opening_data,palette_parser)
    added += [{'map':mid,'localId':1,'kind':'story-state dialogue'},{'map':mid,'localId':4,'kind':'animated source Pokémon / cry'}]
    events['specialResidentCount']=3  # Berry giver, man and Wooper; dialogue count stays straight-line.
    events['additionalResidents']=added
