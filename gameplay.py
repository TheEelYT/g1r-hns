"""First source battle-rule bridge and reviewed New Bark farewell gate."""
import re
import json
import subprocess
import opening
import quest

MOM_FAREWELL = 0x602D
IMPLEMENTED = {'ITEM_MODE_MODERN_MOVES','ITEM_MODE_SPLIT', 'ITEM_MODE_FAIRY_TYPES', 'ITEM_MODE_STURDY',
               'ITEM_MODE_NEW_CITRUS', 'ITEM_MODE_SURVIVE_POISON',
               'ITEM_DIFFICULTY_EXP_MULTIPLIER', 'ITEM_DIFFICULTY_NO_EVS',
               'ITEM_DIFFICULTY_ITEM_PLAYER', 'ITEM_DIFFICULTY_ITEM_TRAINER',
               'ITEM_MAIN_FOLLOWER','ITEM_MAIN_LARGE_FOLLOWER','ITEM_FEATURES_RTC_TYPE',
               'ITEM_BATTLE_FAST_INTRO','ITEM_BATTLE_FAST_BATTLES','ITEM_BATTLE_NEW_BACKGROUNDS',
               'ITEM_BATTLE_NEW_BATTLEUI','ITEM_BATTLE_BALL_PROMPT','ITEM_BATTLE_RUN_TYPE','ITEM_BATTLE_LR_RUN',
               'ITEM_MODE_GEN_ONE_RECHARGE','ITEM_DIFFICULTY_LESS_ESCAPES','ITEM_DIFFICULTY_ESCAPE_ROPE_DIG'}
TYPE_NAMES = ('NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST',
              'STEEL','MYSTERY','FIRE','WATER','GRASS','ELECTRIC','PSYCHIC','ICE','DRAGON','DARK','FAIRY')

def replace_once(src, old, new, count=1):
    assert src.count(old)==count, (old,src.count(old),count)
    return src.replace(old,new)

def metadata(source,engine):
    known=set(re.findall(r'MOVE_(\w+)',(engine/'src/core/game3/constants/emerald/moves.lua').read_text()))-{'NONE','UNAVAILABLE'}
    aliases={'VISE_GRIP':'VICE_GRIP','HIGH_JUMP_KICK':'HI_JUMP_KICK','FEINT_ATTACK':'FAINT_ATTACK','SMELLING_SALTS':'SMELLING_SALT'}
    # Modern Moves chooses learnsets; fixed move parameters use source config.
    move_input='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "config/contest.h"\n#include "data/moves_info.h"\n'
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=move_input,text=True)
    def literal(value):
        value=value.strip().strip('()')
        ternary=re.fullmatch(r'\(?\s*(\d+)\s*>=\s*(\d+)\s*\)?\s*\?\s*(-?\d+|TYPE_\w+)\s*:\s*(-?\d+|TYPE_\w+)',value)
        if ternary:value=ternary[3] if int(ternary[1])>=int(ternary[2]) else ternary[4]
        if value.startswith('TYPE_'):return TYPE_NAMES.index(value[5:])
        assert re.fullmatch(r'-?\d+',value),value
        return int(value)
    moves={}
    for name,row in re.findall(r'\[MOVE_(\w+)\]\s*=\s*(.*?)(?=\n    \[MOVE_|\Z)',body,re.S):
        name=aliases.get(name,name)
        if name not in known:continue
        category=re.search(r'\.category\s*=\s*DAMAGE_CATEGORY_(\w+)',row)
        assert category,name
        moves[name]={'category':category[1].lower()}
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',row,re.S)
        if not desc:
            variable=re.search(r'\.description\s*=\s*(\w+),',row)[1]
            desc=re.search(r'\b'+variable+r'(?:\[\])?\s*=\s*(?:COMPOUND_STRING|_)\((.*?)\);',body,re.S)
        assert desc,name
        moves[name]['description']=''.join(json.loads(s) for s in re.findall(r'"(?:[^"\\]|\\.)*"',desc[1])).replace('{POKEBLOCK}','POKéBLOCK').replace('{PKMN}','POKéMON')
        for field in ('power','accuracy','pp','priority','type'):
            found=re.search(r'\.'+field+r'\s*=\s*([^,]+),',row)
            assert found,(name,field)
            moves[name][field]=literal(found[1])
        if name in ('CHARM','SWEET_KISS','MOONLIGHT'):
            assert 'TYPE_FAIRY' in row,name
            moves[name]['fairyType']=18
    assert len(moves)==354,(len(moves),known-set(moves))
    c=(source/'src/pokemon.c').read_text()
    pre=c.split('sPreFairyTypes[] = {')[1].split('\n};')[0]
    legacy={name:[TYPE_NAMES.index(a),TYPE_NAMES.index(b)] for name,a,b in re.findall(r'\{ SPECIES_(\w+),\s*\{ TYPE_(\w+),\s*TYPE_(\w+)',pre)}
    text='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/pokemon.h"\n#include "config/species_enabled.h"\n'+''.join('#include "data/pokemon/species_info/gen_%d_families.h"\n'%n for n in (1,2,3))
    processed=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=text,text=True)
    native=set(re.findall(r'SPECIES_(\w+)',(engine/'src/core/game3/constants/emerald/species.lua').read_text()))
    species={}
    for name,old in legacy.items():
        if name not in native:continue
        row=re.search(r'\[SPECIES_'+name+r'\]\s*=\s*(.*?)(?=\n\s*\[SPECIES_|\Z)',processed,re.S)[1]
        types=re.search(r'\.types\s*=\s*(.*)',row)[1]
        types=re.sub(r'\((\d+) >= (\d+) \? (TYPE_\w+) : (TYPE_\w+)\)',lambda m:m[3] if int(m[1])>=int(m[2]) else m[4],types)
        names=re.findall(r'TYPE_(\w+)',types)
        assert 1<=len(names)<=2,(name,types)
        new=[TYPE_NAMES.index(t) for t in names]
        if len(new)==1:new*=2
        assert 18 in new,(name,new)
        species[name]={'legacy':old,'modern':new}
    assert len(species)==18,len(species)
    chart={}
    info=(source/'src/data/types_info.h').read_text().split('gTypeEffectivenessTable')[1].split('\n};')[0]
    tokens=('NONE',)+TYPE_NAMES+('STELLAR',)
    aliases={'______':10,'STL_RS':10,'PSN_RS':5,'BUG_RS':10,'PSY_RS':20,'FIR_RS':5}
    assert re.search(r'#define B_UPDATED_TYPE_MATCHUPS\s+GEN_LATEST', (source/'include/config/battle.h').read_text())
    for name,row in re.findall(r'\[TYPE_(\w+)\]\s*=\s*\{([^}]+)\}',info):
        if name not in TYPE_NAMES:continue
        values=[aliases[v] if v in aliases else round(float(re.fullmatch(r'X\(([0-9.]+)\)',v)[1])*10) for v in map(str.strip,row.split(','))]
        assert len(values)==21,(name,len(values))
        chart[str(TYPE_NAMES.index(name))]={str(TYPE_NAMES.index(d)):values[tokens.index(d)] for d in TYPE_NAMES}
    assert len(chart)==19
    config=(source/'include/config/battle.h').read_text()
    fixed={'B_CRIT_CHANCE':'GEN_LATEST','B_CRIT_MULTIPLIER':'GEN_3','B_PARALYSIS_SPEED':'GEN_3',
           'B_CONFUSION_SELF_DMG_CHANCE':'GEN_3','B_BURN_DAMAGE':'GEN_3','B_SLEEP_TURNS':'GEN_3',
           'B_BURN_FACADE_DMG':'GEN_LATEST','B_HIDDEN_POWER_DMG':'GEN_LATEST',
           'B_EXPLOSION_DEFENSE':'GEN_LATEST','B_UPDATED_MOVE_DATA':'GEN_LATEST',
           'B_SCALED_EXP':'GEN_3','B_SHOW_MOVE_DESCRIPTION':'TRUE','B_MOVE_DESCRIPTION_BUTTON':'START_BUTTON'}
    for name,value in fixed.items():assert re.search(r'#define '+name+r'\s+'+value+r'\b',config),name
    odds=re.search(r'sGen7CriticalHitOdds\[\]\s*=\s*\{([^}]+)\}',(source/'src/battle_util.c').read_text())[1]
    odds=[int(n) for n in re.findall(r'\d+',odds)]
    assert odds==[24,8,2,1,1],odds
    return {'moves':moves,'species':species,'chart':chart,'criticalOdds':{str(i):n for i,n in enumerate(odds)},'fixedConfig':fixed,'fairyType':18,'implemented':sorted(IMPLEMENTED),'momFarewellFlag':MOM_FAREWELL,
            'limits':['Native species use source stats; compatible expanded level/egg moves are active. Unsupported moves/abilities, TM/tutor learning, randomizer, Nuzlocke and remaining challenge effects need bridges.','Source selectable terrain and healthboxes are active; battle orchestration and most move animations remain native. Full expansion parity is unfinished.']}

def derivatives(engine,stage):
    src=(engine/'src/core/game3/battle/damage.lua').read_text()
    src=replace_once(src,'local Damage = {}','local Damage = {}\nlocal HNS\nfunction Damage.configure(rules) HNS=rules end')
    src=replace_once(src,'Types.isPhysical(moveType)','HNS.physical(move, moveType)',4)
    src=replace_once(src,'local power = math.floor(40 * powerBits / 63) + 30','local power = 60')
    src=replace_once(src,'  if tonumber(move.effect) == EffectIds.EXPLOSION then\n    defense = math.floor(defense / 2)\n  end\n','')
    src=replace_once(src,'status_of(attacker) == "BRN" and aAb ~= "GUTS"','status_of(attacker) == "BRN" and aAb ~= "GUTS" and tonumber(move.effect) ~= EffectIds.FACADE')
    (stage/'hns_damage.lua').write_text('-- Derived from pinned native damage.lua; see GEN1RECOMP_LICENSE.md.\n'+src)
    src=(engine/'src/core/game3/battle/rules.lua').read_text()
    crit=src[src.index('local function rollZeroTo'):src.index('function Rules.crit.multiplier')]
    crit=replace_once(crit,'function Rules.crit.roll(attacker, moveOrId, highCrit, rng, st)','local function critRoll(attacker, moveOrId, highCrit, rng, st)')
    crit=replace_once(crit,'Rules.crit.CHANCE[stage] or 2','HNS.criticalOdds[tostring(stage)] or 1')
    prefix='return function(HNS)\nlocal Rules=require("src.core.game3.battle.rules")\nlocal Oak=require("src.core.game3.battle.oak_advice")\nlocal function fallback_rng(lo,hi)return require("src.core.game3.battle.link_guard").fallback("rules.roll",lo,hi)end\n'
    (stage/'hns_critical.lua').write_text('-- Derived from native critical roll; HnS fixed odds. See GEN1RECOMP_LICENSE.md.\n'+prefix+crit+'\nreturn critRoll\nend\n')
    src=(engine/'src/core/game3/battle/engine.lua').read_text()
    accuracy=src[src.index('function Ctx:accuracyCheck'):src.index('-- pokefirered/src/battle_script_commands.c:912')]
    accuracy=replace_once(accuracy,'Types.isPhysical(self.moveType or self.move.type)','HNS.physical(self.move, self.moveType or self.move.type)')
    prefix='return function(HNS)\nlocal Ctx={}\nlocal Rules=require("src.core.game3.battle.rules")\nlocal E=require("src.core.game3.battle.effect_ids")\nlocal HeldItems=require("src.core.game3.battle.held_items")\nlocal Oak=require("src.core.game3.battle.oak_advice")\nlocal ModRuntime=require("src.mods.Runtime")\nlocal function roll(ad,lo,hi)return ad:roll(lo,hi)end\n'
    (stage/'hns_accuracy.lua').write_text('-- Derived from native Ctx:accuracyCheck; see GEN1RECOMP_LICENSE.md.\n'+prefix+accuracy+'\nreturn Ctx.accuracyCheck\nend\n')
    selfhit=src[src.index('function Engine.selfHit'):src.index('-- pokefirered/src/battle_util.c:1253')]
    selfhit=replace_once(selfhit,'function Engine.selfHit(M, dmg)','return function(M, dmg)')
    selfhit=replace_once(selfhit,'  local banded = HeldItems.rollFocusBand(ad, user)','  local sturdy=HNS.sturdy(M, user, dmg)\n  if sturdy then dmg=ad:hp(user)-1 end\n  local banded = not sturdy and HeldItems.rollFocusBand(ad, user)')
    selfhit=replace_once(selfhit,'  M:tryFaintUser()','  if sturdy then HNS.sturdyMessage(ad,user) end\n  M:tryFaintUser()')
    (stage/'hns_self_hit.lua').write_text('-- Derived from native Engine.selfHit; see GEN1RECOMP_LICENSE.md.\nreturn function(HNS)\nlocal HeldItems=require("src.core.game3.battle.held_items")\nlocal function roll(ad,lo,hi)return ad:roll(lo,hi)end\n'+selfhit+'\nend\n')
    src=(engine/'src/core/game3/step_events.lua').read_text()
    src=replace_once(src,'local StepEvents = {}\n\nStepEvents._queue = {}\nStepEvents._activeEvent = nil\nStepEvents._poisonFlashTimer = 0\nStepEvents._totalSteps = 0','local StepEvents = setmetatable({}, {__index=NativeSteps, __newindex=function(t,k,v)\n  if k:sub(1,1)=="_" then NativeSteps[k]=v else rawset(t,k,v) end\nend})')
    src=replace_once(src,'mon.hp = math.max(0, hp - 1)','mon.hp = math.max(HNS.poisonSurvives(session) and 1 or 0, hp - 1)')
    src=replace_once(src,'if mon.hp == 0 then','if mon.hp == 0 or (HNS.poisonSurvives(session) and mon.hp == 1) then')
    src=replace_once(src,'          Pokemon.adjustFriendship(mon, Pokemon.FRIENDSHIP_EVENT_FAINT_OUTSIDE_BATTLE,\n            { mapSec = Pokemon.currentMapSec(session) })','          if mon.hp == 0 then Pokemon.adjustFriendship(mon, Pokemon.FRIENDSHIP_EVENT_FAINT_OUTSIDE_BATTLE,\n            { mapSec = Pokemon.currentMapSec(session) }) end')
    src=replace_once(src,'poisonFainted = #faintedMons > 0','for _,v in ipairs(faintedMons) do if v.mon.hp == 0 then poisonFainted=true end end')
    src=replace_once(src,'Hud.openMessage(game, RomText.box((P.field and P.field.poisonFaintText) or "gText_PkmnFainted3",\n              { stringVars = { fainted.name } }),','Hud.openMessage(game, fainted.mon.hp > 0 and HNS.poisonMessage(fainted.name) or RomText.box((P.field and P.field.poisonFaintText) or "gText_PkmnFainted3",\n              { stringVars = { fainted.name } }),')
    (stage/'hns_step_events.lua').write_text('-- Derived from native step_events.lua; shared queue, source poison survival. See GEN1RECOMP_LICENSE.md.\nreturn function(NativeSteps,HNS)\n'+src+'\nend\n')

def build(source,engine,stage,maps,labels,text,scripts,q,Q):
    def r(op,**kw):return {'op':op,**kw}
    def key(n):return 'HNS_RULES_'+n
    def msg(label):
        text[key(label)]=opening.source_text(label,labels)
        return [r('message',ptr=key(label)),r('waitmessage'),r('waitbuttonpress'),r('closemessage')]
    def branch(f,n,on=True):return [r('checkflag',flag=f),r('goto_if',cond=1 if on else 0,target=key(n))]
    def script(n,rows):scripts[key(n)]=rows
    done=[r('releaseall'),r('end')]
    script('END',[r('end')])
    script('MOM',[r('lockall'),r('faceplayer')]+branch(MOM_FAREWELL,'MOM_REPEAT')+[r('playbgm',songName='MUS_HG_FOLLOW_ME_1')]+msg('NewBarkTown_PlayersHouse_1F_Text_MomLeaving')+[r('setflag',flag=MOM_FAREWELL),r('setflag',flag=opening.MOM_VISITED),r('fadedefaultbgm')]+done)
    script('MOM_REPEAT',msg('NewBarkTown_PlayersHouse_1F_Text_MomLeaving')+done)
    scripts['HNS_OPENING_MOM']=branch(quest.EGG_DELIVERED,'MOM')+scripts['HNS_OPENING_MOM']
    scripts['HNS_OPENING_MOM_AFTER']=msg('NewBarkTown_PlayersHouse_1F_Text_MomHurryUpElmIsWaiting')+done
    # Both entry positioning and coordinate interactions must check the farewell.
    town='EM_HNS_NEW_BARK_TOWN_HNS'
    old=scripts['HNS_FIDELITY_TOWN_INIT']
    scripts['HNS_FIDELITY_TOWN_INIT']=branch(quest.EGG_DELIVERED,'TOWN_RETURN')+old
    script('TOWN_RETURN',branch(MOM_FAREWELL,'TOWN_FREE')+[{'op':'setobjectxyperm','localId':2,2:0,3:11},r('setflag',flag=Q['windowHiddenFlag']),r('end')])
    script('TOWN_FREE',[r('goto',target='HNS_FIDELITY_TOWN_AFTER')])
    old=scripts['HNS_FIDELITY_BLOCK_EXIT']
    scripts['HNS_FIDELITY_BLOCK_EXIT']=branch(quest.EGG_DELIVERED,'BLOCK_MOM')+old
    movement=[r('playse',seName='SE_PIN'),r('applymovement',localId=2,movementNames=['MOVEMENT_ACTION_EMOTE_EXCLAMATION_MARK','MOVEMENT_ACTION_STEP_END']),r('delay',frames=55),r('waitmovement',localId=2),r('turnobject',localId=2,direction=1)]
    script('BLOCK_MOM',branch(MOM_FAREWELL,'END')+[r('lockall')]+movement+msg('NewBarkTown_Text_LassState4')+[r('applymovement',localId=255,movementNames=['MOVEMENT_ACTION_WALK_NORMAL_RIGHT','MOVEMENT_ACTION_STEP_END']),r('waitmovement',localId=255)]+done)
    scripts['HNS_FIDELITY_LASS']=[r('lockall'),r('faceplayer')]+branch(quest.EGG_DELIVERED,'LASS_RETURN')+scripts['HNS_FIDELITY_LASS'][2:]
    script('LASS_RETURN',branch(MOM_FAREWELL,'LASS_FREE')+msg('NewBarkTown_Text_LassState4')+done)
    script('LASS_FREE',msg('NewBarkTown_Text_LassState5')+done)
    rules=metadata(source,engine)
    for p in Q['settings']['pages']:
        for row in p['rows']:
            if row['id'] in IMPLEMENTED:row['implemented']=True
            partial={
                'ITEM_MODE_GAMEMODE':'PARTLY IMPLEMENTED:\nSome Custom rules are pending.',
                'ITEM_MODE_MODERN_MOVES':'PARTLY IMPLEMENTED:\nReviewed moves only; others pending.',
                'ITEM_MAIN_FOLLOWER':'PARTLY IMPLEMENTED:\nSome conditional scenes pending.',
            }
            if row['id'] in partial:row['partial']=partial[row['id']]
    derivatives(engine,stage)
    return rules
