"""Source machines and compatibility; stable save IDs are independent of C enums."""
import json, os, re, runpy, subprocess


def build(source, dex, quest):
    prefix='#define TRUE 1\n#define FALSE 0\n#define POKEMON_HNS 1\n#include "constants/global.h"\n#include "config/general.h"\n#include "config/item.h"\n#include "config/overworld.h"\n#include "config/battle.h"\n'
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "data/items.h"\n',text=True)
    items=dict(re.findall(r'\[ITEM_(\w+)\]\s*=\s*\{(.*?)(?=\n\s*\[ITEM_|\Z)',body,re.S))
    machines=[]
    for move,label in sorted(dex['machineLabels'].items(),key=lambda r:(r[1].startswith('HM'),int(r[1][2:]))):
        kind=label[:2];number=int(label[2:]);row=items.get(label) or items[kind+'_'+move]
        item_id=(288+number if number<=50 else 901 if number==51 else 852+number)if kind=='TM'else 338+number
        price=int(re.search(r'\.price\s*=\s*(\d+)',row)[1]);importance=int(re.search(r'\.importance\s*=\s*(\d+)',row)[1])
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',row,re.S)
        assert desc,label
        description=''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',desc[1]))
        name=re.search(r'\.name\s*=\s*(?:ITEM_NAME|COMPOUND_STRING(?:_SIZE_LIMIT)?)\("([^"]+)"',row)[1]
        key='HNS_'+kind+'_'+move
        if move=='ROOST':key='HNS_TM_ROOST'
        record={'label':label,'kind':kind,'number':number,'itemId':item_id,'move':move,'key':key,'name':name,'price':price,'importance':importance,'description':description}
        machines.append(record)
        if kind=='TM'and number>50:
            quest['items'][key]={'id':key,'index':item_id,'name':name,'price':price,'importance':importance,'pocket':'TM_HM','fieldUse':'tm','registrability':0,'battleUsage':0,'description':description}
    assert len(machines)==100 and len({r['itemId']for r in machines})==100
    previous=os.getcwd()
    try:
        os.chdir(source)
        helpers=runpy.run_path(str(source/'tools/learnset_helpers/make_tutors.py'))
        special=json.loads((source/'src/data/pokemon/special_movesets.json').read_text())
        tutors=sorted({n.removeprefix('MOVE_')for n in helpers['extract_repo_tutors']()}|{n.removeprefix('MOVE_')for n in special['extraTutors']})
    finally:os.chdir(previous)
    return {'machines':machines,'tutors':tutors,'limits':'Source TM/HM catalogue, species teaching lists and tutor compatibility API. Unsupported effects cannot be taught. Tutor NPC menus, fees and unlock scripts, later machine rewards/shops and field-HM campaign access remain pending.'}


def pickups(data,source,stage,maps,source_maps,labels,text,scripts,opening,palette_parser):
    """Only exact unconditional source finditem programs; no guessed reward scripts."""
    by_name={name:r for r in data['machines']for name in ('ITEM_'+r['label'],'ITEM_'+r['kind']+'_'+r['move'])}
    result=[]
    for mid,dest in sorted(maps.items()):
        for i,obj in enumerate(source_maps[dest['hnsSourceId']].get('object_events',[])):
            lines=[v.split('@',1)[0].strip()for v in labels.get(obj.get('script'),[])if v.split('@',1)[0].strip()]
            if len(lines)!=2 or lines[1]!='end':continue
            match=re.fullmatch(r'finditem (ITEM_\w+)',lines[0])
            if not match or match[1]not in by_name:continue
            if any(o['localId']==i+1 for o in dest['objects']):continue
            if obj['graphics_id']!='OBJ_EVENT_GFX_POKE_BALL':continue
            if not str(obj['flag']).startswith('FLAG_ITEM_'):continue
            record=by_name[match[1]];flag=0x6800+len(result);key='HNS_MACHINE_PICKUP_'+str(flag)
            tid=key+'_TEXT';text[tid]='{PLAYER} found '+record['name']+'!'
            def r(op,**kw):return {'op':op,**kw}
            done=key+'_DONE';full=key+'_FULL'
            scripts[key]=[r('lockall'),r('checkflag',flag=flag),r('goto_if',cond=1,target=done),r('additem',item=record['itemId'],quantity=1),r('compare_var_to_value',var=0x800D,value=1),r('goto_if',cond=0,target=full),r('setflag',flag=flag),r('removeobject',localId=i+1),r('message',ptr=tid),r('waitmessage'),r('playfanfare',songName='MUS_HG_OBTAIN_TMHM'),r('waitfanfare'),r('waitbuttonpress'),r('closemessage'),r('goto',target=done)]
            scripts[full]=[r('message',ptr='HNS_QUEST_BAG_FULL'),r('waitmessage'),r('waitbuttonpress'),r('closemessage'),r('goto',target=done)]
            scripts[done]=[r('releaseall'),r('end')]
            from world_trainers import add_object
            add_object(source,stage,maps,mid,obj,i,key,opening,palette_parser,flag=flag)
            result.append({'map':mid,'localId':i+1,'flag':flag,'sourceFlag':obj['flag'],'itemId':record['itemId'],'sourceItem':match[1],'script':key})
    data['pickups']=result
