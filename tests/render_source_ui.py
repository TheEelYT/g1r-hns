"""Rasterize actual SourceUI Lua draw calls, preserving pixels and glyph colors."""
import argparse,json,subprocess,math
from pathlib import Path
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--engine',type=Path,required=True);p.add_argument('--mod',type=Path,required=True);p.add_argument('--luajit',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True);capture=a.out/'source_ui_draws.lua'
subprocess.check_call([str(a.luajit.resolve()),str(Path(__file__).with_suffix('.lua').resolve()),str(a.mod.resolve()),str(capture.resolve())],cwd=a.engine)
frames=json.loads(subprocess.check_output([str(a.luajit.resolve()),str(a.engine.resolve()/'tools/lua_to_json.lua'),str(capture.resolve())]))
# Check the complete native draw route, not only the terrain resolver/helper.
for frame in frames:
    name=frame['name'];calls=frame['draws']
    if name.startswith('battle_full_'):
        _,_,style,terrain,mode=name.split('_')
        first=next(c for c in calls if c['op']=='image')
        assert first['file']==f'battle/GRASS_{terrain}_Day.rgba',name
        if mode in ('menu','moves'):
            assert any(c['op']=='image'and c['file']=='ui/frame.rgba'for c in calls),name
        if mode=='menu':
            prompt=next(c for c in calls if c['op']=='image'and c['file']==f'battle/{style}_ballPrompt.rgba')
            assert prompt['ih']==64 and prompt['x']==-2 and prompt['y']==28,name
            assert any(c['op']=='image'and c['file']=='services/item_4.rgba'and c['x']==-2 and c['y']==52 for c in calls),name
        else:
            assert not any(c['op']=='image'and 'ballPrompt'in c['file']for c in calls),name
        if mode=='none':
            assert any(c['op']=='image'and c['y']==121 and c['x']==16 and 'normal' in c['file']for c in calls),name
    elif name.startswith('battle_entry_gen'):
        background=[c for c in calls if c['op']=='image'and c['file']=='battle/GRASS_modern_Day_intro_bg.rgba']
        assert background and all(c['iw']==512 for c in background),name
        state=frame['entryState']
        for y in range(max(0,state['top']),min(112,state['bottom'])):
            for x in range(240):
                matches=[c for c in background if c['x']<=x<c['x']+c['q'][2]and c['y']<=y<c['y']+c['q'][3]]
                assert len(matches)==1,(name,x,y)
                c=matches[0]
                assert c['q'][0]+x-c['x']==(x+(state['scan']if y<80 else -state['scan']))%512,(name,x,y)
                assert c['q'][1]+y-c['y']==y,(name,x,y)
        for c in (c for c in calls if c['op']=='image'and c['file']=='battle/GRASS_modern_Day_entry.rgba'):
            assert c['q'][0]==(c['x']+state['x'])%256,name
            assert c['q'][1]==c['y']+state['y'],name
            assert c['color'][3]==state['alpha']/16,name
        assert not any(c['op']=='image'and any(c['file'].endswith('_'+suffix+'.rgba')for suffix in ('wall','enemy','player'))for c in calls),name
        assert any(c['op']=='image'and c['file']=='battle/GRASS_modern_Day_entry.rgba'for c in calls)==(not name.endswith('_154')),name
    elif name=='battle_entry_fast':
        assert not any(c['op']=='image'and c['file'].endswith(('_entry.rgba','_intro_bg.rgba'))for c in calls),name
cache={}
for frame in frames:
    im=Image.new('RGBA',(240,160),(107,170,107,255));d=ImageDraw.Draw(im)
    for call in frame['draws']:
        rgba=tuple(round(c*255) for c in call['color']);canvas=im;im=Image.new('RGBA',canvas.size);d=ImageDraw.Draw(im)
        if call['op']=='rect':
            x,y,w,h=[round(call[k]) for k in ('x','y','w','h')];layer=Image.new('RGBA',im.size);ImageDraw.Draw(layer).rectangle((x,y,x+w-1,y+h-1),**({'outline':rgba}if call['mode']=='line'else{'fill':rgba}));im.alpha_composite(layer);d=ImageDraw.Draw(im)
        elif call['op']=='polygon':
            z=call['points'];d.polygon(list(zip(z[::2],z[1::2])),fill=rgba)
        else:
            key=call['file']
            if key not in cache:cache[key]=Image.frombytes('RGBA',(call['iw'],call['ih']),(a.mod/key).read_bytes())
            x,y,w,h=call['q'];piece=cache[key].crop((x,y,x+w,y+h))
            if rgba!=(255,255,255,255):
                piece=Image.frombytes('RGBA',piece.size,bytes(v*rgba[i%4]//255 for i,v in enumerate(piece.tobytes())))
            angle=call.get('rotation',0);co=math.cos(angle);si=math.sin(angle);sx=call['sx'];sy=call['sy'];px=call['x'];py=call['y'];ox=call.get('ox',0);oy=call.get('oy',0)
            if angle==0 and sx==1 and sy==1:im.alpha_composite(piece,(round(px-ox),round(py-oy)))
            else:im.alpha_composite(piece.transform(im.size,Image.Transform.AFFINE,(co/sx,si/sx,ox-(co*px+si*py)/sx,-si/sy,co/sy,oy+(si*px-co*py)/sy),Image.Resampling.NEAREST))
        if call.get('clip'):
            x,y,w,h=call['clip'];clipped=Image.new('RGBA',im.size);clipped.paste(im.crop((x,y,x+w,y+h)),(x,y));im=clipped
        canvas.alpha_composite(im);im=canvas;d=ImageDraw.Draw(im)
    im.save(a.out/(frame['name']+'.png'))
montage=Image.new('RGB',(4*480,((len(frames)+3)//4)*352),(24,24,32));d=ImageDraw.Draw(montage)
for i,f in enumerate(frames):
    x=i%4*480;y=i//4*352;d.text((x+8,y+6),f['name'],fill='white');montage.paste(Image.open(a.out/(f['name']+'.png')).resize((480,320),Image.Resampling.NEAREST),(x,y+28))
montage.save(a.out/'overview.png');print(json.dumps({'screens':len(frames),'overview':str(a.out/'overview.png')}))
