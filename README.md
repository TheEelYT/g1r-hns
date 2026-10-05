# Pokémon Heart & Soul → Gen1Recomp, version 0.7.2

Version 0.7.2 completes source Dex egg/level-up/TM/HM/tutor browsing, including Totodile's 87 modern moves; restores animated stats icons, unseen portraits and scroll arrows; and fixes Pokégear footers, centered help, button glow and early Condition access. PC Game Modes uses its own source save/cancel header. Expanded battle effects, remaining rules and the later campaign are still in progress.

**Download the `.g1rcart` from [Releases](https://github.com/TheEelYT/g1r-hns/releases/latest), then import it as a custom cart.** The cart installs the pinned mod, keeps saves isolated to Pokémon Heart & Soul, and ships sealed with mod edits disabled. The mod ZIP is the alternative manual download. A ZIP alone does not create the custom cart.

## Install and test on Windows

1. Use Gen1Recomp **v0.3.44**, with vanilla US Emerald already imported normally.
2. Download `pokemon_heart_soul-1.0.1.g1rcart`, import it through Gen1Recomp's cart importer, accept installation of its pinned mod, and select Pokémon Heart & Soul in Emerald's cart list. The mod is **0.7.2**; the cart wrapper is **1.0.1**, which upgrades the supplied 1.0.0 local cart. The original cart ID, label and seal are retained.
3. Continue an existing HnS save under the same cart. Party, inventory, map IDs and story flags are retained. Restart after updating. To use the manual alternative, uninstall the prior same-ID mod, import `hns_exploration-0.7.2.zip`, confirm 0.7.2 and enable it for Emerald. Manual mod installation does not create or select the cart or move vanilla saves into it.
4. For the full opening, create a New Game: select gender and name, then browse the six challenge pages with L/R and confirm with Start or the SAVE row. Check GB SOUNDS and key-item EXP. SHARE. Start in the bed, walk toward the clock, set it and read the information window; Mom then gives Pokégear and running shoes. The town Lass blocks early departure and Silver stands by the lab. After choosing a starter, Elm stops you at the exit and steps you back. Walk up and talk to him for Mr. Pokémon directions and number registration; the aide gives the Potion. Try Silver at the lab window and accept the Cherrygrove guide’s tour. Returning from Mr. Pokémon triggers Elm’s incoming disaster call. Check the officer’s custom rival name, Egg handoff jingle and one-time aide Poké Balls. The Lass then blocks all three town exits until you speak to Mom. Try EXIT followed by New Game and confirm Oak returns.
5. Open Pokégear from the pause menu: source home buttons for map (Select switches Johto/Kanto), phone (Mom/Elm), condition, radio and ribbons as they unlock. The radio card is obtained through the Goldenrod Radio Tower quiz; later radio rewards/effects and phone contacts are still pending. OPTIONS contains all three source option pages, also using L/R; B or Start saves options. PC GAME MODES reopens the challenge pages; only the source-permitted easier changes are allowed after startup. USE the key-item EXP. SHARE to toggle party experience. Interact with a Center wall clock and press R to reset the saved time without penalty. Check source border banners and both players’ battle back sprites. Condition is hidden before its source unlock. Map/Call pages use source headings, help icons and list positioning; page changes fade and headers/buttons slide.
6. In Sprout Tower, walk into either source trigger lane near Silver and the Elder on 3F. Silver moves, speaks and uses an Escape Rope. Defeat Li and receive HM05 Flash. Four source item balls across the tower floors are collectible once.
7. Challenge Falkner in Violet Gym. His source team is Pidgey level 8 and Noctowl level 11, with source moves and held berry. Winning gives the Zephyr Badge and TM51 Roost, updates the guide/statues and enables Flash outside battle. Cut still requires the second badge. A battle loss awards no progress; a full bag leaves the reward retryable without refighting.
8. Teach Roost through the native TM bag flow to an eligible Pokémon. It restores half the maximum HP, has the pinned source’s 5 PP and temporarily removes Flying typing until the turn ends. This is an explicit move bridge alongside the first HnS mechanics batch described below.

Arrow keys/WASD move; Z/Enter is A. Disable the mod, select an Emerald slot and restart to play ordinary Emerald. Restart after updating; hot reload is untested.

## Imported and working

- All **564 maps/interiors**: 560 HnS definitions and four shared rooms, **146 native tileset pairs**, **550,536 layout cells**, **219 connections**, **1,419 static warps**, and 11 dynamic-return headers (eight active, three dormant).
- **2,204 objects**, **402 native overworld sheets**, including source avatar states, **37 trainer portraits**. These include 495 dialogue NPCs, 28 nurses, 22 mart clerks, 227 ordinary trainers, the opening cast, 23 additional reviewed residents and the new tower/gym actors and pickups, plus 1,368 restored field Pokémon and 104 additional cry/dialogue interactions. Source movement/ranges, walking frames and counter interactions are retained.
- Source Elm entrance/email, automatic Mr. Pokémon/Oak meeting, visible Silver battle and officer/rival-name/Elm investigation. One Johto starter with a source picture/cry and optional saved nickname, lab healing, Mystery Egg, Pokédex unlock and one-time Potion, five Poké Ball and CHERI BERRY gifts. Stolen starter ball, broken window and returning residents use persistent state.
- HnS Johto Pokédex with **282 source regional numbers**, seen/caught filtering, HGSS Plus layouts/fonts, source entries/measurements, source statistics, EV/hidden-ability toggling and level-up move information; caught registration uses the source layout, entry text, type icons, footprints, front pictures, cry and fade/slide transition. Expanded species retain reserved regional slots. Evolution/forms, size comparison and cry visualization remain unfinished. National mode follows the source 482-entry obtainable order, with reserved unsupported entries.
- **232 source trainer rosters**, **502 team members**, source portraits/classes/money and supported moves/items/basic AI. Native sight, approach and persistent defeat state; empty/fainted parties cannot launch imported fights.
- **316 wild pools** across **150 maps**, **2,795 slots**: 110 land, 55 water, 62 rock-smash and 89 fishing. Daytime/default source rates, levels and complete slot arrays are preserved. Rods and later HM access still need their campaign bridges.
- Source water/flowers and other tile callbacks: 69 animated pairs, 124 banks and 1,807 metatile references, including foreground/middle layers and palette cycles.
- Source bag backgrounds, Gold/Kris bag sprites, icons/names/descriptions and six displayed pockets: Items, Medicine, Poké Balls, TMs & HMs, Berries and Key Items. Medicine retains native saved Items storage and native item actions.
- **35 source berry objects / 33 saved tree IDs**, with 16 berry varieties, source yields/art, ripe initial state, harvest jingle and automatic replanting/regrowth. Full-bag rejection retains ripe berries. Native saved tree state survives Continue.
- Source door sheets/palettes and four-beat opening/closing waits, including scripted delayed closes; source Gold/Kris exit-arrow frames use the correct palette.
- HnS trainer card palettes, Gold/Kris portraits, Johto badges and saved-party icons, retaining native statistics and flip/close flow.
- Native Center ball/monitor healing animation, black-fade healing outside Centers, counters, 19 source blackout checkpoints and native money/bag Buy/Sell/Quit marts. Expanded vendors, trades and later restocking remain unfinished.
- **148 source M4A songs and jingles** with original sequences/instruments: map themes, trainer encounters, battle/victory music, Oak, healing, level-up and item/egg/berry/TM/badge rewards. Source loop/tuning data and intentional voice-bank continuation are preserved. Native Emerald sound effects and cries remain available.
- Sprout Tower Silver/Elder/Li scene, guarded Flash gift and four source pickups. Falkner’s first source team, Zephyr Badge, guide/statues and usable TM51 Roost. Native badge services match Johto’s first-badge Flash requirement.

## Battle rules in this build

| Rule | Behavior | Selection |
| --- | --- | --- |
| Existing move parameters | Source power, accuracy, PP, priority and supported types for 354 moves | Always applies |
| Type matchups | Source modern chart, including Ghost/Dark versus Steel | Always applies |
| Critical hits | Odds 1/24, 1/8, 1/2, guaranteed; damage remains 2× | Always applies |
| Hidden Power / Explosion / Facade | 60 power / full Defense / no burn penalty | Always applies |
| Paralysis / confusion / burn / sleep | Source-configured Gen 3 behavior retained | Always applies |
| Move categories | Per-move physical/special categories or old type split | PHYS/SPEC SPLIT |
| Fairy | Retype 18 supported species and Charm/Sweet Kiss/Moonlight | FAIRY TYPES |
| Sturdy / Sitrus / field poison | Full-HP survival / quarter-HP berry / cure at 1 HP | Respective mode settings |
| EXP / EVs | 1×, 1.5×, 2×, 0× / allow or block player awards | Difficulty settings |
| Battle items | Player medicine and trainer AI use; balls remain allowed | PLAYER ITEMS / TRAINER ITEMS |
| Expanded learnsets | Saved selection; effect still pending | MODERN MOVES |

These are the first supported mechanics, not a complete expansion import.

## Limits and source repairs

The full campaign remains in progress. Player followers, Nuzlocke and other expanded challenge rules, later phone contacts/rematches, later Gyms/story, doubles, trades, advanced services, hidden items, puzzles and scripted travel remain unported. All source settings pages retain selections; native options, party EXP. SHARE and the nine rules above are active. Other effects remain pending and are listed in the scope documentation. Radio tuning/music and its quiz unlock work; dynamic program content, rewards and encounter effects remain in progress. Conditional residents not yet reviewed can still be missing; exact source omissions are recorded in `world.lua` and `build_report.json`. Dialogue can mention unfinished features. Of the remaining Pokémon omissions, 154 need source story/visibility scripts and 54 have out-of-bounds source coordinates. Another 47 restored Pokémon have advanced/expanded interactions that remain unported; their source sprites are present.

Battles use Emerald species/base stats and supported effects/items, plus the HnS fixed-rule and settings bridges and Roost. The 354 existing moves use source power/accuracy/PP/priority/types, and the fixed source type chart, critical odds, Hidden Power, Explosion and Facade rules are active. HnS deliberately retains Gen 3 critical damage (2×), paralysis speed (¼), confusion chance (½), burn damage (⅛) and sleep rules. MODERN MOVES controls expanded learnsets in the source and remains PENDING; it does not disable fixed move parameters. Expanded species, moves, abilities, items and the other fixed expansion behaviors still need bridges. Existing saved max-PP values are retained; fresh moves use source PP. Unsupported trainer teams and wild pools are omitted intact. Wild encounter time-of-day switching, swarms and later radio effects remain queued. Decorative day/night Pokémon swap on map entry using the native saved RTC and source 19:00–06:00 night boundary. The player uses source Gold/Kris field and battle sprites and the standard RSE naming keyboard.

Music uses the engine’s synchronous buffered mixer because the native filesystem-only worker cannot read mod-owned overlays. Owned song slots use HnS’s fifteen sampled voices and its 304-samples-per-VBlank fixed-rate clock. Vanilla slots retain their original allocator and clock. The user confirmed the music mix. The user confirmed field/healing visuals; the new startup and banners still need a Windows live check. The mod declares `engine_internals` for owned asset overlays and native bridges.

Previous map repairs are retained: black source palette backdrop, corrected UnionRoom atlas split, Route 38 transparent placeholder and lower padding omitted only when opaque foreground fully covers it. Twelve unusable source warp rows/arrivals remain audited omissions; all their maps remain imported. Both shared Artisan Cave exits retain reciprocal HnS Frontier destinations. Elm’s atlas retains the source broken-window metatile. Prior tile pixels, palettes, layouts and stable namespaces are preserved; five Mom/gate script replacements are reconstructed and audited against 0.6.5.

## Validation

Version 0.7.2 passes **79,901 native checks under each cache root**, 19 converter tests and strict Modkit validation. Six independent source audits compare all prior world/presentation/gameplay data, 934 move parameter/description records, 1,487 C-evaluated learnset arrays (33,629 rows), all 386 two-frame stats icons, move item/question pixels and all 48 five-bit button-glow variants. Totodile's modern list is exactly 14 egg + 17 level-up + 56 teachable = 87 entries. Sixty-four CPU previews rasterize actual Lua draw calls with scissor clipping and source-sheet bounds; captured icon/glow phases contain different pixels. All 4,279 prior non-code assets, 564 maps, 1,752 scripts and 2,000 texts remain unchanged. The native cart tests check import/roundtrip, upgrade from the reference 1.0.0 cart, exact GitHub pin, retained label, isolated saves and sealed mod edits. Cart parser/store and ZIP resolution interfaces are byte-identical to Windows v0.3.44. No graphical LÖVE runtime or imported Emerald ROM is available here, so these previews are not screenshots from a running game.

The user confirmed the previous maps/NPCs, opening choreography, corrected music and 0.6.2 field fixes. Version 0.6.7 checked actual FIGHT → START move details, input-free native throw continuation, source gear unlocks, unequal-level EXP awards, and 354 C-compiled move descriptions. Retained checks include native move-category damage, Counter history, Hustle accuracy, critical odds, Hidden Power/Explosion/Facade, multi-hit/confusion Sturdy, actual Sitrus consumption, EXP/EV/item settings and native poison queue checks. It checks the recreated boot menu, Egg removal/jingle and all three Mom-gate lanes. An independent C expression oracle verifies all 354 move rows and 361 type matchups. Earlier checks include menu dependencies/confirmation, actual source-font UI draw captures, three tour lanes, starter/nickname acceptance/decline/save/PC guards, native PC result compatibility, Wooper release and field help/call overlays to settings persistence, Pokégear call waits, map regions, Center clock confirmation/RTC, XP eligibility/toggle, old-save migration and source UI asset checks to native terrain/sprite drawing, stair interpolation/collision, Pokémon spawning/visibility/cries, the VM and healing effect, screen fades and actual party restoration. Tests use default and changed cache roots. Additional source audits compare Pokémon and healing pixels directly with source PNGs/palettes and preserve all prior layouts, atlas pixels, script bytes and save namespaces.

New regressions cover both tower scene lanes, Li/Falkner loss and win branches, bag rejection/retry, persistent rewards, native save flags, pickups, Flash/Cut requirements, TM teaching and Roost healing/type restoration. All 148 songs are sequenced and mixed to finite, nonzero PCM; tests check map music, healing-jingle timing/pause/restoration, battle/victory selection and vanilla isolation. Independent source audits check all map/encounter music, source fanfare durations, instrument/sample boundaries, National Park’s continued piano bank, and all 9,216 pixels in Wooper’s reordered walking sheet.

Music regressions reproduce 12 early looped-note cutoffs in New Bark, nine on Route 29, twelve in Violet and 34 in trainer battle music during the first six seconds with the old allocator. The corrected passages show none; all 774 note start times, pitches, instrument programs and velocities remain identical. Known-envelope tests exercise N24 gates, gate extensions, tie/end-tie, sustain and exact release steps through the native sample resolver/mixer. Seven-note chords retain every source voice while vanilla slots keep five. Fixed-rate source instruments use the source clock; vanilla fixed-rate samples remain unchanged.

Existing scene checks retain all three Elm entrance lanes, Mr/Oak approach/departure, officer/naming and Egg delivery, bag retry and connected-map Silver visibility. Native save schema retains rival name. Pokédex checks exercise real menu routing and modal input. Graphics uploads and text/name/battle completion are controlled boundaries. Generic species/move/item fixtures do not validate full ROM balance.

**No graphical LÖVE runtime or imported Emerald ROM/cache is available here.** Windows playback, the complete intro and battle visuals remain unverified locally. Source-font menu/help/call/collection rendering is checked through sixty-four captures of the actual Lua draw calls, rasterized without a ROM; these are UI previews, not screenshots from a running game. Reports distinguish native PCM testing from listening in the Windows game. Source previews are not screenshots. All 103 audited native interfaces are byte-identical to Gen1Recomp v0.3.44. The owned sequencer differs only in its configurable voice-cap condition. Results are recorded in `reports/validation.json` and its logs.

## Rebuild

Use Linux or WSL with Python 3.10+, Pillow, LuaJIT, **gcc/g++ and GNU binutils** (`as`, `ld`, `objcopy`, `nm`). The converter compiles pinned mid2agb/wav2agb tools automatically. No GBA compiler or game ROM is needed. Keep upstream checkouts separate.

```bash
git clone https://github.com/PokemonHnS-Development/pokehns-expansion.git hns-source
git -C hns-source checkout 167aa6d537b109bb229c231ddce4616974c4da71
git clone https://github.com/bryanthaboi/gen1recomp.git hns-gen1recomp
git -C hns-gen1recomp checkout 20ab97abf8092c37344d108f2136ec4e5d131500
python3 -m pip install Pillow
python3 /path/to/checkpoint/build_port.py --source hns-source --engine hns-gen1recomp --out hns-build/hns_exploration
```

Set `HNS_LUAJIT` to an absolute LuaJIT executable if it is not on PATH. The default scope is `all`; output must be fresh. `--ups PATH` records patch identity only and never applies it. `--previews PATH` renders diagnostic maps. Audio tool/cache directories are placed beside the checkpoint in `.tools/hns-audio`.

From the engine checkout:

```bash
luajit /path/to/checkpoint/tests/test_native.lua /absolute/hns-build/hns_exploration
luajit /path/to/checkpoint/tests/test_native.lua /absolute/hns-build/hns_exploration default
python3 tools/modkit.py validate /absolute/hns-build/hns_exploration
python3 /path/to/checkpoint/tests/test_converter.py
python3 /path/to/checkpoint/tests/check_world.py --source /absolute/hns-source --engine /absolute/hns-gen1recomp --mod /absolute/hns-build/hns_exploration --luajit /absolute/path/to/luajit
python3 /path/to/checkpoint/tests/check_fidelity.py --source /absolute/hns-source --engine /absolute/hns-gen1recomp --mod /absolute/hns-build/hns_exploration --luajit /absolute/path/to/luajit
python3 /path/to/checkpoint/tests/check_gameplay.py --source /absolute/hns-source --engine /absolute/hns-gen1recomp --mod /absolute/hns-build/hns_exploration --luajit /absolute/path/to/luajit
python3 /path/to/checkpoint/tests/check_services.py --source /absolute/hns-source --engine /absolute/hns-gen1recomp --mod /absolute/hns-build/hns_exploration --luajit /absolute/path/to/luajit
```

Set `MODKIT_LUAJIT` if needed. Upstream `gen3check` targets FireRed and reports MK400 for an Emerald-only manifest; integration tests use the actual Emerald loader.

## Next work and provenance

Continue importing the fixed HnS battle system and remaining settings, expanded move/item/ability compatibility, then the road to Azalea, source story gates/conditional residents and item gifts. Later badges, phone/rematches, scripted travel and puzzles follow their dependencies. Progression blockers are reserved for the final stage: missing trainers, Cut trees and other obstacles must eventually enforce the source route order and prevent sequence breaks. Keep test travel open until the remaining campaign is complete.

- HnS `Release-v2.0.6`: `167aa6d537b109bb229c231ddce4616974c4da71`.
- Gen1Recomp source: `20ab97abf8092c37344d108f2136ec4e5d131500`; compared v0.3.44: `bd64bec97575b3a155b64791f1b058107ef31a0d`.
- User UPS: `pokemonHnS_v2.0.6.ups`, valid checksum, 16 MiB input/32 MiB output; input CRC32 `1f1c08fb`, output CRC32 `01713508`.

Maps, pixels, dialogue and audio come from matching public HnS source. No ROM image is included. Credit PokemonHnS-Development, RHH’s pokeemerald-expansion, resetes12’s Modern Emerald, pret, the original developers and Gen1Recomp contributors. Full upstream credits are retained. Converter, runtime glue and tests were authored for TheEelYT with Codex.

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC (https://github.com/bryanthaboi/gen1recomp). The derived sequencer retains the upstream GPLv3 license and additional terms in `GEN1RECOMP_LICENSE.md`.

## Startup and Pokégear scope

All nine source menus (88 rows) are present: MODE, FEATURES, RANDOMIZER, NUZLOCKE, DIFFICULTY, CHALLENGES during Oak’s introduction after naming; OPTIONS, BATTLE OPTIONS and SOUND from the pause menu. Left/Right selects an active value and L/R changes pages. R does nothing on the final loaded pause-options page. On PC Game Modes, the final R opens Save confirmation. A final GEN1RECOMP tab restores every platform-appropriate native engine option, using the existing native row actions and options persistence: speed, video, graphics, audio, performance, extras, controls and mods. The six cartridge options remain on their HnS pages. Challenge SAVE/Start requires YES/NO confirmation; mid-run B cancels challenge edits. Options B/Start saves. PC GAME MODES exposes the source lock policies: one-way settings can only decrease; fully locked choices cannot change. Recommended/custom, randomizer, Nuzlocke, mirror and quick-run dependencies follow the pinned source. Unfinished rule effects are documented as pending; in-game options use only the source L/R icons, with no extra Save/header labels. Source descriptions and defaults are imported. Text speed through FAST, battle scene/style, button mode, frame and sound use native options. FASTER text currently falls back to FAST and is marked pending. Other expanded effects are saved and marked pending.

Oak uses the source brown-coat portrait, purple/gray backdrop, Wooper and Gold/Kris pictures, default names and MUS_HG_NEW_GAME. Mom gives Pokégear, then running shoes. The clock tooltip and pause time display are present; Center wall clocks use the native RTC offset and allow R to enter setting mode. GB SOUNDS is present, but alternate GB playback is not yet implemented.

EXP. SHARE is key item 903 with a USE toggle. Its enabled award path uses the pinned source ratios: active participants split 2/3 of the base award, each eligible reserve receives 7/25, and a single eligible party Pokémon receives the full amount. Eggs/fainted Pokémon are excluded; native boosts, level-ups and battle stat refresh remain intact. Disabled mode delegates to native participant/held-item experience. The pinned B_SCALED_EXP = GEN_3 and EXP_CAP_NONE configuration does not weight EXP by recipient level; an unequal-level regression verifies those exact awards. Expanded species yield/balance remains pending. Older bag-held EXP.SHARE migrates to the key item on map entry.

Pokégear uses the native modal/save services with source Johto/Kanto map pixels, source section coordinates and Mom/Elm dialogue. Elm’s initial registration and incoming theft call run through the field VM. Elm’s source count/rating calls are implemented; later contacts and rematches remain in progress. The radio has the source Goldenrod quiz gate and Johto tuning/music; later Kanto card services, dynamic programs, rewards and encounter effects are unfinished. Source map/call layouts and bitmap fonts are refined in this build. Condition/ribbons use source art and saved data; remaining subpage transitions, later call contacts and full radio gameplay remain future work.

Source popup index artwork/palettes feed the native banner renderer. Gold/Kris four-frame back strips feed native battle presentation. Existing maps, standing/walking pixels, stable IDs and save namespaces are preserved. Stable settings vars remain 0x7009–0x700A and 0x7100–0x7157. This build adds flags 0x602F (Condition) and 0x6030 (berry initialization), plus native handler 0x484E530C. The save export stores the real Dex state in modData.hnsDexState and a launcher-compatible summary view; native loading restores the real state before gameplay.

## 0.7.1 presentation repairs

The source exit-arrow PNG stores eight frames horizontally. The renderer now selects valid 16×16 quads; the native Center exit test checks visibility, facing, both flash frames, all directions, both avatar palettes and actual nontransparent pixels. Pokédex and Call-list foregrounds now mask their scrolling text and portraits in source priority order, retaining their frames. Three-picture Pokédex carousel scaling follows the source sine/cosine positions. The stats page uses source window coordinates, padded numbers, small/narrower fonts, type/category/candy icons and actual button/directional glyphs. A-toggle shows EV arrows, hidden abilities, egg groups and the source contest description/type/appeal/jam. Source stat macros are preprocessed with the actual metaprogram defaults. Complete source egg, level-up, TM/HM and tutor browsing is present in 0.7.2. Expanded battle effects and move learning remain pending. The common Map/Call footer follows source layer priority and covers the bottom of the location window in 0.7.2.

Falkner has no Sprout Tower prerequisite in the pinned HnS scripts. This release preserves that behavior, per the user's clarification. It adds no new progression blockers and does not change the launcher or save namespaces. Later campaign, unimplemented challenge effects and the final trainer/Cut-tree/route-order audit remain future work.

## GitHub releases

The repository stores the converter, runtime and regression checks. Update both `manifest.json` and `runtime/manifest.json` to the new mod version and increment `release/cart.json`'s cart version to publish a release; the manual Release workflow also accepts a matching mod version. Both versions are semantic versions. Never decrease the cart version below the supplied 1.0.0 reference, change its stable ID, or replace a published ZIP in place.

The workflow checks out the pinned public HnS and Gen1Recomp sources, builds without a ROM, runs native/converter/source audits and strict Modkit validation, then uses `release.py` to package a deterministic `hns_exploration-VERSION.zip`, `pokemon_heart_soul-CARTVERSION.g1rcart` and `SHA256SUMS`. The native cart parser/importer verifies the exact ZIP pin, embedded art, upgrade from 1.0.0, save namespace and sealed mod plan. The recommended cart download is listed first. Published version assets are immutable.

For local packaging after validation:

```bash
python3 release.py --mod /absolute/hns-build/hns_exploration --out /absolute/dist --engine /absolute/hns-gen1recomp --luajit /absolute/path/to/luajit
```
