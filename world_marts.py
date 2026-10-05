"""Import simple money marts with source stock and explicit item-name mapping.

The current opening has no badges or completed Mr. Pokemon quest. Shared
Cherrygrove clerks therefore use their source pre-quest stock; pokemart 0
uses HnS's ordinary zero-badge inventory. Exchanges and expanded-item shops
remain audited rather than receiving guessed replacement stock.
"""
import re
import opening

PREFIX="HNS_WORLD_MART_"
ITEM_ALIASES={"ITEM_X_SP_ATK":"ITEM_X_SPECIAL","ITEM_X_DEFENSE":"ITEM_X_DEFEND"}


def lines(label,labels):
    return [s for line in labels.get(label,[]) if (s:=line.split("@",1)[0].strip())]


def source_stock(pointer,source,labels):
    if pointer=="0":
        body=re.search(r"sShopInventory_ZeroBadges\[\]\s*=\s*\{(.*?)\};",(source/"src/shop.c").read_text(),re.S)
        if not body:raise ValueError("missing HnS zero-badge stock")
        entries=re.findall(r"\bITEM_\w+\b",body[1])
        if not entries or entries[-1]!="ITEM_NONE":raise ValueError("unterminated default mart stock")
        return entries[:-1]
    entries=[]
    for line in lines(pointer,labels):
        if line=="pokemartlistend":return entries
        match=re.fullmatch(r"\.2byte\s+(ITEM_\w+)",line)
        if not match:raise ValueError(f"unsupported mart stock directive: {pointer}/{line}")
        if match[1]=="ITEM_NONE":return entries
        entries.append(match[1])
    raise ValueError(f"unterminated mart stock: {pointer}")


def clerk_stock(label,source,labels):
    rows=lines(label,labels)
    # .align belongs to the following list, not the ended clerk program.
    while rows and rows[-1].startswith(".align "):rows.pop()
    before=["lock","faceplayer","message gText_HowMayIServeYou","waitmessage"]
    after=["msgbox gText_PleaseComeAgain, MSGBOX_DEFAULT","release","end"]
    if label=="Cherrygrove_Pokemart_EventScript_Clerk":
        expected=before+["goto_if_ge VAR_NEWBARK_TOWN_STATE, 5, Cherrygrove_Pokemart_EventScript_Clerk2",
                         "pokemart Cherrygrove_Pokemart_Pokemart"]+after
        if rows!=expected:return None
        pointer="Cherrygrove_Pokemart_Pokemart"
    else:
        if len(rows)!=8 or rows[:4]!=before or rows[5:]!=after:return None
        match=re.fullmatch(r"pokemart\s+(\w+)",rows[4])
        if not match:return None
        pointer=match[1]
    stock=source_stock(pointer,source,labels)
    return {"sourceScript":label,"sourceStock":pointer,"sourceItems":stock,"items":[ITEM_ALIASES.get(v,v) for v in stock]}


def build(source,engine,maps,source_maps,labels,text,scripts,sprites,movement_fields):
    engine_names=set(re.findall(r'"(ITEM_\w+)"',(engine/"src/core/game3/constants/emerald/items.lua").read_text()))
    mart_labels={};current=None
    for line in (source/"data/text/mart_clerk.inc").read_text().splitlines():
        match=re.match(r"^(\w+)::?\s*$",line)
        if match:current=match[1];mart_labels[current]=[]
        elif current:mart_labels[current].append(line.strip())
    def row(op,**kw):return {"op":op,**kw}
    def message(label):
        tid=PREFIX+label;text[tid]=opening.source_text(label,mart_labels)
        return [row("message",ptr=tid),row("waitmessage"),row("waitbuttonpress"),row("closemessage")]
    stocks={};clerks=[];omitted=[]
    for mid,dest in sorted(maps.items()):
        src=source_maps[dest["hnsSourceId"]];existing={o["localId"] for o in dest["objects"]}
        for i,o in enumerate(src.get("object_events",[])):
            if i+1 in existing or o["graphics_id"]!="OBJ_EVENT_GFX_MART_EMPLOYEE_HNS" or o.get("flag")!="0":continue
            try:stock=clerk_stock(o.get("script",""),source,labels)
            except ValueError as error:
                omitted.append({"map":mid,"sourceIndex":i,"reason":str(error)});continue
            if stock is None:continue
            missing=[v for v in stock["items"] if v not in engine_names]
            if missing:
                omitted.append({"map":mid,"sourceIndex":i,"reason":"expanded item mapping required","items":missing});continue
            if not stock["items"]:raise ValueError(f"empty mart stock: {mid}")
            if not(0<=o["x"]<dest["width"] and 0<=o["y"]<dest["height"]):raise ValueError(f"mart clerk outside layout: {mid}")
            key=PREFIX+mid+"_"+str(i);stocks[key]=stock
            scripts[key]=[row("lockall"),row("faceplayer")]+message("gText_HowMayIServeYou")+[
                row("pokemart",ptr=key)]+message("gText_PleaseComeAgain")+[row("releaseall"),row("end")]
            gid=sprites[o["graphics_id"]]["graphicsId"]
            obj={"localId":i+1,"x":o["x"],"y":o["y"],"elevation":o["elevation"],"graphicsId":gid,
                 "hnsGraphicsId":gid,"scriptKey":key,"flag":0,**movement_fields(o)}
            facing=o["movement_type"].removeprefix("MOVEMENT_TYPE_FACE_").lower()
            if facing in ("up","down","left","right"):obj["facing"]=facing
            dest["objects"].append(obj);clerks.append({"map":mid,"localId":i+1,"script":key})
    return {"stocks":stocks,"clerks":clerks,"omitted":omitted,"limits":"Source pre-quest/zero-badge stock; native Emerald prices, money and bag. Expanded items, badge-driven restocking and exchange services remain unported."}
