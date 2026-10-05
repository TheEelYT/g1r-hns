"""Reviewed later-generation move effects that the native engine can execute.

Never convert an unsupported effect into plain damage. Stable port IDs are
source declaration ordinal + 1000; Roost keeps the existing save-compatible 901.
"""
import json,re,subprocess
from gameplay import TYPE_NAMES

EXTRA={'BURN':'BURN','FREEZE_OR_FROSTBITE':'FREEZE','FREEZE':'FREEZE','PARALYSIS':'PARALYSIS','POISON':'POISON',
       'TOXIC':'TOXIC','CONFUSION':'CONFUSION','FLINCH':'FLINCH','ALL_STATS_UP':'ALL_STATS_UP',
       'ATK_MINUS_1':'ATK_MINUS_1','DEF_MINUS_1':'DEF_MINUS_1','SPD_MINUS_1':'SPD_MINUS_1',
       'SP_ATK_MINUS_1':'SP_ATK_MINUS_1','SP_DEF_MINUS_1':'SP_DEF_MINUS_1','ACC_MINUS_1':'ACC_MINUS_1',
       'ATK_PLUS_1':'ATK_PLUS_1','DEF_PLUS_1':'DEF_PLUS_1','SPD_PLUS_1':'SPD_PLUS_1',
       'SP_ATK_PLUS_1':'SP_ATK_PLUS_1','SP_DEF_PLUS_1':'SP_DEF_PLUS_1'}


def build(source,engine):
    inp='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n#include "config/contest.h"\n#include "data/moves_info.h"\n'
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=inp,text=True)
    native=set(re.findall(r'MOVE_(\w+)',(engine/'src/core/game3/constants/emerald/moves.lua').read_text()))
    effects=dict((name,int(n))for name,n in re.findall(r'^  (\w+) = (\d+),',(engine/'src/core/game3/battle/effect_ids.lua').read_text(),re.M))
    # Explicitly reviewed dispatches: HIT and its additional-effect list,
    # 50% absorption, high critical stage 1 and native-compatible status moves.
    compatible={'HIT','ABSORB','ALWAYS_HIT','ATTACK_UP','DEFENSE_UP','SPEED_UP','SPECIAL_ATTACK_UP','SPECIAL_DEFENSE_UP','ATTACK_DOWN','DEFENSE_DOWN','SPEED_DOWN','SPECIAL_ATTACK_DOWN','SPECIAL_DEFENSE_DOWN','SLEEP','POISON','TOXIC','PARALYZE','CONFUSE','RECOVER','REST','REFRESH','INGRAIN','WISH','PAIN_SPLIT','HEAL_BELL','SAFEGUARD','REFLECT','LIGHT_SCREEN','MIST','HAZE','FOCUS_ENERGY','SUBSTITUTE','PROTECT','ENDURE','SPIKES','LEECH_SEED','HELPING_HAND'}
    records={};omitted=[]
    def num(row,field,default=None):
        m=re.search(r'\.'+field+r'\s*=\s*([^,}\n]+)',row)
        if not m:return default
        expr=m[1].strip().strip('()');tern=re.fullmatch(r'(\d+)\s*>=\s*(\d+)\s*\?\s*(-?\d+)\s*:\s*(-?\d+)',expr)
        if tern:return int(tern[3]if int(tern[1])>=int(tern[2])else tern[4])
        if re.fullmatch(r'-?\d+',expr):return int(expr)
        compare=re.fullmatch(r'(\d+)\s*(<=|>=|==|!=|<|>)\s*(\d+)',expr)
        if compare:
            a,b=int(compare[1]),int(compare[3]);return int({'<':a<b,'>':a>b,'<=':a<=b,'>=':a>=b,'==':a==b,'!=':a!=b}[compare[2]])
        raise ValueError(field+': '+expr)
    for ordinal,(name,row)in enumerate(re.findall(r'\[MOVE_(\w+)\]\s*=\s*(.*?)(?=\n    \[MOVE_|\Z)',body,re.S)):
        if name in native or name in ('NONE','ROOST','VISE_GRIP','HIGH_JUMP_KICK','FEINT_ATTACK','SMELLING_SALTS'):continue
        eff=re.search(r'\.effect\s*=\s*EFFECT_(\w+)',row)
        if not eff:continue
        reason=None;extra=[];effect=eff[1]
        if effect not in compatible or effect not in effects:reason='expanded effect handler required: '+effect
        if re.search(r'\.(?:isZMove|isMaxMove)\s*=\s*1',row):reason='special battle transformation required'
        # Unreviewed arguments must not silently disappear.
        args=re.search(r'\.argument\s*=\s*\{([^}]+)',row)
        if args and not(effect=='ABSORB'and re.fullmatch(r'\s*\.absorbPercentage\s*=\s*50\s*,?\s*',args[1])):reason='expanded move argument required'
        addition=re.search(r'\.additionalEffects\s*=\s*(.*?)(?=\n\s*\.(?:contest|battleAnim|valid)|\Z)',row,re.S)
        if addition:
            for block in re.findall(r'\{([^{}]+)\}',addition[1]):
                move=re.search(r'\.moveEffect\s*=\s*MOVE_EFFECT_(\w+)',block)
                if not move or move[1]not in EXTRA:reason='expanded additional effect required';break
                if re.search(r'\.(?:onChargeTurn|onlyIfTargetRaisedStats|sheerForceOverride|chargeTurnOnly)',block):reason='conditional additional effect required';break
                extra.append({'effect':EXTRA[move[1]],'chance':num(block,'chance',100),'user':num(block,'self',0)==1})
        category=re.search(r'\.category\s*=\s*DAMAGE_CATEGORY_(\w+)',row)
        typ=re.search(r'\.type\s*=\s*TYPE_(\w+)',row)
        target=re.search(r'\.target\s*=\s*TARGET_(\w+)',row)
        if not category or not typ or typ[1]not in TYPE_NAMES:reason='expanded type/category required'
        if target and target[1]not in {'SELECTED','USER','BOTH','ALL_BATTLERS','OPPONENTS_FIELD'}:reason='expanded target required'
        for flag in ('multiHit','ignoresSubstitute','ignoresTargetAbility','ignoresDefenseBoosts','ignoresEvasion','alwaysCriticalHit','twoTurnMove','damagesUnderground','damagesUnderwater','damagesAirborne'):
            if num(row,flag,0):reason='expanded move flag required: '+flag
        if reason:omitted.append({'move':name,'reason':reason});continue
        display=re.search(r'\.name\s*=\s*COMPOUND_STRING\("([^\"]+)"\)',row)[1]
        desc=re.search(r'\.description\s*=\s*COMPOUND_STRING\((.*?)\),',row,re.S)
        if not desc:
            ref=re.search(r'\.description\s*=\s*(\w+),',row)
            if ref:desc=re.search(r'\b'+ref[1]+r'(?:\[\])?\s*=\s*(?:COMPOUND_STRING|_)\((.*?)\);',body,re.S)
        description=''.join(json.loads(v)for v in re.findall(r'"(?:[^"\\]|\\.)*"',desc[1]))if desc else ''
        crit=num(row,'criticalHitStage',0)
        if crit>1:omitted.append({'move':name,'reason':'expanded critical stage required'});continue
        flags=0
        for field,bit in [('makesContact',1),('ignoresProtect',2),('magicCoatAffected',4),('snatchAffected',8),('mirrorMoveBanned',16),('ignoresKingsRock',32)]:
            value=num(row,field,0)
            if (field in ('ignoresProtect','mirrorMoveBanned','ignoresKingsRock')and not value)or(field not in ('ignoresProtect','mirrorMoveBanned','ignoresKingsRock')and value):flags|=bit
        rec={'id':1000+ordinal,'name':display,'description':description,'effect':effects['HIGH_CRITICAL']if crit==1 and effect=='HIT'else effects[effect],
            'power':num(row,'power',0),'accuracy':num(row,'accuracy',0),'pp':num(row,'pp',0),'priority':num(row,'priority',0),
            'type':TYPE_NAMES.index(typ[1]),'category':category[1].lower(),'flags':flags,'target':{'SELECTED':0,'USER':16,'BOTH':8,'ALL_BATTLERS':32,'OPPONENTS_FIELD':64}.get(target[1]if target else 'SELECTED',0),
            'additionalEffects':extra,'thawsUser':num(row,'thawsUser',0)==1}
        if rec['thawsUser']and effect=='HIT':rec['effect']=effects['THAW_HIT']
        hits=num(row,'strikeCount',1)
        if hits!=1:omitted.append({'move':name,'reason':'expanded multi-hit dispatch required'});continue
        records[name]=rec
    alt=dict(re.findall(r'\{ MOVE_(\w+),\s*TYPE_(\w+)\s*\}',(source/'src/pokemon.c').read_text().split('sFairyMoveAltTypes[]')[1].split('};')[0]))
    for name,row in records.items():
        if row['type']==18:row['legacyType']=TYPE_NAMES.index(alt.get(name,'NORMAL'))
    return {'moves':records,'omitted':omitted,'limits':'Reviewed native-compatible expanded damage, absorption and setup effects, source PP/category/target and independent secondary chances. Unsupported mechanics are listed, never downgraded to plain damage.'}
