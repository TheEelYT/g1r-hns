"""Import every HnS move row, keeping source fields apart from engine dispatch.

Source expressions/references are retained verbatim after preprocessing, so
unimplemented arguments, animations and flags are not discarded. Port IDs keep
existing saves compatible; source enum IDs are recorded separately.
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path
from dex_moves import ALIASES
from gameplay import TYPE_NAMES


def fields(body):
    result={};start=0;depth=0;quoted=False;escaped=False
    for i,c in enumerate(body+','):
        if quoted:
            if escaped:escaped=False
            elif c=='\\':escaped=True
            elif c=='"':quoted=False
        elif c=='"':quoted=True
        elif c in '({[':depth+=1
        elif c in ')}]':depth-=1
        elif c==',' and depth==0:
            part=body[start:i].strip();start=i+1
            if part:
                m=re.fullmatch(r'\.([\w.]+)\s*=\s*(.*)',part,re.S)
                assert m,part
                assert m[1]not in result,m[1]
                result[m[1]]=m[2].strip()
    assert depth==0 and not quoted
    return result


def rows(body):
    for m in re.finditer(r'\[MOVE_(\w+)\]\s*=\s*\{',body):
        start=m.end();depth=1;quoted=False;escaped=False
        for i in range(start,len(body)):
            c=body[i]
            if quoted:
                if escaped:escaped=False
                elif c=='\\':escaped=True
                elif c=='"':quoted=False
            elif c=='"':quoted=True
            elif c=='{':depth+=1
            elif c=='}':
                depth-=1
                if depth==0:
                    yield m[1],fields(body[start:i]);break
        else:raise ValueError('unterminated move '+m[1])


def number(value):
    value=value.strip().strip('() ')
    tern=re.fullmatch(r'(\d+)\s*>=\s*(\d+)\s*\?\s*(-?\d+)\s*:\s*(-?\d+)',value)
    if tern:return int(tern[3]if int(tern[1])>=int(tern[2])else tern[4])
    assert re.fullmatch(r'-?\d+',value),value
    return int(value)


def build(source,engine,display,expanded,roost_id):
    prefix='#define TRUE 1\n#define FALSE 0\n#include "config/general.h"\n#include "config/battle.h"\n'
    body=subprocess.check_output(['cpp','-P','-I'+str(source/'include'),'-I'+str(source/'src'),'-'],input=prefix+'#include "config/contest.h"\n#include "data/moves_info.h"\n',text=True)
    entries=list(rows(body));names=[n for n,_ in entries];assert len(names)==len(set(names))
    code='#include <stdio.h>\n'+prefix+'#include "constants/moves.h"\nint main(void){\n'
    code+=''.join('printf("'+n+' %d\\n",MOVE_'+n+');\n'for n in names)+'}\n'
    with tempfile.TemporaryDirectory()as tmp:
        p=Path(tmp);(p/'ids.c').write_text(code)
        subprocess.run(['gcc','-I'+str(source/'include'),str(p/'ids.c'),'-o',str(p/'ids')],check=True)
        ids=dict((n,int(v))for n,v in (line.split()for line in subprocess.check_output([str(p/'ids')],text=True).splitlines()))
    native={n:int(v)for v,n in re.findall(r'\[(\d+)\]\s*=\s*"MOVE_(\w+)"',(engine/'src/core/game3/constants/emerald/moves.lua').read_text())}
    omitted={r['move']:r['reason']for r in expanded['omitted']}
    records={}
    for ordinal,(name,values)in enumerate(entries):
        canonical=ALIASES.get(name,name);d=display.get(canonical)
        assert d or name=='NONE',name
        rec=dict(d or {'name':''.join(json.loads(s)for s in re.findall(r'"(?:[^"\\]|\\.)*"',values['name'])),
                      'description':'','power':number(values['power']),'accuracy':number(values['accuracy']),
                      'type':values['type'].removeprefix('TYPE_'),'category':values['category'].removeprefix('DAMAGE_CATEGORY_').lower()})
        rec.update(sourceName=name,sourceId=ids[name],sourceOrdinal=ordinal,sourceFields=values,
                   pp=number(values.get('pp','0')),priority=number(values.get('priority','0')),
                   target=values.get('target','TARGET_SELECTED').removeprefix('TARGET_'),
                   sourceEffect=values.get('effect','EFFECT_HIT').removeprefix('EFFECT_'))
        if name=='NONE':rec.update(id=0,support='none')
        elif canonical in native:rec.update(id=native[canonical],support='native')
        elif name in expanded['moves']:rec.update(id=expanded['moves'][name]['id'],support='implemented')
        else:rec.update(id=1000+ordinal,support='pending',pendingReason=omitted[name])
        if name=='ROOST':assert rec['id']==roost_id and rec['sourceEffect']=='ROOST'
        assert canonical not in records,canonical
        records[canonical]=rec
    assert len({r['id']for r in records.values()})==len(records)
    return {'moves':records,'count':len(records),'source':'HnS src/data/moves_info.h',
            'counts':{status:sum(r['support']==status for r in records.values())for status in ('none','native','implemented','pending')},
            'limits':'Complete source move data and original field expressions imported. Native bridges and reviewed custom effects execute; pending effects remain excluded from learned move lists.'}
