"""Run pinned C tileset callbacks to obtain exact frame, offset and timing data."""
import collections
import re
import subprocess
import tempfile
from pathlib import Path
from PIL import Image


def compile_callbacks(source, root):
    body=(source/'src/tileset_anims.c').read_text()
    body=re.sub(r'^#include.*$', '',body,flags=re.M)
    graphics=(source/'src/graphics.c').read_text()
    external='\n'.join(m[0] for m in re.finditer(r'const u16 (gTilesetAnims_BattleDomePals\w+)\[\]\s*=\s*INCBIN_U16\([^;]+;',graphics))
    body=external+'\n'+body
    # These functions interact with hardware/map globals, not animation logic.
    omitted={'ResetTilesetAnimBuffer','AppendTilesetAnimToBuffer','TransferTilesetAnimsBuffer','InitTilesetAnimations','InitSecondaryTilesetAnimation','UpdateTilesetAnimations','_InitPrimaryTilesetAnimation','_InitSecondaryTilesetAnimation'}
    for match in reversed(list(re.finditer(r'^(?:static )?void (\w+)\([^;]*?\)\s*\{',body,re.M))):
        if match[1] not in omitted:continue
        i=match.end();depth=1
        while depth:
            depth+=(body[i]=='{')-(body[i]=='}');i+=1
        body=body[:match.start()]+body[i:]
    frames=[]
    def frame(m):
        frames.append((m[1],tuple(re.findall(r'"([^"]+)"',m[2]))));return 'const u16 '+m[1]+'[8192] = {0};'
    body=re.sub(r'(?:static )?const u16(?: ALIGNED\(4\))? (\w+)\[\]\s*=\s*INCBIN_U16\((.*?)\);',frame,body)
    assert 'INCBIN_' not in body
    prefix='''#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef uint16_t u16;typedef uint8_t u8;typedef uint32_t u32;
#define EWRAM_DATA
#define IS_HNS 1
#define ALIGNED(x)
#define ARRAY_COUNT(x) (sizeof(x)/sizeof((x)[0]))
#define min(a,b) ((a)<(b)?(a):(b))
#define TILE_SIZE_4BPP 32
#define TILE_OFFSET_4BPP(x) ((x)*32)
#define BG_VRAM 0x10000000
#define BG_PLTT_ID(x) ((x)*16)
#define PLTT_SIZE_4BPP 32
#define TASK_NONE 255
static struct {int y;int blendColor;} gPaletteFade;
static u16 gPlttBufferUnfaded[256];
static int tick,channel;
static void Task_BattleTransition_Intro(void){}
static int FindTaskIdByFunc(void (*fn)(void)){return TASK_NONE;}
static void BlendPalette(int a,int b,int c,int d){}
static void AppendTilesetAnimToBuffer(const u16*,u16*,u16);
static void CpuCopy16(const u16*,u16*,int);
'''
    locate='static int locate(const u16 *src,int *offset){uintptr_t p=(uintptr_t)src;\n'
    for i,(name,_) in enumerate(frames):
        locate+=f'if(p>=(uintptr_t){name} && p<(uintptr_t)({name}+8192)){{*offset=p-(uintptr_t){name};return {i};}}\n'
    locate+='fprintf(stderr,"Unknown frame pointer\\n");exit(2);}\n'
    locate+='static void AppendTilesetAnimToBuffer(const u16 *src,u16 *dest,u16 size){int o=0;int f=locate(src,&o);printf("F %d %d %d %d %d %d\\n",channel,tick,f,o,((uintptr_t)dest-BG_VRAM)/32,size/32);}\n'
    locate+='static void CpuCopy16(const u16 *src,u16 *dest,int size){int o=0;int f=locate(src,&o);printf("P %d %d %d %d %d %d\\n",channel,tick,f,o,(int)(dest-gPlttBufferUnfaded)/16,size);}\n'
    init_names=re.findall(r'^void (InitTilesetAnim_\w+)\(void\)',body,re.M)
    main='static void init(const char *n){if(!strcmp(n,"NULL"))return;\n'
    for name in init_names:main+=f'if(!strcmp(n,"{name}")){{{name}();return;}}\n'
    main+='fprintf(stderr,"Unknown callback %s\\n",n);exit(3);}\nint main(int argc,char **argv){sSecondaryTilesetBaseTile=atoi(argv[3]);init(argv[1]);init(argv[2]);printf("M %d %d %d %d\\n",sPrimaryTilesetAnimCounterMax,sSecondaryTilesetAnimCounterMax,sPrimaryTilesetAnimCounter,sSecondaryTilesetAnimCounter);for(channel=0;channel<2;channel++){int max=channel?sSecondaryTilesetAnimCounterMax:sPrimaryTilesetAnimCounterMax;void(*fn)(u16)=channel?sSecondaryTilesetAnimCallback:sPrimaryTilesetAnimCallback;for(tick=0;tick<max;tick++)if(fn)fn(tick);}return 0;}\n'
    path=root/'callbacks.c';path.write_text(prefix+body+locate+main)
    subprocess.run(['gcc','-w','-O0',str(path),'-o',str(root/'callbacks')],check=True)
    return root/'callbacks',frames


def build(source,engine,stage,pairs,pair_mids,pair_defs,lua_encode,palette_parser):
    counts=collections.Counter();source_pixels={}
    with tempfile.TemporaryDirectory() as tmp:
        exe,frames=compile_callbacks(source,Path(tmp))
        for key,pair in pairs.items():
            callbacks=[pair.primary.spec['callback'],pair.secondary.spec['callback']]
            output=subprocess.check_output([str(exe),*callbacks,str(pair.n_primary)],text=True).splitlines()
            pmax,smax,pstart,sstart=map(int,output[0].split()[1:])
            grouped=collections.defaultdict(list)
            for line in output[1:]:
                kind,ch,t,f,off,dest,size=line.split();grouped[kind,int(ch),int(dest),int(size)].append((int(t),int(f),int(off)))
            banks=[];mids=sorted(pair_mids[key])
            for (kind,ch,dest,size),events in grouped.items():
                maximum=(pmax,smax)[ch];variants=list(dict.fromkeys((f,o) for _,f,o in events));timeline=[-1]*maximum
                for t,f,o in events:timeline[t]=variants.index((f,o))
                row={'counter':'secondary' if ch else 'primary','period':1,'phase':0,'frames':len(variants),'timeline':timeline,'sourceDestination':dest,'sourceSize':size,'sourceFrames':[{'paths':list(frames[f][1]),'offset':o} for f,o in variants]}
                folder=stage/'native'/key;folder.mkdir(exist_ok=True)
                n=len(banks)
                if kind=='P':
                    values=b''.join(__import__('struct').pack('<16H',*palette_parser(source/frames[f][1][0].replace('.gbapal','.pal'))) for f,_ in variants)
                    row.update(kind='palette',paletteSlot=dest,file=f'anim_{n}.pal');(folder/row['file']).write_bytes(values)
                else:
                    affected=[];all_layers=[[],[],[]]
                    # Recompute whole metatile layers with just this DMA range
                    # replaced, preserving palette indices and flip/occlusion.
                    for f,off in variants:
                        path=tuple(p.replace('.4bpp','.png') for p in frames[f][1])
                        if path not in source_pixels:
                            source_pixels[path]=[]
                            for p in path:
                                im=Image.open(source/p);assert im.mode=='P'
                                source_pixels[path]+=[list(im.crop((x,y,x+8,y+8)).tobytes()) for y in range(0,im.height,8) for x in range(0,im.width,8)]
                        tiles=source_pixels[path];offset=off//32;assert off%32==0
                        assert offset+size<=len(tiles),(key,path,offset,size,len(tiles))
                        old_pixel=[pair.primary.pixel,pair.secondary.pixel]
                        def pixel(which,tid,x,y):
                            absolute=tid+(pair.n_primary if which else 0)
                            if dest<=absolute<dest+size:return tiles[offset+absolute-dest][y*8+x]
                            return old_pixel[which](tid,x,y)
                        pair.primary.pixel=lambda tid,x,y:pixel(0,tid,x,y)
                        pair.secondary.pixel=lambda tid,x,y:pixel(1,tid,x,y)
                        try:
                            current=[]
                            for mid in mids:
                                entries,_,_=pair.definition(mid)
                                if any(dest<=e&1023<dest+size for e in entries):current.append(mid)
                            assert not affected or current==affected
                            affected=current
                            for mid in affected:
                                for i,layer in enumerate(pair.layers(mid)):all_layers[i].append(bytes(layer))
                        finally:pair.primary.pixel,pair.secondary.pixel=old_pixel
                    if not affected:continue
                    for i,(field,mfield) in enumerate([('file','mids'),('overFile','overMids'),('middleFile','middleMids')]):
                        filename=f'anim_{n}_{i}.idx';(folder/filename).write_bytes(b''.join(all_layers[i]));row[field]=filename;row[mfield]=affected
                    masks=[[],[],[]]
                    for mid in affected:
                        e,_,lt=pair.definition(mid)
                        bottom=[dest<=v&1023<dest+size for v in e[:4]];top=[dest<=v&1023<dest+size for v in e[4:]]
                        for i,bits in enumerate([([a or b for a,b in zip(bottom,top)] if lt==1 else bottom),([False]*4 if lt==1 else top),(bottom if lt==0 else top if lt==1 else [False]*4)]):masks[i].append(sum(1<<q for q,v in enumerate(bits) if v))
                    row['quads'],row['overQuads'],row['middleQuads']=masks
                    counts['animated_metatile_references']+=len(affected)
                banks.append(row)
            if banks:
                man={'family':'rse','counters':{'primary':{'max':pmax},'secondary':{'max':smax,'start':'primary' if sstart==pstart and sstart else 0}},'banks':banks,'sourceCallbacks':callbacks}
                (stage/'native'/key/'anim_manifest.lua').write_text('return '+lua_encode(man)+'\n')
                pair_defs[key]['animationFiles']=['anim_manifest.lua']+[v for row in banks for k,v in row.items() if k in ('file','overFile','middleFile')]
                counts['animated_pairs']+=1;counts['banks']+=len(banks)
    derivative(engine,stage)
    return dict(counts)


def derivative(engine,stage):
    src=(engine/'src/core/game3/tileset_anim.lua').read_text()
    helpers=src[src.index('local function rse_piece'):src.index('local function rse_counters')]
    helpers=helpers.replace('local keys = over and bank.overKeys or bank.underKeys','local keys = over=="middle" and bank.middleKeys or over==true and bank.overKeys or bank.underKeys').replace('if over then bank.overKeys = keys else bank.underKeys = keys end','if over=="middle" then bank.middleKeys=keys elseif over then bank.overKeys = keys else bank.underKeys = keys end').replace('(over and "o" or "u")','(over=="middle" and "m" or over and "o" or "u")')
    helpers=helpers.replace('  if rse_paste(entry, bank, bank.over,', '  if rse_paste(entry, bank, bank.middle, row.middleMids or EMPTY, row.middleQuads, frame, ts.midImageData, entry.lutOver, "middle") then dirty.middle=true end\n  if rse_paste(entry, bank, bank.over,')
    step=src[src.index('function TilesetAnim.stepRse()'):src.index('local function load_bank')]
    step=step.replace('dirty.under, dirty.over = nil, nil','dirty.under, dirty.over, dirty.middle = nil, nil, nil').replace('if dirty.under or dirty.over then','if dirty.under or dirty.over or dirty.middle then').replace('NativeTileset().flush(ts, dirty.under, dirty.over)','NativeTileset().flush(ts, dirty.under, dirty.over)\n        if dirty.middle and ts.midImage then ts.midImage:replacePixels(ts.midImageData) end')
    step=step.replace('function TilesetAnim.stepRse()','local function stepRse()')
    prefix='return function(TilesetAnim)\nlocal EMPTY={}\nlocal function NativeTileset()return require("src.core.game3.tileset_native")end\nlocal rseDirty={}\n'
    (stage/'hns_tile_animation.lua').write_text('-- Derived native metatile animation patch; see GEN1RECOMP_LICENSE.md.\n'+prefix+helpers+step+'\nreturn stepRse\nend\n')
