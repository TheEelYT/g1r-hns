"""Reviewed GB mart conversion erratum: keep the source MIDI intro outside loop."""
import re,struct
from fractions import Fraction

def midi_markers(path):
    data=path.read_bytes();assert data[:4]==b'MThd'
    division=struct.unpack('>H',data[12:14])[0];assert division<32768
    size=struct.unpack('>I',data[18:22])[0];track=data[22:22+size];p=0;tick=0;running=0;markers={}
    def vlq():
        nonlocal p
        value=0
        while True:
            n=track[p];p+=1;value=(value<<7)|(n&127)
            if n<128:return value
    while p<len(track):
        tick+=vlq();status=track[p]
        if status>=128:p+=1
        else:status=running
        if status==255:
            kind=track[p];p+=1;n=vlq();value=track[p:p+n];p+=n
            if kind==6:markers[value.decode()]=tick
        elif status in (240,247):
            n=vlq();p+=n
        else:
            running=status;p+=1 if status&240 in (192,208)else 2
    return division,markers

def fix(source,text):
    midi='sound/songs/midi/mus_hg_poke_mart.mid'
    division,markers=midi_markers(source/midi)
    units=Fraction(markers['['],division)*4;assert units.denominator==1
    units=int(units);assert units==32
    # The GB arrangement repeats the MIDI's body twice. Its transcription
    # stops one sixteenth-note unit before that whole-bar boundary.
    body_units=Fraction(markers[']']-markers['['],division)*4
    assert body_units.denominator==1;body_units=int(body_units)
    assert body_units==448
    repeats=2;expected=units+repeats*body_units;assert expected==928
    # Player comparison identifies a silent gap, not a short note. Keep the
    # MIDI-grid repair separate from this one-unit reviewed listening adjustment.
    # This is an explicit conversion erratum, not a claim about the public MIDI.
    listening_gap=1
    totals=[]
    for ch in range(1,5):
        label=f'gbs_hg_poke_mart_Ch{ch}'
        start=text.index(label+':');end=text.index(f'sound_loop 0, {label}.mainloop',start)
        body=text[start:end];lines=body.splitlines(keepends=True);out=[];elapsed=0;inserted=False;octave=None;velocity=None
        for line in lines:
            if line.strip()==label+'.mainloop:':line=line.replace('.mainloop:', '.intro:')
            m=re.match(r'\s*octave (\d+)',line)
            if m:octave=m[1]
            m=re.match(r'\s*(?:note_type \d+,|volume_envelope)\s*(\d+),\s*(\d+)',line)
            if m:velocity=m.groups()
            note=re.match(r'\s*(?:note \w+,|rest|drum_note \d+,)\s*(\d+)',line)
            if note and elapsed==units and not inserted:
                out.append(label+'.mainloop:\n')
                if ch<4:
                    assert octave is not None and velocity is not None
                    out.append(f'\toctave {octave}\n\tnote_type 12, {velocity[0]}, {velocity[1]}\n')
                else:out.append('\tdrum_speed 12\n')
                inserted=True
            out.append(line)
            if note:elapsed+=int(note[1])
        assert inserted and elapsed==expected-1,(ch,elapsed)
        out.append(f'\trest {1+listening_gap}\t@ MIDI boundary plus reviewed silent loop gap\n')
        totals.append(elapsed+1+listening_gap);text=text[:start]+''.join(out)+text[end:]
    return text,{'sourceMidi':midi,'midiDivision':division,'midiLoopTick':markers['['],'midiLoopEndTick':markers[']'],'midiBodyUnits':body_units,'bodyRepeats':repeats,'tailPaddingUnits':1,'listeningGapUnits':listening_gap,'introUnits':units,'trackUnits':totals}
