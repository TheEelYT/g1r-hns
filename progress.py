"""Generate a reviewable weighted feature-parity estimate from the built port."""
import argparse,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def generate(mod,engine,luajit):
    spec=json.loads((ROOT/'progress.json').read_text())
    world=json.loads(subprocess.check_output([str(luajit),str(engine/'tools/lua_to_json.lua'),str(mod/'world.lua')],text=True))
    abilities=world['abilities'];moves=world['expandedMoves'];settings=world['startup']['settings']
    # Count reviewed bridges, including explicitly partial settings; not all
    # modern-move effects are complete merely because that menu is wired.
    implemented=world['startup']['rules']['implemented']
    def countrows(v):
        if isinstance(v,dict):
            if 'choices'in v and 'id'in v:return [v]
            return [r for x in v.values() for r in countrows(x)]
        if isinstance(v,list):return [r for x in v for r in countrows(x)]
        return []
    rows=countrows(settings)
    ids={r['id'] for r in rows}
    metrics={'abilities':{'covered':sum(abilities['counts'][k]for k in ('native','reviewed')),'total':len(abilities['records'])},
             'moves':{'covered':len(moves['moves']),'total':len(moves['moves'])+len(moves['omitted'])},
             'settings':{'covered':len(set(implemented)&ids),'total':len(ids)}}
    assert all(0<=m['covered']<=m['total'] and m['total']>0 for m in metrics.values())
    assert spec['schema']==1
    seen=set();score=0;categories=[]
    assert sum(c['weight']for c in spec['categories'])==100
    for c in spec['categories']:
        assert c['weight']>0
        assert c['id']not in seen;seen.add(c['id']);subtotal=0
        assert sum(i['weight']for i in c['items'])==c['weight']
        for i in c['items']:
            key=c['id']+'/'+i['id'];assert key not in seen;seen.add(key)
            assert i['weight']>0 and i['state']in ('done','partial','pending')
            assert all((ROOT/p).is_file()for p in i['evidence']),i
            fraction={'done':1,'partial':.5,'pending':0}[i['state']]
            if 'metric'in i:
                assert i['state']=='partial';m=metrics[i['metric']];fraction=m['covered']/m['total']
            subtotal+=i['weight']*fraction
        categories.append({'id':c['id'],'title':c['title'],'weight':c['weight'],'complete_percent':round(subtotal/c['weight']*100,2),'earned_points':round(subtotal,4)})
        score+=subtotal
    version=json.loads((mod/'manifest.json').read_text())['version']
    result={'version':version,'method':spec['method'],'complete_percent':round(score,2),'remaining_percent':round(100-score,2),'categories':categories,'coverage':metrics,
            'limits':['Scope weights are editorial and can change when omissions are found.','Partial milestones default to half credit; measured rows use their actual reviewed counts.','Settings include partial bridges; expanded moves exclude original native move rows.','Automated headless checks do not establish Windows GPU/audio/gameplay parity.']}
    lines=['# Port progress — '+version,'',f"**Approximately {score:.0f}% complete / {100-score:.0f}% remaining.**",'',spec['method'],'','Weights describe total feature scope. Map imports and small fixes do not count equally with battle systems or the full campaign. This estimate does not predict engineering hours or a release date.','', '| Area | Scope weight | Estimated complete |','|---|---:|---:|']
    for c in categories:lines.append(f"| {c['title']} | {c['weight']}% | {c['complete_percent']:.1f}% |")
    lines+=['','Measured bridge coverage (not a claim of complete behavior):','']
    for name,m in metrics.items():lines.append(f"- {name.title()}: {m['covered']}/{m['total']} ({100*m['covered']/m['total']:.1f}%).")
    lines+=['','The source scope inventory and evidence paths are in [progress.json](progress.json). `done` earns full credit, `pending` zero and `partial` half unless a coverage counter is specified. Each item has an explicit share of its category. Settings include partial Modern Moves coverage; expanded moves exclude the original native rows.','', '## Inventory','']
    for c in spec['categories']:
        lines+=['### '+c['title'],'','| Milestone | Weight | State | Evidence |','|---|---:|---|---|']
        for i in c['items']:lines.append(f"| {i['label']} | {i['weight']} | {i['state']} | "+', '.join(f'[{p}]({p})'for p in i['evidence'])+' |')
        lines.append('')
    lines+=['Missing progression trainers, Cut trees and other travel blockers stay **last**, alongside the route-order and sequence-break audit. Testing travel remains open. Mod 1.0.0 remains reserved for full romhack parity.','','Windows GPU rendering, gameplay and listening remain player checks. See [TESTING.md](TESTING.md).','', 'Regenerate: `python3 progress.py --mod build/hns_exploration --engine build/engine --luajit /path/to/luajit` (add `--check` in CI).','']
    return result,'\n'.join(lines)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for k in ('mod','engine','luajit'):p.add_argument('--'+k,type=Path,required=True)
    p.add_argument('--check',action='store_true');a=p.parse_args()
    result,markdown=generate(a.mod.resolve(),a.engine.resolve(),a.luajit.resolve())
    for path,value in [(ROOT/'PROGRESS.md',markdown),(ROOT/'reports/progress.json',json.dumps(result,indent=2)+'\n')]:
        if a.check:assert path.read_text()==value,'Stale progress snapshot: '+str(path)
        else:path.write_text(value)
    print(json.dumps({k:result[k]for k in ('version','complete_percent','remaining_percent','coverage')}))
if __name__=='__main__':main()
