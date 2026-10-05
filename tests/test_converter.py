"""Small independent checks for the GBA binary conversion boundary."""
import importlib.util
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("build_port", Path(__file__).parents[1] / "build_port.py")
port = importlib.util.module_from_spec(spec)
spec.loader.exec_module(port)


class ConverterTests(unittest.TestCase):
    def test_wild_import_never_redistributes_unsupported_slots(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);source=root/"source";engine=root/"engine"
            (source/"src/data").mkdir(parents=True)
            constants=engine/"src/core/game3/constants/emerald"
            constants.mkdir(parents=True);(constants/"species.lua").write_text('return {"SPECIES_RATTATA","SPECIES_NONE"}')
            mon={"species":"SPECIES_RATTATA","min_level":2,"max_level":4}
            entry={"map":"MAP_TEST","base_label":"Test_Day","land_mons":{"encounter_rate":20,"mons":[dict(mon) for _ in range(12)]},"water_mons":{"encounter_rate":10,"mons":[dict(mon) for _ in range(5)]}}
            path=source/"src/data/wild_encounters.json"
            def build():
                path.write_text(json.dumps({"wild_encounter_groups":[{"for_maps":True,"encounters":[entry]}]}))
                return port.world_encounters.build(source,engine,{"EM_HNS_TEST":{"hnsSourceId":"MAP_TEST"}})
            self.assertEqual(len(build()["tables"]["EM_HNS_TEST"]["land"]["slots"]),12)
            for species in ("SPECIES_HAPPINY","SPECIES_NONE"):
                entry["land_mons"]["mons"][5]["species"]=species
                result=build()
                self.assertEqual(set(result["tables"]["EM_HNS_TEST"]),{"water"})
                self.assertEqual(len(result["omitted"]),1)
            entry["land_mons"]["mons"][5]=dict(mon)
            entry["land_mons"]["mons"].pop()
            self.assertNotIn("land",build()["tables"]["EM_HNS_TEST"])
            entry["water_mons"]["encounter_rate"]=0
            self.assertEqual(build()["tables"],{})

    def test_trainer_roster_rejects_expanded_mechanics(self):
        text="""=== TRAINER_TEST ===
Name: TEST
Class: Youngster Hns
Pic: Youngster
Gender: Male
Double Battle: No
AI: Basic Trainer

Rattata
Level: 4
IVs: 0 HP / 0 Atk / 0 Def / 0 SpA / 0 SpD / 0 Spe
- Tackle
"""
        trainer=port.world_trainers
        prepared={"rosters":trainer.parse_rosters(text),"classes":{"Youngster Hns":160},"pics":{"Youngster":128},"classRows":{"160":{"name":"YOUNGSTER","money":4}},"known":{"species":{"RATTATA"},"moves":{"TACKLE"},"items":set()}}
        self.assertEqual(trainer.roster("TRAINER_TEST",prepared)["party"],[{"species":"RATTATA","level":4,"iv":0,"moves":["TACKLE"]}])
        for key,value in (("Ability","Guts"),("Nature","Adamant"),("species","HAPPINY"),("IVs","1 HP / 0 Atk / 0 Def / 0 SpA / 0 SpD / 0 Spe"),("moves",["UNKNOWN"])):
            bad=copy.deepcopy(prepared);bad["rosters"]["TRAINER_TEST"]["party"][0][key]=value
            with self.assertRaises(ValueError):trainer.roster("TRAINER_TEST",bad)
        bad=copy.deepcopy(prepared);bad["rosters"]["TRAINER_TEST"]["header"]["Double Battle"]="Yes"
        with self.assertRaises(ValueError):trainer.roster("TRAINER_TEST",bad)

    def test_trainer_script_does_not_discard_story_branches(self):
        labels={"Trainer":["trainerbattle_single TRAINER_TEST, Intro, Defeat","msgbox After, MSGBOX_AUTOCLOSE","end"]}
        self.assertEqual(port.world_trainers.basic_script("Trainer",labels),("TRAINER_TEST","Intro","Defeat","After"))
        labels["Trainer"].insert(0,"goto_if_set FLAG_STORY, Other")
        self.assertIsNone(port.world_trainers.basic_script("Trainer",labels))

    def test_short_source_palette_zero_fills_native_slots(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/"short.pal"
            p.write_text("JASC-PAL\n0100\n2\n248 0 0\n0 248 0\n")
            self.assertEqual(port.parse_palette(p),[31,31<<5]+[0]*14)
            p.write_text("JASC-PAL\n0100\n2\n248 0 0\n")
            with self.assertRaises(ValueError):port.parse_palette(p)

    def test_layout_split_uses_source_default_and_reviewed_erratum(self):
        self.assertEqual(port.layout_profile({"id":"LAYOUT_BATTLE_PYRAMID_SQUARE01_HNS"}),(512,6))
        self.assertEqual(port.layout_profile({"id":"LAYOUT_UNION_ROOM_HNS","layout_version":"emerald"}),(640,7))
        self.assertEqual(port.layout_profile({"id":"LAYOUT_JOHTO","layout_version":"hns"}),(640,7))
        with self.assertRaises(ValueError):port.layout_profile({"id":"unknown","layout_version":"guessed"})

    def test_missing_lower_pixels_require_exact_opaque_foreground(self):
        class Source:
            count=1;blank_placeholders=set();spec={"dir":Path("lower")}
            def pixel(self,tid,x,y):
                if tid>=self.count:raise ValueError("missing visible source tile")
                return 1
        pair=object.__new__(port.Pair)
        pair.primary=pair.secondary=Source();pair.n_primary=640;pair.occluded_source_tiles=set()
        entries=[2]*8
        self.assertEqual(pair.half(entries,0,bytes([1]*256)),bytearray(256))
        covered=bytearray([1]*256);covered[17]=0
        with self.assertRaises(ValueError):pair.half(entries,0,covered)
        with self.assertRaises(ValueError):pair.half(entries,0)

    def test_world_dialogue_rejects_control_flow_and_prompts(self):
        labels={"NPC":["lock","faceplayer","msgbox Text, MSGBOX_NPC","release","end"],"Text":['.string "Hello!$"']}
        self.assertEqual(port.world_events.simple_dialogue("NPC",labels),"Hello!")
        for line in ("setflag FLAG_DONE","goto Other","special HealPlayerParty","end"):
            labels["NPC"].insert(0,line)
            self.assertIsNone(port.world_events.simple_dialogue("NPC",labels))
            labels["NPC"].pop(0)
        labels["NPC"][2]="msgbox Text, MSGBOX_YESNO"
        self.assertIsNone(port.world_events.simple_dialogue("NPC",labels))

    def test_movement_sheets_cover_walking_and_in_place_animation(self):
        for name in ("WANDER_AROUND","WALK_LEFT_RIGHT","JOG_IN_PLACE_DOWN","WALK_SEQUENCE_DOWN_RIGHT_UP_LEFT"):
            self.assertTrue(port.world_events.needs_walk_frames("MOVEMENT_TYPE_"+name))
        for name in ("NONE","FACE_LEFT","LOOK_AROUND","ROTATE_CLOCKWISE","FACE_DOWN_AND_RIGHT"):
            self.assertFalse(port.world_events.needs_walk_frames("MOVEMENT_TYPE_"+name))

    def test_mart_stock_rejects_unknown_directives_and_missing_terminator(self):
        marts=port.world_events.world_marts
        rows={"Stock":[".2byte ITEM_POTION",".2byte ITEM_NONE"]}
        self.assertEqual(marts.source_stock("Stock",None,rows),["ITEM_POTION"])
        for bad in ([".2byte ITEM_POTION"],[".byte 13",".2byte ITEM_NONE"]):
            with self.assertRaises(ValueError):marts.source_stock("Stock",None,{"Stock":bad})

    def test_mart_clerk_rejects_unsupported_story_branch(self):
        marts=port.world_events.world_marts
        rows={"Clerk":["lock","faceplayer","message gText_HowMayIServeYou","waitmessage","pokemart Stock",
                       "msgbox gText_PleaseComeAgain, MSGBOX_DEFAULT","release","end"],
              "Stock":[".2byte ITEM_X_DEFENSE",".2byte ITEM_X_SP_ATK",".2byte ITEM_NONE"]}
        self.assertEqual(marts.clerk_stock("Clerk",None,rows)["items"],["ITEM_X_DEFEND","ITEM_X_SPECIAL"])
        rows["Clerk"].insert(4,"goto_if_set FLAG_DONE, Other")
        self.assertIsNone(marts.clerk_stock("Clerk",None,rows))

    def test_native_backdrop_matches_hns_load_without_changing_other_colors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for folder in ("primary","secondary"): (root/folder/"palettes").mkdir(parents=True)
            colors=[(184,208,168)] + [(i*8,16,24) for i in range(1,16)]
            body="JASC-PAL\n0100\n16\n" + "".join(f"{r} {g} {b}\n" for r,g,b in colors)
            primary_path=root/"primary/palettes/00.pal"
            primary_path.write_text(body)
            (root/"secondary/palettes/07.pal").write_text(body)
            class Source:
                def __init__(self,folder): self.spec={"dir":root/folder}
            source_colors=port.parse_palette(primary_path)
            self.assertNotEqual(source_colors[0],0)
            pair=port.Pair(Source("primary"),Source("secondary"),640,7,{})
            self.assertEqual(pair.palettes[0],[0]+source_colors[1:])
            self.assertEqual(pair.palettes[7],source_colors)
            self.assertEqual(port.parse_palette(primary_path),source_colors)
            packed=struct.unpack("<256H",pair.palettes_blob()[8:])
            self.assertEqual(packed[0],0)
            self.assertEqual(packed[1:16],tuple(source_colors[1:]))

    def test_640_split_and_gba_flips(self):
        class Source:
            def __init__(self, value): self.value = value
            def pixel(self, tid, x, y): return (self.value + x + y) % 15 + 1
        pair = object.__new__(port.Pair)
        pair.primary, pair.secondary, pair.n_primary = Source(0), Source(7), 640
        # Tile 639 is still primary; 640 is secondary tile zero. Four entries
        # also exercise both GBA horizontal/vertical flip bits and palette 2.
        entries = [639 | 2 << 12, 640 | 2 << 12, 640 | 1024 | 2 << 12, 640 | 2048 | 2 << 12] * 2
        pixels = pair.half(entries, 0)
        self.assertEqual(pixels[0], 33)
        self.assertEqual(pixels[8], 40)
        self.assertEqual(pixels[8 * 16], 47)
        self.assertEqual(pixels[8 * 16 + 8], 47)

    def test_native_layout_retains_collision_and_elevation(self):
        word = 700 | 2 << 10 | 11 << 12
        blob = port.layout_blob(1,1,[word],[1,2,3,4])
        self.assertEqual(blob[:4],b"SVML")
        self.assertEqual(struct.unpack("<BBHHHHBB",blob[4:16]),(1,0,1,1,1,1,2,2))
        self.assertEqual(struct.unpack("<HBB",blob[24:]),(700,2,11))

    def test_truncated_and_wrong_sized_layouts_rejected(self):
        with self.assertRaises(ValueError): port.layout_blob(2,2,[1],[1,2,3,4])
        with self.assertRaises(ValueError): port.layout_blob(1,1,[1],[1])

    def test_codegen_text_quotes_and_control_tokens(self):
        self.assertEqual(port.lua('PROF.ELM\\p"Hi"'), '"PROF.ELM\\\\p\\\"Hi\\\""')

    def test_simple_sign_does_not_discard_game_logic(self):
        labels = {"Sign":["msgbox Text, MSGBOX_SIGN","end"],"Text":['.string "Town\\pDescription$"']}
        self.assertEqual(port.simple_sign("Sign",labels),"Town\\pDescription")
        labels["Sign"].insert(0,"special StartBattle")
        self.assertIsNone(port.simple_sign("Sign",labels))

    def test_source_path_cannot_escape_checkout(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError): port.safe_source(Path(tmp),"../not-source")

    def test_opening_text_preserves_controls_and_variables(self):
        labels={"Text":['.string "{PLAYER} received {STR_VAR_1}!\\p"', '.string "Good luck!$"']}
        self.assertEqual(port.opening.source_text("Text",labels),"{PLAYER} received {STR_VAR_1}!\\pGood luck!")

    def test_opening_text_rejects_unsupported_or_unterminated_data(self):
        for lines in ([ '.string "Hello$"', '.byte 0xff'], ['.string "Hello"'], []):
            with self.assertRaises(ValueError): port.opening.source_text("Text",{"Text":lines})


if __name__ == "__main__": unittest.main()
