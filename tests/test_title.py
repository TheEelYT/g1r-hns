"""Check queued title changes without building or publishing a mod release."""
import argparse, shutil, struct, subprocess, sys, tempfile
from pathlib import Path

repo=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(repo))
import boot_assets
from build_port import lua
from check_fields import check_title_font

p=argparse.ArgumentParser()
for name in ('source','engine','luajit'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args()
with tempfile.TemporaryDirectory(prefix='hns-title-')as temp:
    stage=Path(temp);boot=boot_assets.build(a.source,a.engine,stage)
    for name in ('boot_presentation.lua','title_caption.lua','source_ui.lua','intro_credits.lua'):
        shutil.copyfile(repo/'runtime'/name,stage/name)
    # Long silent source-format sequence keeps the title open for blink checks.
    # Music playback itself belongs to the full native/audio integration suite.
    (stage/'audio/songs').mkdir(parents=True)
    track=bytes([0xb0])*100+bytes([0xb1])
    (stage/'audio/songs/2.bin').write_bytes(struct.pack('<4B3I',1,0,0,0,0,16,len(track))+track)
    world={'startup':{'ui':{}},'audio':{'songs':{'1':'MUS_HG_INTRO','2':'MUS_HG_TITLE'}},'bootPresentation':boot}
    (stage/'world.lua').write_text('return '+lua(world)+'\n')
    print('Independent source title glyph checks:',check_title_font(a.source,stage,world),flush=True)
    subprocess.run([str(a.luajit.resolve()),str(repo/'tests/test_title.lua'),str(stage),str(repo)],cwd=a.engine,check=True)
