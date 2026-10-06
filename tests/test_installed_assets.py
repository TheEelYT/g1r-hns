"""Run the native suite on files encoded by the real newer G1R installer codec."""
import argparse
from pathlib import Path
import subprocess
import tempfile

p=argparse.ArgumentParser()
p.add_argument('--engine',type=Path,required=True)
p.add_argument('--mod',type=Path,required=True)
p.add_argument('--luajit',type=Path,required=True)
a=p.parse_args()
engine,mod,lua=a.engine.resolve(),a.mod.resolve(),a.luajit.resolve()
tests=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='hns-installed-')as tmp:
    installed=Path(tmp)/'hns_exploration';installed.mkdir()
    packed=[]
    for file in mod.rglob('*'):
        rel=file.relative_to(mod);dest=installed/rel
        if file.is_dir():dest.mkdir(exist_ok=True)
        elif file.suffix in ('.rgba','.idx'):packed.append(rel.as_posix())
        else:dest.symlink_to(file)
    listing=Path(tmp)/'files.txt';listing.write_text('\n'.join(packed)+'\n')
    encode=Path(tmp)/'encode.lua'
    encode.write_text("""
package.path='./?.lua;./?/init.lua;'..package.path
local Blob=require('src.import.CacheBlob')
local n=0
for rel in io.lines(arg[3])do
  local f=assert(io.open(arg[1]..'/'..rel,'rb'));local raw=f:read('*a');f:close()
  local encoded=Blob.encode('mods/hns_exploration/'..rel,raw)
  assert(Blob.decode(rel,encoded)==raw,'installer codec round trip '..rel)
  local out=assert(io.open(arg[2]..'/'..rel,'wb'));out:write(encoded);out:close();n=n+1
end
print('Real CacheBlob installer encoding: '..n..' assets')
""")
    subprocess.run([str(lua),str(encode),str(mod),str(installed),str(listing)],cwd=engine,check=True)
    # Every integration path reads through the real Loader/mod API, including
    # boot credits/title, maps/interiors, NPCs, source fonts and battle terrain.
    for root in ('default','mounted'):
        subprocess.run([str(lua),str(tests/'test_native.lua'),str(installed),root],cwd=engine,check=True)
