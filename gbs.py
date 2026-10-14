"""Source-only GBS streams/tables and a host-compiled source timing oracle."""
import hashlib,re,shutil,subprocess,tempfile
from pathlib import Path
from audio import translated,TOOLS


def run(args,**kw):
    try:return subprocess.run(args,check=True,capture_output=True,**kw)
    except subprocess.CalledProcessError as exc:raise ValueError((exc.stderr.decode()if isinstance(exc.stderr,bytes)else exc.stderr)or str(exc))from exc


def compile_source(source,root):
    by_header={h:p for p in (source/'sound/songs/gbs').rglob('*.s')for h in re.findall(r'^\s*\.global\s+(\w+_Header)',p.read_text(),re.M)}
    asm=translated((source/'asm/macros/asm.inc').read_text())+'\n'+translated((source/'asm/macros/gbs.inc').read_text())+'\n.set voicegroup000,0\n'
    for path in sorted(set(by_header.values())):
        text=re.sub(r'^\s*\.(?:include|section)\b[^\n]*','',path.read_text(),flags=re.M)
        asm+=translated(re.sub(r'\bvoicegroup\d+\b','voicegroup000',text))+'\n'
    (root/'songs.s').write_text(asm)
    for args in [('as','-o',root/'songs.o',root/'songs.s'),('ld','-Ttext=0','-o',root/'songs.elf',root/'songs.o'),('objcopy','-O','binary',root/'songs.elf',root/'songs.bin')]:run(list(map(str,args)))
    symbols={m[3]:int(m[1],16)for line in subprocess.check_output(['nm','-n',str(root/'songs.elf')],text=True).splitlines()if(m:=re.fullmatch(r'([0-9a-f]+) (\w) (\S+)',line))}
    header=re.sub(r'^#include.*$','',(source/'include/gbs.h').read_text(),flags=re.M)
    implementation=re.sub(r'^#include.*$','',(source/'src/gbs.c').read_text(),flags=re.M)
    implementation=implementation[:implementation.index('void ply_gbs_switch')]+implementation[implementation.index('static inline bool32 IsM4AUsingCGBChannel(int channel)\n{'):]
    prefix,suffix=(Path(__file__).parent/'gbs_trace.c').read_text().split('/* SOURCE */')
    (root/'trace.c').write_text(prefix+header+'\n#define MusicPlayerTrack GBSTrack\n'+(source/'src/data/gbs.h').read_text()+'\n'+implementation+suffix)
    run(['gcc','-O2','-Werror','-std=gnu99',str(root/'trace.c'),'-o',str(root/'trace')])
    return symbols,by_header


def tables(source):
    code=re.sub(r'//[^\n]*','',(source/'src/data/gbs.h').read_text())
    def nums(body):return [int(n,0)if n!='NOISE_DATA_END'else 255 for n in re.findall(r'0x[0-9A-Fa-f]+|\b\d+\b|NOISE_DATA_END',body)]
    frequency=nums(re.search(r'sFrequencyTable\[\]\s*=\s*\{(.*?)\};',code,re.S)[1]);frequency=[n-65536 if n>=32768 else n for n in frequency]
    waves=[nums(row)for row in re.findall(r'\{([^{}]*)\}',re.search(r'sWaveTrackPatterns\[\]\[16\]\s*=\s*\{(.*?)\};',code,re.S)[1])]
    noises={name:nums(body)for name,body in re.findall(r'(sNoiseData\d+)\[\]\s*=\s*\{(.*?)\};',code,re.S)}
    groups=[ [noises[n]for n in re.findall(r'sNoiseData\d+',body)]for _,body in sorted(re.findall(r'(sNoiseDataGroup\d+)\[\]\s*=\s*\{(.*?)\};',code,re.S))]
    return {'frequency':frequency,'waves':waves,'groups':groups}


def build(source,stage,audio):
    from build_port import lua
    mapping={name:header for name,header in re.findall(r'^\s*song_gbs\s+(\w+),\s*(\w+)',(source/'sound/song_table.inc').read_text(),re.M)}
    selected={sid:mapping[name]for sid,name in audio['songs'].items()if name in mapping}
    with tempfile.TemporaryDirectory(dir=TOOLS)as temp:
        root=Path(temp);symbols,files=compile_source(source,root)
        dest=stage/'gbs';dest.mkdir();shutil.copyfile(root/'songs.bin',dest/'songs.bin')
        data=tables(source);(dest/'tables.lua').write_text('return '+lua(data))
        records={sid:{'header':symbols[h],'source':files[h].relative_to(source).as_posix(),'name':h}for sid,h in selected.items()}
    fingerprint=hashlib.sha256((dest/'songs.bin').read_bytes()+(dest/'tables.lua').read_bytes()).hexdigest()
    return {'songs':records,'file':'gbs/songs.bin','tables':'gbs/tables.lua','trackCount':len(set(selected.values())),'songCount':len(selected),'sourceFingerprint':fingerprint,
            'flag':0x20,'onText':'The GB Player was turned on.\nSounds from the past fill the air.','offText':'The GB Player was turned off.\nSounds of nostalgia fade away.',
            'limits':'Source GBS music/fanfare bytecode, fractional timing, loops, envelopes, modulation and drums use the native PSG mixer. GB cry remaps, hardware SFX arbitration and exact analog PSG behavior remain pending.'}
