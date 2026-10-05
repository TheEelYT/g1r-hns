"""HnS opening artwork, title OAM frames, and private native screen derivatives."""
from pathlib import Path
import struct
from PIL import Image


def palette(path):
    if not path.exists():
        im=Image.open(path.with_suffix('.png'));p=im.getpalette()
        return [(p[i]>>3)|((p[i+1]>>3)<<5)|((p[i+2]>>3)<<10)for i in range(0,len(p),3)]
    lines=path.read_text().splitlines();n=int(lines[2])
    return [(r>>3)|((g>>3)<<5)|((b>>3)<<10)for r,g,b in (map(int,x.split())for x in lines[3:3+n])]


def tiles(path,bpp=4):
    im=Image.open(path);assert im.mode=='P' and im.width%8==0 and im.height%8==0
    return [list(im.crop((x,y,x+8,y+8)).tobytes()) for y in range(0,im.height,8)for x in range(0,im.width,8)]


def text_map(tiledata,words,w,h,colors=None,bpp=4):
    data=bytearray(w*h*(4 if colors is not None else 1))
    for y in range(h):
        for x in range(w):
            word=words[(y//8)*32+x//8];tid=word&1023;px=x%8;py=y%8
            if word&1024:px=7-px
            if word&2048:py=7-py
            n=tiledata[tid][py*8+px]+((word>>12)*16 if bpp==4 else 0)
            if colors is None:data[y*w+x]=n
            else:
                c=colors[n];pos=(y*w+x)*4
                data[pos:pos+4]=bytes((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255))
    return data


def build(source,engine,stage):
    out=stage/'boot';out.mkdir();intro={};title={'layers':{},'sprites':{},'palettes':{}}
    def rgba(name,w,h,data):
        assert len(data)==w*h*4,(name,w,h,len(data))
        file='boot/'+name+'.rgba';(stage/file).write_bytes(data);return {'file':file,'width':w,'height':h,'w':w,'h':h}
    root=source/'graphics/intro_frlg'
    for name,rel,pal in [('introGfText','game_freak/game_freak','game_freak/logo'),('introGfLogo','game_freak/logo','game_freak/logo'),
        ('introStar','game_freak/star','game_freak/star'),('introSparklesSmall','game_freak/sparkles_small','game_freak/sparkles'),('introSparklesBig','game_freak/sparkles_big','game_freak/sparkles')]:
        im=Image.open(root/(rel+'.png'));colors=palette(root/(pal+'.pal'));data=bytearray()
        for n in im.tobytes():
            if name=='introGfText':n=15-(n>>4)
            c=colors[n];data.extend((round((c&31)*255/31),round((c>>5&31)*255/31),round((c>>10&31)*255/31),255 if n else 0))
        intro[name]=rgba(name,im.width,im.height,data)
    for name,rel in [('introCopyright','copyright'),('introGfBg','game_freak/bg')]:
        words=list(struct.unpack('<'+str((root/(rel+'.bin')).stat().st_size//2)+'H',(root/(rel+'.bin')).read_bytes()))
        colors=palette(root/(rel+'.pal'));colors=colors+[0]*(256-len(colors))
        intro[name]=rgba(name,256,160,text_map(tiles(root/(rel+'.png')),words,256,160,colors))
    root=source/'graphics/title_screen/hns'
    bg=palette(root/'pokemon_logo.pal')+palette(root/'rayquaza_and_clouds.pal');title['palettes']['bg']=bg
    def index(name,w,h,data,bpp):
        raw=bytearray();
        for n in data:raw.extend((n,0,0,255))
        a=rgba(name,w,h,raw);a['bpp']=bpp;return a
    words=list((root/'pokemon_logo.bin').read_bytes());td=tiles(root/'pokemon_logo.png',8)
    logo=bytearray(256*256)
    for y in range(256):
        for x in range(256):logo[y*256+x]=td[words[y//8*32+x//8]][y%8*8+x%8]
    title['layers']['logo']=index('titleLogo',256,256,logo,8)
    raw=(root/'rayquaza.bin').read_bytes();words=list(struct.unpack('<'+str(len(raw)//2)+'H',raw))
    title['layers']['rayquaza']=index('titleBackdrop',256,160,text_map(tiles(root/'rayquaza.png'),words,256,160),8)
    def sprite(name,filename,w,h,offset,frames,bpp):
        im=Image.open(root/filename);td=tiles(root/filename,bpp);data=bytearray()
        for y in range(h*frames):
            for x in range(w):
                tid=offset+(y//h)*(w*h//64)+(y%h//8)*(w//8)+x//8
                data.append(td[tid][y%8*8+x%8]&(255 if bpp==8 else 15))
        a=index(name,w,h*frames,data,bpp);a.update(w=w,h=h,anims=[[{'op':'frame','frame':i,'duration':4},{'op':'end'}]for i in range(frames)])
        title['sprites'][name]=a
        pal=im.getpalette();return [(pal[i]>>3)|((pal[i+1]>>3)<<5)|((pal[i+2]>>3)<<10)for i in range(0,len(pal),3)]
    title['palettes']['version']=sprite('version_banner_left','emerald_version.png',64,32,0,1,8)
    sprite('version_banner_right','emerald_version.png',64,32,32,1,8)
    title['palettes']['pressStart']=sprite('press_start','press_start.png',32,8,1,10,4)[:16]
    sprite('logo_shine','logo_shine.png',64,64,0,1,4)
    title['alphaBlend']=[[16,min(i,16)]if i<=16 else[max(0,32-i),16]for i in range(64)]
    # Keep the pinned engine untouched. Patch only private copies of its machines.
    code=(engine/'src/ui/game3/rse/title_rse.lua').read_text()
    code=code.replace('local Title = {}','local Source\nlocal Title = {}\nfunction Title.configure(s) Source=s end')
    code=code.replace('machine:manifest(Title.MANIFEST)','Source.manifest').replace('Machine.layer(', 'Source.layer(').replace('Machine.template(', 'Source.template(')
    code=code.replace('self.clouds = self:layer("clouds")','self.clouds = nil').replace('local song = songId(self.params.song)','local song = Source.song').replace('Title.songFrames(song)','Source.songFrames')
    # The function declaration itself must retain its original name.
    code=code.replace('function Source.songFrames','function Title.songFrames')
    a=code.index('function Title.songFrames');b=code.index('function Title.new',a);code=code[:a]+'function Title.songFrames()return Source.songFrames end\n\n'+code[b:]
    a=code.index('      local w = ppu.scanline:initWave');b=code.index('      self.phase = "phase1"',a);code=code[:a]+code[b:]
    code=code.replace('self:createPressStartBanner(START_BANNER_X, 108)','self:createPressStartBanner(START_BANNER_X, 138)')
    code=code.replace('Sprites.startAnim(s, i + NUM_PRESS_START_FRAMES)','Sprites.startAnim(s, i + NUM_PRESS_START_FRAMES)\n    s.data[0] = 1')
    code=code.replace('Palette.rgb(24, 31, 12)','Palette.rgb(1, 1, 1)').replace('self:updateLegendaryMarkingColor(band(d[0], 0xFF))','-- HnS has no Emerald legendary marking cycle')
    (stage/'hns_title.lua').write_text(code)
    code=(engine/'src/ui/game3/intro_movie.lua').read_text().replace('local IntroMovie = {}','local Source\nlocal IntroMovie = {}\nfunction IntroMovie.configure(s)Source=s end')
    code=code.replace('    self.pal:reset()\n    Bg.initFromTemplates({ { bg = 0','    self.pal:reset()\n    Audio.playSong(Source.song,{restart=true})\n    Bg.initFromTemplates({ { bg = 0',1)
    code=code.replace('    Audio.playSong(Song.MUS_GAME_FREAK, { restart = true })','    -- HnS keeps HG_INTRO playing here.')
    a=code.index('    -- pokefirered/src/intro.c:2108');b=code.index('    p.timer = 0',a);code=code[:a]+code[b:]
    a=code.index('function IntroMovie.IntroCB_GF_RevealLogo');b=code.index('-- Scene 1',a)
    part=code[a:b].replace('p.timer > 90','p.timer > 80').replace('p.timer > 20','p.timer > 10').replace('self:setCB("Scene1")','self:setCB("ExitToTitleScreen")');code=code[:a]+part+code[b:]
    (stage/'hns_intro.lua').write_text(code)
    return {'intro':intro,'title':title}
