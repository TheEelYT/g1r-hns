"""Package one immutable mod ZIP and its sealed, hash-pinned custom cart."""
import argparse
import base64
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent


def lua(value):
    if isinstance(value,bool):return 'true'if value else'false'
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,(int,float)):return str(value)
    if isinstance(value,list):return '{'+','.join('['+str(i)+']='+lua(v)for i,v in enumerate(value,1))+'}'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v)for k,v in sorted(value.items()))+'}'
    raise TypeError(type(value))


def package(mod,out,engine,luajit):
    manifest=json.loads((mod/'manifest.json').read_text());template=json.loads((ROOT/'release/cart.json').read_text())
    version=manifest['version'];cart_version=template['version'];repo=template['repo'];mod_id=manifest['id']
    assert re.fullmatch(r'\d+\.\d+\.\d+',version),version
    assert manifest['github']==repo
    assert template['id']=='pokemon_heart_soul'and template['seal']=='sealed'
    assert template['base']=='emerald'and template['load_order']==[mod_id]
    label=(ROOT/'release/pokemon-heart-soul.png').read_bytes()
    assert label.startswith(b'\x89PNG\r\n\x1a\n')and len(label)<=1024*1024
    out.mkdir(parents=True,exist_ok=True)
    zip_path=out/(mod_id+'-'+version+'.zip');cart_path=out/(template['id']+'-'+cart_version+'.g1rcart')
    # Fixed timestamps, permissions and order avoid new cart hashes for identical builds.
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
        for path in sorted(mod.rglob('*')):
            if not path.is_file():continue
            assert path.suffix.lower()not in ('.gba','.gb','.gbc','.sav','.ups'),path
            member=zipfile.ZipInfo(mod_id+'/'+path.relative_to(mod).as_posix(),(2020,1,1,0,0,0))
            member.create_system=3;member.external_attr=0o100644<<16;member.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(member,path.read_bytes(),compresslevel=9)
    digest=hashlib.sha256(zip_path.read_bytes()).hexdigest()
    template['mods']=[{'id':mod_id,'source':'github','repo':repo,'version':version,'sha256':digest}]
    bundle={'format':'g1rcart','formatVersion':1,'cart':template,'labelArt':{'bytes':len(label),'data':base64.b64encode(label).decode(),'encoding':'base64','name':'pokemon-heart-soul.png'}}
    cart_path.write_text('return '+lua(bundle)+'\n')
    # Use the actual Emerald-aware runtime parser, not the older cartkit CLI.
    subprocess.run([str(luajit),str(ROOT/'tests/test_cart_release.lua'),str(cart_path.resolve()),digest,version,cart_version],cwd=engine,check=True)
    records=[{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in (cart_path,zip_path)]
    (out/'SHA256SUMS').write_text(''.join(r['sha256']+'  '+r['name']+'\n'for r in records))
    (out/'release.json').write_text(json.dumps({'mod_version':version,'cart_version':cart_version,'repo':repo,'files':records},indent=2)+'\n')
    notes='Download **`'+cart_path.name+'` (recommended)** and import it with Gen1Recomp’s cart importer. It installs the exact mod release, keeps HnS saves under the custom cart, and ships sealed with mod edits disabled. Use Gen1Recomp v0.3.44 with vanilla US Emerald imported.\n\n`'+zip_path.name+'` is the alternative manual mod download; it does not create the isolated cart by itself.\n\nMod '+version+' / cart '+cart_version+'. Existing `pokemon_heart_soul` cart identity and label are preserved. This is a development port; the later campaign and expanded battle effects remain in progress.\n'
    (out/'release-notes.md').write_text(notes)
    return {'result':'pass','mod_version':version,'cart_version':cart_version,'files':records}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('mod','out','engine','luajit'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();print(json.dumps(package(a.mod.resolve(),a.out.resolve(),a.engine.resolve(),a.luajit.resolve())))
