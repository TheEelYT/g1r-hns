"""Persistent opening errand through Mr. Pokemon, Silver and Elm's delivery.

Source dialogue, object positions, teams and Silver movement are retained.
Automatic choreography supplements these retry/talk entry points in scenes.py. Stable
port flags, a native key item and inventory-success branches protect retries.
"""
import opening
import world_trainers
from world_marts import source_stock,lines

PREFIX="HNS_QUEST_"
EGG_RECEIVED=0x6004
EGG_DELIVERED=0x6005
RIVAL_DONE=0x6006
POTION_GIFT=0x6007
BALLS_GIFT=0x6008
MR_AFTER_HIDDEN=0x600B
SILVER_HIDDEN=0x600C
RIVAL_STAGE=0x7003
EGG_ITEM=900
DEX_NATIVE=0x484E5302
PARTY_NATIVE=0x484E5303


def build(source,stage,maps,source_maps,labels,text,scripts,opening_data,palette_parser,trainer_data,prepared,marts):
    def key(name):return PREFIX+name
    def r(op,**kw):return {"op":op,**kw}
    def script(name,rows):scripts[key(name)]=rows;return key(name)
    def message(label):
        tid=key(label);text[tid]=opening.source_text(label,labels)
        return [r("message",ptr=tid),r("waitmessage"),r("waitbuttonpress"),r("closemessage")]
    def own_message(name,value):
        tid=key(name+"_TEXT");text[tid]=value
        return [r("message",ptr=tid),r("waitmessage"),r("waitbuttonpress"),r("closemessage")]
    def flag_branch(flag,target,on=True):return [r("checkflag",flag=flag),r("goto_if",cond=1 if on else 0,target=key(target))]
    def success(target):return [r("compare_var_to_value",var=opening.RESULT,value=1),r("goto_if",cond=0,target=key(target))]
    lock=[r("lockall"),r("faceplayer")];finish=[r("releaseall"),r("end")]
    script("BAG_FULL",own_message("BAG_FULL","Your BAG cannot hold this gift. Make room, then speak to me again.")+finish)
    script("NEED_STARTER",own_message("NEED_STARTER","PROF.ELM is waiting in NEW BARK TOWN. Choose a POKéMON for his errand first.")+finish)
    script("MR",lock+flag_branch(EGG_RECEIVED,"MR_REPEAT")+flag_branch(opening.RECEIVED,"NEED_STARTER",False)
           +message("MrPokemonHouse_Text_Intro1")+message("MrPokemonHouse_Text_Intro2")
           +[r("additem",item=EGG_ITEM,quantity=1)]+success("BAG_FULL")
           +message("MrPokemonHouse_Text_GotEgg")+message("MrPokemonHouse_Text_Intro3")+message("MrPokemonHouse_Text_Intro4")+message("MrPokemonHouse_Text_Intro5")
           +message("MrPokemonHouse_Text_OakIntro")+message("MrPokemonHouse_Text_GetDex")
           +[r("setflag",engineFlagName="FLAG_SYS_POKEDEX_GET"),r("callnative",fn=DEX_NATIVE)]
           +message("MrPokemonHouse_Text_OakParting")+[r("setflag",flag=EGG_RECEIVED),r("setvar",var=RIVAL_STAGE,value=1),r("clearflag",flag=MR_AFTER_HIDDEN),
              r("removeobject",localId=2),r("removeobject",localId=3),r("addobject",localId=1)]
           +message("MrPokemonHouse_Text_Heal")+[r("callnative",fn=opening.HEAL_NATIVE),r("waitstate")]+message("MrPokemonHouse_Text_DependingOnYou")+finish)
    script("MR_REPEAT",flag_branch(EGG_DELIVERED,"MR_AFTER")+[r("checkitem",item=EGG_ITEM,quantity=1)]+success("MR_REPLACE")
           +message("MrPokemonHouse_Text_DependingOnYou")+finish)
    script("MR_REPLACE",[r("additem",item=EGG_ITEM,quantity=1)]+success("BAG_FULL")+message("MrPokemonHouse_Text_GotEgg")+finish)
    script("MR_AFTER",message("MrPokemonHouse_Text_AlwaysNewDiscoveries")+finish)
    script("MR_INIT",flag_branch(EGG_RECEIVED,"MR_INIT_AFTER")+[r("setflag",flag=MR_AFTER_HIDDEN),r("end")])
    script("MR_INIT_AFTER",[r("clearflag",flag=MR_AFTER_HIDDEN),r("end")])
    mrid="EM_HNS_ROUTE30_MR_POKEMONS_HOUSE_HNS"
    for index,hide in ((0,MR_AFTER_HIDDEN),(1,EGG_RECEIVED),(2,EGG_RECEIVED)):
        event=source_maps[maps[mrid]["hnsSourceId"]]["object_events"][index]
        world_trainers.add_object(source,stage,maps,mrid,event,index,key("MR"),opening_data,palette_parser,flag=hide)
    maps[mrid]["mapScripts"]["onTransition"]=key("MR_INIT")

    # Source-coordinate return triggers align the player and perform Silver's
    # eight-step approach, then native battle against the stronger starter.
    cherry="EM_HNS_CHERRYGROVE_CITY_HNS"
    silver=source_maps[maps[cherry]["hnsSourceId"]]["object_events"][13]
    world_trainers.add_object(source,stage,maps,cherry,silver,13,key("RIVAL"),opening_data,palette_parser,scripted_movement=True,flag=SILVER_HIDDEN)
    def movement(label,lid):
        rows=[v.strip() for v in labels[label] if v.strip() and not v.strip().startswith("@")]
        names=[]
        for name in rows:
            token=name.upper()
            if token.startswith("WALK_") and token.split("_",1)[1] in ("UP","DOWN","LEFT","RIGHT"):token=token.replace("WALK_","WALK_NORMAL_",1)
            names.append("MOVEMENT_ACTION_"+token)
        return [r("applymovement",localId=lid,movementNames=names),r("waitmovement",localId=lid)]
    script("RIVAL_INIT",flag_branch(RIVAL_DONE,"RIVAL_INIT_HIDE")+flag_branch(EGG_RECEIVED,"RIVAL_INIT_SHOW")
           +[r("setflag",flag=SILVER_HIDDEN),r("setvar",var=RIVAL_STAGE,value=0),r("end")])
    script("RIVAL_INIT_SHOW",[r("clearflag",flag=SILVER_HIDDEN),r("setvar",var=RIVAL_STAGE,value=1),r("setobjectxyperm",localId=14,x=silver["x"],y=silver["y"]),r("end")])
    script("RIVAL_INIT_HIDE",[r("setflag",flag=SILVER_HIDDEN),r("setvar",var=RIVAL_STAGE,value=2),r("end")])
    maps[cherry]["mapScripts"]["onTransition"]=key("RIVAL_INIT")
    for y,name in ((9,"RIVAL_TOP"),(10,"RIVAL_MID"),(11,"RIVAL_BOTTOM")):
        maps[cherry]["coordEvents"].append({"x":56,"y":y,"elevation":0,"var":RIVAL_STAGE,"value":1,"scriptKey":key(name)})
    party_check=[r("callnative",fn=PARTY_NATIVE)]+success("RIVAL_NO_PARTY")
    script("RIVAL_TOP",[r("lockall")]+party_check+movement("CherryGroveCity_Movement_Trigger_Silver_Top",255)+[r("goto",target=key("RIVAL_APPROACH"))])
    script("RIVAL_BOTTOM",[r("lockall")]+party_check+movement("CherryGroveCity_Movement_Trigger_Silver_Bottom",255)+[r("goto",target=key("RIVAL_APPROACH"))])
    script("RIVAL_MID",[r("lockall")]+party_check+[r("goto",target=key("RIVAL_APPROACH"))])
    script("RIVAL_APPROACH",movement("CherryGroveCity_Movement_Silver_Enter",14)+[r("goto",target=key("RIVAL_CORE"))])
    rival_rows=flag_branch(EGG_RECEIVED,"RIVAL_NOT_READY",False)+flag_branch(RIVAL_DONE,"RIVAL_FINISH")+message("CherrygroveCity_Text_RivalSeen")
    for choice,name in enumerate(("CYNDAQUIL","TOTODILE","CHIKORITA")):
        rival_rows += [r("compare_var_to_value",var=opening.STARTER_VAR,value=choice),r("goto_if",cond=1,target=key("RIVAL_"+name))]
        label="TRAINER_RIVAL_"+name+"_1_HNS";tid=prepared["ids"][label];record=world_trainers.roster(label,prepared)
        record["dialogs"]={"defeat":opening.source_text("CherrygroveCity_Text_SilverWin",labels)}
        trainer_data["records"][str(tid)]=record
        pid=record["pic"]
        if str(pid) not in trainer_data["portraits"]:trainer_data["portraits"][str(pid)]=world_trainers.portrait(source,prepared["rosters"][label]["header"]["Pic"],pid,stage,palette_parser)
        defeat=key("RIVAL_DEFEAT");text[defeat]=record["dialogs"]["defeat"]
        script("RIVAL_"+name,[r("trainerbattle",type=3,trainer=tid,defeatText=defeat)]+flag_branch(0x500+tid,"RIVAL_FINISH",False)+[r("goto",target=key("RIVAL_WON"))])
    script("RIVAL",lock+party_check+[r("goto",target=key("RIVAL_CORE"))])
    script("RIVAL_NO_PARTY",own_message("RIVAL_NO_PARTY","You need a healthy POKéMON to battle. Visit ELM or a POKéMON CENTER.")+finish)
    script("RIVAL_CORE",rival_rows+finish)
    script("RIVAL_NOT_READY",own_message("RIVAL_NOT_READY","Finish PROF.ELM's errand at MR. POKéMON's house first.")+finish)
    script("RIVAL_WON",message("CherrygroveCity_Text_RivalAfter")
           +[r("applymovement",localId=255,movementNames=["MOVEMENT_ACTION_LOCK_FACING_DIRECTION","MOVEMENT_ACTION_WALK_FAST_DOWN","MOVEMENT_ACTION_UNLOCK_FACING_DIRECTION","MOVEMENT_ACTION_FACE_UP"])]
           +movement("CherryGroveCity_Movement_Silver_Leave1",14)+[r("waitmovement",localId=255)]
           +movement("CherryGroveCity_Movement_Silver_Return",14)+message("CherrygroveCity_Text_RivalID")
           +movement("CherryGroveCity_Movement_Silver_Leave2",14)
           +[r("setflag",flag=RIVAL_DONE),r("setflag",flag=SILVER_HIDDEN),r("setvar",var=RIVAL_STAGE,value=2),r("removeobject",localId=14)]+finish)
    script("RIVAL_FINISH",finish)

    # Keep the proven starter flow and IDs; only prefix Elm/aide talk entry
    # points with the new state branches. Failed inventory actions set no gift
    # or delivery flags, allowing a safe retry after making room in the bag.
    scripts[opening.PREFIX+"ELM"] = flag_branch(EGG_DELIVERED,"ELM_AFTER")+flag_branch(EGG_RECEIVED,"ELM_RETURN")+scripts[opening.PREFIX+"ELM"]
    script("ELM_RETURN",lock+flag_branch(RIVAL_DONE,"ELM_WAIT_RIVAL",False)+[r("checkitem",item=EGG_ITEM,quantity=1)]+success("ELM_MISSING_EGG")
           +message("NewBarkTown_Lab_Text_ElmAfterTheft1")+[r("removeitem",item=EGG_ITEM,quantity=1)]+success("ELM_MISSING_EGG")
           +message("NewBarkTown_Lab_Text_ElmAfterTheft2")+message("NewBarkTown_Lab_Text_ElmAfterTheft3")+message("NewBarkTown_Lab_Text_ElmAfterTheft4")
           +[r("setflag",flag=EGG_DELIVERED)]+finish)
    script("ELM_AFTER",lock+message("NewBarkTown_Lab_Text_ElmStudyingEgg")+finish)
    script("ELM_WAIT_RIVAL",own_message("ELM_WAIT_RIVAL","A trainer near CHERRYGROVE's east exit is looking for you. Meet him before returning the EGG.")+finish)
    script("ELM_MISSING_EGG",own_message("ELM_MISSING_EGG","Please bring the MYSTERY EGG from MR. POKéMON's house.")+finish)
    scripts[opening.PREFIX+"AIDE1"]=flag_branch(EGG_DELIVERED,"AIDE_BALLS")+flag_branch(opening.RECEIVED,"AIDE_POTION")+scripts[opening.PREFIX+"AIDE1"]
    script("AIDE_POTION",lock+flag_branch(POTION_GIFT,"AIDE_AFTER")+message("NewBarkTown_Lab_Text_AideGivePotion")
           +[r("additem",itemName="ITEM_POTION",quantity=1)]+success("BAG_FULL")+[r("setflag",flag=POTION_GIFT)]
           +own_message("POTION_RECEIVED","{PLAYER} received a POTION!")+finish)
    script("AIDE_BALLS",lock+flag_branch(BALLS_GIFT,"AIDE_AFTER")+message("NewBarkTown_Lab_Text_AideGiveBalls")
           +[r("additem",itemName="ITEM_POKE_BALL",quantity=5)]+success("BAG_FULL")+[r("setflag",flag=BALLS_GIFT)]
           +own_message("BALLS_RECEIVED","{PLAYER} received five POKé BALLS!")+message("NewBarkTown_Lab_Text_AideExplainBalls")+finish)
    script("AIDE_AFTER",message("NewBarkTown_Lab_Text_AideAlwaysBusy")+finish)
    for stock in marts["stocks"].values():
        if stock["sourceScript"]=="Cherrygrove_Pokemart_EventScript_Clerk":
            upgrade=lines("Cherrygrove_Pokemart_EventScript_Clerk2",labels)
            while upgrade and upgrade[-1].startswith(".align "):upgrade.pop()
            if upgrade!=["pokemart 0","msgbox gText_PleaseComeAgain, MSGBOX_DEFAULT","release","end"]:raise ValueError("missing reviewed post-quest mart stock")
            stock["postQuestItems"]=source_stock("0",source,labels)
    return {"flags":{"eggReceived":EGG_RECEIVED,"eggDelivered":EGG_DELIVERED,"rivalDone":RIVAL_DONE,"potionGift":POTION_GIFT,"ballsGift":BALLS_GIFT},
            "vars":{"rivalStage":RIVAL_STAGE},"eggItem":EGG_ITEM,"dexNative":DEX_NATIVE,"partyNative":PARTY_NATIVE,"objects":[{"map":mrid,"localId":i} for i in (1,2,3)]+[{"map":cherry,"localId":14}],
            "items":{"HNS_MYSTERY_EGG":{"id":"HNS_MYSTERY_EGG","index":EGG_ITEM,"name":"MYSTERY EGG","price":0,"pocket":"KEY_ITEMS","fieldUse":"none","importance":1,"registrability":0,"battleUsage":0,"description":"A mysterious EGG for PROF.ELM to examine."}},
            "changedPriorScripts":[opening.PREFIX+"ELM",opening.PREFIX+"AIDE1"],
            "limits":"Talk to Mr. Pokemon to receive egg/dex/healing; source Silver approach and battle on return; deliver egg to Elm and collect aide gifts. National dex bridges Emerald's regional list. Automatic Mr. Pokemon/police choreography, rival naming and phone calls remain unported."}
