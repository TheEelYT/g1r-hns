"""Compile only source sound data, never a game ROM, into native M4A packs.

GNU as can assemble these data-only directives on the host. ARM .word and
.align are explicitly translated to their 32-bit/power-of-two equivalents.
Pinned mid2agb/wav2agb preserve source instruments, sample loops and sequences.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile

BASE=0x2000  # Below script variable range 0x4000: audio operands are immediates.
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
TOOLS=ROOT/'.tools/hns-audio'

def run(args,**kw):
    subprocess.run([str(a) for a in args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kw)

def tools(source):
    TOOLS.mkdir(parents=True,exist_ok=True)
    for name,standard in [('mid2agb','c++11'),('wav2agb','c++17')]:
        executable=TOOLS/name
        if not executable.exists():
            run(['g++','-std='+standard,'-O2','-Wno-switch',*sorted((source/'tools'/name).glob('*.cpp')),'-o',executable])

def translated(value):
    value='\n'.join(line.split('@',1)[0] for line in value.splitlines())
    value=value.replace('::',':')
    value=re.sub(r'\.align\s+(\d+)',lambda m:'.balign '+str(1<<int(m[1])),value)
    value=re.sub(r'\.word\b','.4byte',value)
    return value

def build(source,engine,stage,maps,source_maps,trainers,prepared,scripts):
    from build_port import lua
    tools(source)
    init=re.search(r'void m4aSoundInit\(void\)\s*\{(.*?)\n\}',(source/'src/m4a.c').read_text(),re.S)[1]
    max_channels=int(re.search(r'\((\d+)\s*<<\s*SOUND_MODE_MAXCHN_SHIFT\)',init)[1])
    frequency=re.search(r'SOUND_MODE_FREQ_(\d+)',init)[1]
    definitions=(source/'include/gba/m4a_internal.h').read_text()
    setting=int(re.search(r'#define SOUND_MODE_FREQ_'+frequency+r'\s+0x([0-9A-Fa-f]+)',definitions)[1],16)>>16
    sample_table=re.search(r'gPcmSamplesPerVBlankTable\[\]\s*=\s*\{(.*?)\};',(source/'src/m4a_tables.c').read_text(),re.S)[1]
    samples_per_vblank=int(re.findall(r'\d+',sample_table)[setting-1])
    assert 1<=max_channels<=15 and samples_per_vblank>0
    # The pinned engine captures FireRed's five-channel limit in a private
    # closure. Derive a source-owned copy with one configurable limit; runtime
    # dispatch uses it only for tagged HnS slots, preserving native playback.
    sequencer=(engine/'src/core/game3/m4a_seq.lua').read_text()
    needle='if count >= MAX_DS then'
    if sequencer.count(needle)!=1:raise ValueError('pinned M4A channel allocator changed')
    (stage/'hns_m4a_seq.lua').write_text('-- Derived from pinned Gen1Recomp m4a_seq.lua; source-scoped channel limit.\n'+sequencer.replace(needle,'if count >= (player.hnsMaxDsChannels or MAX_DS) then'))
    table=re.findall(r'^\s*song (\w+),\s*(\w+),\s*(\d+)',(source/'sound/song_table.inc').read_text(),re.M)
    names={symbol.upper():i for i,(symbol,_,_) in enumerate(table)}
    def sid(name):
        if name in ('MUS_NONE','MUS_DUMMY'):return 0
        if name not in names:raise ValueError('source song absent from table: '+name)
        return BASE+names[name]
    map_songs={mid:sid(source_maps[m['hnsSourceId']]['music']) for mid,m in maps.items()}
    roles={
        'battleWild':'MUS_HG_VS_WILD','battleTrainer':'MUS_HG_VS_TRAINER','battleGymLeader':'MUS_HG_VS_GYM_LEADER',
        'battleRival':'MUS_HG_VS_RIVAL','battleChampion':'MUS_HG_VS_CHAMPION',
        'victoryWild':'MUS_HG_VICTORY_WILD','victoryTrainer':'MUS_HG_VICTORY_TRAINER','victoryGymLeader':'MUS_HG_VICTORY_GYM_LEADER',
        'heal':'MUS_HG_HEAL','levelUp':'MUS_HG_LEVEL_UP','obtainItem':'MUS_HG_OBTAIN_ITEM',
        'caught':'MUS_HG_CAUGHT','evolution':'MUS_HG_EVOLUTION','evolved':'MUS_HG_EVOLVED',
        'surf':'MUS_HG_SURF','cycling':'MUS_HG_CYCLING','encounterRival':'MUS_HG_ENCOUNTER_RIVAL',
    }
    # HnS's fanfare table substitutes these for the corresponding Emerald cue.
    fanfare_rows=re.search(r'sFanfaresHnS\[\]\s*=\s*\{(.*?)\};',(source/'src/sound.c').read_text(),re.S)[1]
    fanfares={name:int(frames) for name,frames in re.findall(r'\{\s*(MUS_\w+),\s*(\d+)\s*\}',fanfare_rows)}
    aliases={}
    for role,name in roles.items():
        native={'battleWild':'MUS_VS_WILD','battleTrainer':'MUS_VS_TRAINER','battleGymLeader':'MUS_VS_GYM_LEADER',
                'battleRival':'MUS_VS_RIVAL','battleChampion':'MUS_VS_CHAMPION','victoryWild':'MUS_VICTORY_WILD',
                'victoryTrainer':'MUS_VICTORY_TRAINER','victoryGymLeader':'MUS_VICTORY_GYM_LEADER',
                'heal':'MUS_HEAL','levelUp':'MUS_LEVEL_UP','obtainItem':'MUS_OBTAIN_ITEM','caught':'MUS_CAUGHT',
                'evolution':'MUS_EVOLUTION','evolved':'MUS_EVOLVED','surf':'MUS_SURF','cycling':'MUS_CYCLING',
                'encounterRival':'MUS_ENCOUNTER_BOY'}[role]
        if role!='encounterRival':aliases[native]=sid(name)
    for name in fanfares:
        native=name.replace('MUS_HG_','MUS_')
        if native in ('MUS_OBTAIN_TMHM','MUS_OBTAIN_BADGE','MUS_OBTAIN_BERRY','MUS_MOVE_DELETED'):aliases[native]=sid(name)
    aliases['MUS_RG_OBTAIN_KEY_ITEM']=sid('MUS_HG_OBTAIN_KEY_ITEM')
    selected={value-BASE for value in map_songs.values() if value}
    selected.update(names[v] for v in roles.values());selected.update(names[v] for v in fanfares)
    for rows in scripts.values():
        for row in rows:
            if row.get('songName'):selected.add(names[row['songName']])
    selected.add(names['MUS_HG_OAK'])
    selected.update(names[n]for n in ('MUS_HG_INTRO','MUS_HG_TITLE'))
    for name in names:
        if name in ('MUS_HG_NEW_GAME','MUS_HG_FOLLOW_ME_2') or name.startswith('MUS_HG_RADIO_'):selected.add(names[name])
    for tid,record in trainers['records'].items():
        music='MUS_HG_ENCOUNTER_'+prepared['rosters'][record['source']]['header']['Music'].removeprefix('Hg ').upper().replace(' ','_')
        if music=='MUS_HG_ENCOUNTER_SILVER':music='MUS_HG_ENCOUNTER_RIVAL'
        # Source defines use BOY_1/GIRL_1, SAGE etc.
        if music not in names:raise ValueError('unmapped encounter music: '+music)
        record['encounterMusic']=sid(music);selected.add(names[music])
    cfg={line.split(':',1)[0].removesuffix('.mid'):shlex.split(line.split(':',1)[1]) for line in (source/'sound/songs/midi/midi.cfg').read_text().splitlines() if ':' in line and not line.startswith('#')}
    # Cache is derived only from pinned source assets, converter and extraction
    # script; reusing it cannot change runtime file timestamps on release builds.
    fingerprint=hashlib.sha256()
    for path in sorted((source/'sound').rglob('*')):
        if path.is_file():fingerprint.update(path.relative_to(source).as_posix().encode());fingerprint.update(path.read_bytes())
    fingerprint.update(Path(__file__).read_bytes());fingerprint.update((HERE/'audio_extract.lua').read_bytes())
    fingerprint.update((engine/'src/import/gba/extract_audio.lua').read_bytes())
    fingerprint.update((engine/'src/import/LuaWriter.lua').read_bytes())
    fingerprint.update(','.join(map(str,sorted(selected))).encode())
    cache=TOOLS/'cache'/fingerprint.hexdigest();target=stage/'audio'
    if not cache.exists():
        with tempfile.TemporaryDirectory(dir=TOOLS) as temp:
            temp=Path(temp);blocks={}
            incs=[*sorted((source/'sound/voicegroups').rglob('*.inc')),source/'sound/keysplit_tables.inc',source/'sound/direct_sound_data.inc',source/'sound/programmable_wave_data.inc']
            for path in incs:
                content='\n'.join(line.split('@',1)[0] for line in path.read_text().splitlines())
                content=re.sub(r'^\s*\.(?:if|else|endif)\b[^\n]*','',content,flags=re.M)
                content=re.sub(r'^\s*voice_group (\w+)(?:,\s*(\d+))?\s*$',lambda m:'voicegroup_'+m[1]+':\n .space '+str(int(m[2] or 0)*12),content,flags=re.M)
                content=re.sub(r'^\s*keysplit (\w+)(?:,\s*(\d+))?\s*$',lambda m:'keysplit_'+m[1]+':\n .space '+str(int(m[2] or 0))+'\n .set _last_note,'+str(int(m[2] or 0))+'\n .set _last_split,0',content,flags=re.M)
                content=re.sub(r'^\s*\.set (KeySplitTable\w+),\s*\. - (\d+)\s*$',lambda m:m[1]+':\n .space '+m[2],content,flags=re.M)
                for match in re.finditer(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',content,re.M|re.S):blocks[match[1]]=translated(match[1]+':\n'+match[2])
            # The source deliberately lets HGSS/DPPt main-bank instruments
            # continue into the next physical bank. Reproduce those tone rows
            # before padding, while keeping the next bank's independent label.
            # Zero padding at this boundary would silence National Park's piano.
            bank_order=re.findall(r'\.include "sound/voicegroups/(voicegroup\d+)\.inc"',(source/'sound/voice_groups.inc').read_text())
            for i,name in enumerate(bank_order):
                original=(source/'sound/voicegroups'/(name+'.inc')).read_text()
                if 'remaining voices wrap around' not in original:continue
                rows=re.findall(r'^\s*voice_\w+[^\n]*',blocks[name],re.M)
                needed=128-len(rows)
                continuation=[]
                for following in bank_order[i+1:]:
                    continuation+=re.findall(r'^\s*voice_\w+[^\n]*',blocks[following],re.M)
                    if len(continuation)>=needed:break
                if needed<0 or len(continuation)<needed:raise ValueError('incomplete source voice-bank continuation: '+name)
                blocks[name]+='\n'+'\n'.join(continuation[:needed])+'\n'
            songs=[];required=set()
            for index in sorted(selected):
                name=table[index][0]
                midi=source/'sound/songs/midi'/(name+'.mid')
                if midi.exists():
                    out=temp/(name+'.s');run([TOOLS/'mid2agb',midi,out,*cfg[name]]);content=out.read_text()
                else:
                    files=list((source/'sound/songs').rglob(name+'.s'))
                    if len(files)!=1:raise ValueError('missing source assembly for '+name)
                    content=files[0].read_text()
                content=re.sub(r'^\s*\.include.*$','',content,flags=re.M)
                content=re.sub(r'^\s*\.section.*$','',content,flags=re.M)
                content=re.sub(r'^\s*\.end\s*$','',content,flags=re.M)
                content=translated(content);songs.append(content)
                required.update(v for v in re.findall(r'\b\w+\b',content) if v in blocks)
            pending=list(required)
            while pending:
                name=pending.pop()
                for dep in re.findall(r'\b\w+\b',blocks[name]):
                    if dep in blocks and dep not in required:required.add(dep);pending.append(dep)
            assets=[]
            for name in sorted(required):
                block=blocks[name]
                def incbin(match):
                    path=source/match[1]
                    if not path.exists():
                        wav=path.with_suffix('.wav')
                        if not wav.exists():raise ValueError('missing source sample '+str(wav))
                        out=temp/(name+'.bin');run([TOOLS/'wav2agb','-b',wav,out]);path=out
                    return '.incbin "'+str(path)+'"'
                block=re.sub(r'\.incbin "([^"]+)"',incbin,block)
                # Small subgroup tables must be padded to 128 tones so native
                # extraction does not interpret the following unrelated data.
                if name.startswith('voicegroup'):
                    block=' .balign 4\n'+block+'\n .space 1536-(.-'+name+'),0\n'
                if name.startswith('keysplit_') or name.startswith('KeySplitTable'):
                    block+='\n .space 128-(.-'+name+'),0\n'
                assets.append(block)
            asm=translated((source/'sound/MPlayDef.s').read_text())+'\n'+translated((source/'asm/macros/music_voice.inc').read_text())+'\n'+translated((source/'asm/macros/m4a.inc').read_text())+'\n'+ '\n'.join(assets+songs)
            (temp/'sounds.s').write_text(asm)
            try:
                run(['as','-o',temp/'sounds.o',temp/'sounds.s'])
                run(['ld','-Ttext=0x08000000','-o',temp/'sounds.elf',temp/'sounds.o'])
                run(['objcopy','-O','binary',temp/'sounds.elf',temp/'sounds.bin'])
            except subprocess.CalledProcessError as exc:raise ValueError(exc.stderr.decode()[:10000]) from exc
            nm=subprocess.check_output(['nm','-n',temp/'sounds.elf'],text=True)
            symbols={m[3]:int(m[1],16) for line in nm.splitlines() if (m:=re.fullmatch(r'([0-9a-f]+) (\w) (\S+)',line))}
            records={str(BASE+i):{'name':table[i][0].upper(),'header':symbols[table[i][0]]-0x08000000,'player':0,
                      'kind':'fanfare' if table[i][0].upper() in fanfares else 'bgm',
                      'fanfareFrames':fanfares.get(table[i][0].upper())} for i in sorted(selected)}
            (temp/'songs.lua').write_text('return '+lua(records))
            out=temp/'pack';out.mkdir();(out/'songs').mkdir()
            luajit=os.environ.get('HNS_LUAJIT') or shutil.which('luajit') or ROOT/'.tools/LuaJIT/src/luajit'
            try:run([luajit,HERE/'audio_extract.lua',temp/'sounds.bin',temp/'songs.lua',out],cwd=engine)
            except subprocess.CalledProcessError as exc:raise ValueError(exc.stderr.decode()) from exc
            cache.parent.mkdir(parents=True,exist_ok=True);shutil.copytree(out,cache)
    shutil.copytree(cache,target)
    for mid,m in maps.items():m['music']=map_songs[mid]
    cues={}
    for key,rows in scripts.items():
        additions=[]
        for i,row in enumerate(rows,1):
            if row['op']=='message':
                label=row.get('ptr','')
                sound=None
                if label.endswith(('ReceivedStarter','POTION_RECEIVED_TEXT','BALLS_RECEIVED_TEXT')):sound='MUS_HG_OBTAIN_ITEM'
                if label.endswith('MrPokemonHouse_Text_GotEgg'):sound='MUS_HG_OBTAIN_KEY_ITEM'
                if label.endswith('MrPokemonHouse_Text_GetDex'):sound='MUS_HG_OBTAIN_ITEM'
                if label.endswith('NewBarkTown_Lab_Text_ElmAfterTheft2'):sound='MUS_HG_LEVEL_UP'
                if sound:
                    additions.append({'before':i,'rows':[{'op':'playfanfare','songName':sound}]})
                    # Wait after the message has opened, while its receipt text is visible.
                    additions.append({'after':i,'rows':[{'op':'waitfanfare'}]})
                if label.endswith('MrPokemonHouse_Text_OakIntro'):additions.append({'before':i,'rows':[{'op':'playbgm','songName':'MUS_HG_OAK'}]})
                if label.endswith('MrPokemonHouse_Text_Heal'):additions.append({'before':i,'rows':[{'op':'fadedefaultbgm'}]})
            if row['op']=='callnative' and row.get('fn')==opening_heal_native():
                if key=='HNS_WORLD_NURSE_HEAL':
                    additions.append({'before':i,'rows':[{'op':'dofieldeffect',1:25},{'op':'waitfieldeffect',1:25}]})
                else:
                    additions.append({'before':i,'rows':[{'op':'fadescreen',1:1},{'op':'playfanfare','songName':'MUS_HG_HEAL'},{'op':'waitfanfare'}]})
            if row['op']=='waitstate' and i>1 and rows[i-2].get('fn')==opening_heal_native() and key!='HNS_WORLD_NURSE_HEAL':
                additions.append({'after':i,'rows':[{'op':'fadescreen',1:0}]})
            if row['op']=='setflag' and row.get('flag')==0x6017:additions.append({'after':i,'rows':[{'op':'playfanfare','songName':'MUS_HG_OBTAIN_BERRY'},{'op':'waitfanfare'}]})
        if key=='HNS_QUEST_RIVAL_CORE':additions.append({'before':1,'rows':[{'op':'playbgm','songName':'MUS_HG_ENCOUNTER_RIVAL'}]})
        if additions:cues[key]=additions
    return {'base':BASE,'songs':{str(BASE+i):table[i][0].upper() for i in sorted(selected)},
            'roles':{k:sid(v) for k,v in roles.items()},'aliases':aliases,'mapSongs':map_songs,
            'fanfares':{str(sid(k)):{'frames':v,'name':k} for k,v in fanfares.items()},
            'oak':sid('MUS_HG_OAK'),'cues':cues,'songCount':len(selected),'sampleBytes':(target/'samples.bin').stat().st_size,
            'soundMode':{'maxDsChannels':max_channels,'samplesPerVBlank':samples_per_vblank,'frequencySetting':int(frequency)},
            'sourceFingerprint':fingerprint.hexdigest()}

def opening_heal_native():
    import opening
    return opening.HEAL_NATIVE
