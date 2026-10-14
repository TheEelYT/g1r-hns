"""Compare the portable GB sequencer frame-for-frame against actual HnS C."""
import re,subprocess,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import gbs


def check(source,engine,mod,luajit,world):
    spec=world['audio']['gbSounds'];records={r['name']:r for r in spec['songs'].values()};frames=0
    mapping={name:header for name,header in re.findall(r'^\s*song_gbs\s+(\w+),\s*(\w+)',(source/'sound/song_table.inc').read_text(),re.M)}
    expected={sid:mapping[n]for sid,n in world['audio']['songs'].items()if n in mapping}
    assert {sid:r['name']for sid,r in spec['songs'].items()}==expected
    with tempfile.TemporaryDirectory()as temp:
        root=Path(temp);symbols,_=gbs.compile_source(source,root)
        assert (root/'songs.bin').read_bytes()==(mod/spec['file']).read_bytes()
        script='''package.path='./?.lua;./?/init.lua;'..package.path
local Q=assert(loadfile(arg[1]..'/gbs_seq.lua'))();local f=assert(io.open(arg[1]..'/gbs/songs.bin','rb'));local data=f:read('*a');f:close()
local tables=dofile(arg[1]..'/gbs/tables.lua');local s=Q.new(data,tonumber(arg[2]),tables)
for i=1,tonumber(arg[3])do local r=Q.frame(s);local out={};for n=0,63 do out[n+1]=string.char(r[n])end;io.write(table.concat(out));Q.clearTriggers(s)end
'''
        (root/'actual.lua').write_text(script)
        for name,row in records.items():
            assert row['header']==symbols[name]
            count=int(gbs.run([str(root/'trace'),str(root/'songs.bin'),str(symbols[name]),str(root/'expected.bin'),'2400'],text=True).stdout)
            expected=(root/'expected.bin').read_bytes()
            actual=subprocess.check_output([str(luajit),str(root/'actual.lua'),str(mod),str(row['header']),str(count)],cwd=engine)
            if expected!=actual:
                i=next(i for i,(a,b)in enumerate(zip(expected,actual))if a!=b)
                raise AssertionError(f'{name} frame {i//64} register {i%64}: C {expected[i]}, Lua {actual[i]}')
            frames+=count
    return {'source_gbs_mapped_songs':len(spec['songs']),'source_gbs_distinct_tracks':len(records),'source_c_gbs_frames':frames,'source_c_gbs_register_bytes':frames*64}
