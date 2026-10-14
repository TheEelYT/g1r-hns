"""Extend the source's baked outlined, shaded title lettering as bitmap glyphs."""
from PIL import Image


def build(source,stage):
    original=Image.open(source/'graphics/title_screen/hns/press_start.png')
    # Preserve the actual glyphs and antialias colors, excluding the adjacent
    # separators: x=115 is the source period after 0, not part of that glyph.
    crops={'v':(91,8,5,7),'2':(96,8,9,7),'0':(106,8,9,7),'6':(116,8,9,7)}
    glyphs={c:original.crop((x,y,x+w,y+h))for c,(x,y,w,h)in crops.items()}
    patterns={
        '1':['..###..','...##..','...##..','...##..','.######'],
        '3':['#######','.....##','..#####','.....##','#######'],
        '4':['##...##','##...##','#######','.....##','.....##'],
        '5':['#######','##.....','#######','.....##','#######'],
        '7':['#######','.....##','....##.','...##..','..##...'],
        '8':['.#####.','##...##','.#####.','##...##','.#####.'],
        '9':['.######','##...##','.######','.....##','.#####.'],
        'M':['##...##','###.###','#######','##.#.##','##...##'],
        'o':['.#####.','##...##','##...##','##...##','.#####.'],
        'd':['######.','##...##','##...##','##...##','######.'],
        '.':['.','.','.','.','#'],
        '·':['.','.','#','.','.'],
    }
    for c,rows in patterns.items():
        im=Image.new('P',(len(rows[0])+2,7));points=[(x+1,y+1)for y,row in enumerate(rows)for x,v in enumerate(row)if v=='#']
        for x,y in points:
            for dx in (-1,0,1):
                for dy in (-1,0,1):im.putpixel((x+dx,y+dy),1)
        for x,y in points:im.putpixel((x,y),(5,5,4,3,3)[y-1])
        glyphs[c]=im
    glyphs[' ']=Image.new('P',(4,7))
    width=sum(im.width for im in glyphs.values());atlas=Image.new('P',(width,7));mapping={};x=0
    for c,im in glyphs.items():
        atlas.paste(im,(x,0));mapping[c]={'x':x,'w':im.width,'advance':im.width if c not in ('.','·')else 2};x+=im.width
    layers={}
    for n in range(1,6):
        file=f'boot/title_font_{n}.rgba';(stage/file).write_bytes(bytes(v for p in atlas.tobytes()for v in (255,255,255,255 if p==n else 0)))
        layers[str(n)]={'file':file,'width':width,'height':7}
    return {'layers':layers,'glyphs':mapping,'height':7,'sourceGlyphs':{c:list(r)for c,r in crops.items()},'style':'source title banner bitmap lettering'}
