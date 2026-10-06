# Pokémon Heart & Soul → Gen1Recomp 0.7.5

A development port of HnS Release-v2.0.6 for Gen1Recomp v0.3.44. Version 0.7.5 repairs battle action/move frames and message placement in both UI styles, restores the complete sliding R-ball prompt, and fixes Modern grass terrain. The original source PRET/RHH credits sequence now plays between copyright and Game Freak. Settings retain visible pending/partial support notices; the permanent checklist tracks completed and remaining work.

**Download `pokemon_heart_soul-1.0.4.g1rcart` from [Releases](https://github.com/TheEelYT/g1r-hns/releases/latest) and import it as a custom cart.** The cart installs the exact hash-pinned mod, isolates HnS saves and ships sealed with mod edits disabled. `hns_exploration-0.7.5.zip` is the alternative manual mod download; a ZIP alone does not create the custom cart.

## Install and test

Use Gen1Recomp **v0.3.44**, with vanilla US Emerald already imported. Import the cart, accept its pinned mod installation and select Pokémon Heart & Soul. The mod version is **0.7.5** and the cart version is **1.0.4**. The existing `pokemon_heart_soul` identity, label and seal are preserved, including upgrades from the supplied 1.0.0 cart. Restart after updating. Existing HnS party/inventory/map/story/settings namespaces are retained; a New Game is needed to replay the opening.

For a manual install, uninstall the prior same-ID mod, import the ZIP and enable it for Emerald. This does not select the custom cart or move vanilla saves into it. Disable the mod, select an Emerald slot and restart for ordinary Emerald. Hot reload is untested.

Suggested checks for this update:

- Launch from a closed game. Copyright should lead into the source POWERED BY / PRET × RHH credits, including Dizzy Egg and Porygon animation, then Game Freak and the HnS title. Any game button can skip the credits after their initial fade.
- In a grass encounter, select OLD and MODERN terrain separately. MODERN should show the source forest/grass backdrop instead of the generic striped building background. Repeat at morning, day, evening and night.
- Check the action menu, move menu and ordinary battle messages under both GEN 3 and GEN 4 UI. Source window borders, message origin/width, move names and PP/type panels should remain aligned. Check another user-selected window frame too.
- With Poké Balls in the bag, watch the R prompt slide in. Its full window and source ball icon should align; arrows appear while R is held and disappear on release. Hold R with a direction to cycle, then release without cycling to throw. Continue into the bag, moves and message states and check that the prompt slides away.

- Launch through the source credits, HnS Game Freak introduction and title, then press Start. EXIT → New Game must still show Oak and Wooper. The intro/title songs are the source `HG_INTRO` and `HG_TITLE`; Oak retains `HG_NEW_GAME`.
- In OPTIONS, enable Follower and, if desired, Big Followers. Walk a few steps with a healthy non-egg party member; the source sprite follows one cell behind and can be spoken to. Shiny palettes and walking frames are imported. Large followers use the source indoor restrictions; surfing, biking and forced travel hide followers. These options retain the source defaults, which can leave followers disabled.
- Select FAKE RTC and set the clock at a Pokémon Center. Time advances **24 game seconds per played second**, retains its value in saves and does not advance while the game is closed. Check morning/evening/night encounters and ambient Pokémon visibility. Outdoor colors transition at 06:00–10:00 and 18:00–20:00. Encounter night starts at 19:00; battle palettes deliberately retain the source's separate 20:00 night boundary.
- Switch Battle Terrain between OLD and MODERN and Battle UI between GEN 3 and GEN 4. Check Fast Intro, Fast Battles, R-ball selection and Quick Run. Hold R with a direction to select another available ball; release R without cycling to throw the selected ball. Run Type B selects RUN from the menu; the source L+R/B shortcuts can escape during the opening wild message before sending out the player Pokémon. The run prompt option controls the hint separately from the shortcut.
- Check CLOSE, USE, TOSS and ESCAPE labels in the bag. Use Escape Rope from each Sprout Tower floor; it should consume one and return to the recorded outdoor entrance. The Escape Rope/Dig difficulty restriction prevents use without consuming the item.
- Inflict paralysis, complete several turns, save and reload. Paralysis should persist until cured; the native engine passes numeric status IDs to the imported healthboxes. Older GBA numeric status fields are normalized once, with stale fields removed after migration.
- With Modern Moves enabled, compatible expanded moves appear in the source level-up/egg learnsets. Ice Fang has separate freeze/flinch chances and Drain Punch heals from damage dealt. START move details also supports the new IDs. Modern Moves OFF uses the source Gen 3 lists. Existing saved moves remain intact.

Arrow keys/WASD move; Z/Enter is A. Gen1Recomp's native key bindings apply.

## Imported world and gameplay

The port retains all **564 maps/interiors**, **146 tileset pairs**, **550,536 layout cells**, **219 connections**, **1,419 static warps** and 11 dynamic-return headers. There are **2,204 map objects**, source avatar states, 37 trainer portraits and source walking/turning/counter interactions. The normal/shiny follower assets add **826 sheets for 413 native species/forms** to the prior 402 overworld sheets. Missing conditional residents and later campaign objects remain tracked.

Opening gameplay includes gender/name followed by the six source challenge pages, Oak's Wooper, the bed/clock/help sequence, Mom's Pokégear/running shoes, GB SOUNDS and key-item EXP. SHARE. Elm's email/starter picture/nickname/exit stop and number registration, the aide gifts, lab healing, Cherrygrove guide, Mr. Pokémon/Oak scene, visible Silver encounter and officer naming/Egg handoff are retained. The town Lass blocks departure until Elm initially, and until Mom after the return investigation.

Sprout Tower includes the Silver/Elder scene, Li battle, Flash reward and four item balls. Violet Gym includes Falkner's source team, Zephyr Badge/TM51 Roost, guide/statue updates, retryable rewards and Flash's badge check. Roost restores half maximum HP, has source 5 PP and removes Flying typing until the turn ends. **The pinned HnS scripts do not require Sprout Tower before Falkner**, so this port adds no such gate.

There are **232 reviewed trainer rosters**, 502 team members and 316 default wild pools across 150 maps. Unsupported teams/pools are omitted intact. Timed encounter pools are now imported with source NULL fallbacks; later HM/rod access, swarms and radio encounter effects still need their campaign bridges. Source water/flower tile callbacks, doors, gold exit arrows, stairs, field Pokémon, healing animations/fades, labels and item jingles are retained. The build includes 150 source songs with native synchronous mixing and source gate/release/sustain timing. The user confirmed the previous music and early gameplay.

The Johto/National Pokédex, caught registration and nicknaming, animated statistics icons, unseen question portraits, list arrows and source button footers remain intact. The source move-information browser includes Totodile's full 87-entry modern list: 14 egg, 17 level-up and 56 teachable moves. Browsing an entry does not imply its battle effect or teaching path is implemented. Pokégear home/map/call/condition/ribbons/radio layouts, transitions/glow, Mom/Elm contacts and Elm's count/rating calls are retained. Goldenrod's radio quiz gate is implemented; later contacts, rematches, programs/rewards and Kanto card services remain pending.

The bag includes the berry pouch and source item artwork. Native berry-tree persistence, pickup/regrowth and prior save summary repairs remain intact. Native save loading restores real Dex state from `modData.hnsDexState`; launcher-compatible summary fields reflect actual caught and badge counts. No launcher changes are required.

## Settings and battle coverage

All nine source settings pages and 88 rows are present with source defaults, descriptions, dependencies and lock policies. Oak shows the challenge pages after naming. Pause OPTIONS uses source L/R icons and saves with B/Start; R does nothing on its final HnS page. PC Game Modes has its own previous/next/save/cancel controls and final confirmation. Recommended/custom, randomizer and Nuzlocke dependent rows gray out appropriately. A GEN1RECOMP tab restores platform-appropriate native speed, video, graphics, audio, performance, extras, controls and mod options through their original persistence/actions.

The native battle engine now uses HnS stats, catch rates, EXP yields, growth and EV yields for the supported species. Fixed move data, updated type chart, source critical odds, Hidden Power/Explosion/Facade and source physical/special choices remain active. HnS retains Gen 3 critical damage (2×), paralysis speed (¼), confusion chance (½), burn damage (⅛) and sleep rules. Gen 1 recharge, reduced escapes and Escape Rope/Dig restrictions are connected to their settings. Existing PP values are preserved; freshly learned moves use source PP.

The 23 reviewed rule/feature settings are recorded in `world.startup.rules.implemented`. This includes **partial Modern Moves coverage**: source level-up and egg lists translate existing native moves, Roost and explicitly reviewed compatible expanded moves. Unsupported effects are recorded in `world.expandedMoves.omitted`; they are never converted into generic damage. Distinct expanded move animations still use native presentation. Expanded TM/tutor learning and unsupported abilities/species/items/effects remain unfinished. Randomizer, Nuzlocke and remaining challenge rules are saved with source menus but their unported effects remain pending. FASTER text falls back to FAST; alternate GB SOUNDS playback remains pending.

EXP. SHARE uses the pinned source ratios: active participants split 2/3 of the base award, each eligible reserve receives 7/25, and one eligible party Pokémon receives the full award. Eggs/fainted members are excluded. Source `B_SCALED_EXP = GEN_3` does not weight awards by recipient level. Disabled mode delegates to native experience, and old bag-held EXP. SHARE migrates to the key item.

Outdoor tint uses the source's 5-bit arithmetic and time transitions. **Palette-bank light immunity and alternate-light high-bit behavior remain pending**; the current shader tints the outdoor field as a whole. Source battle terrain pixels and status strips are imported, while platform entry motion and battle orchestration remain native. Basic named follower dialogue and source emotes/ball transitions are active; full conditional interaction scripts, caught-ball variants and female-specific graphics remain pending. This release does **not** complete the entire enhanced battle system.

## Validation and rebuilding

Version 0.7.5 passes the native regression suite under both cache roots, 19 converter tests, strict Modkit validation and 92 CPU UI captures. Validation uses the real pinned native Lua modules with controlled boundaries for unavailable ROM data, GPU uploads and graphical effect handoffs. It exercises persistent status, source stats, all tower escape floors, saved Fake RTC, real grass-step encounter rolls in four time periods, changing tint viewports/error cleanup, follower emotes and door recall, complete native action/move/message battle draws, source terrain/healthboxes, full R prompt, shortcuts and credits/intro/title completion alongside the retained campaign/UI/audio regressions. Seven independent audits compare world/presentation/gameplay/services/Dex data and the new expansion with source; the tint oracle compiles the actual HnS `TimeMixPalettes` function and compares every ordinary 15-bit color at six transition points. CPU UI captures rasterize actual Lua draw calls and enforce source-sheet bounds.

**No graphical LÖVE runtime or imported Emerald ROM/cache is available here.** Windows gameplay, listening and live GPU rendering require a player check. CPU previews are not running-game screenshots. Detailed results and limitations are recorded under `reports/`.

Use Linux/WSL with Python 3.10+, Pillow, LuaJIT, gcc/g++ and GNU binutils. No ROM or GBA compiler is needed to build. Keep upstream sources separate and output to a fresh directory:

```bash
git clone https://github.com/PokemonHnS-Development/pokehns-expansion.git hns-source
git -C hns-source checkout 167aa6d537b109bb229c231ddce4616974c4da71
git clone https://github.com/bryanthaboi/gen1recomp.git hns-gen1recomp
git -C hns-gen1recomp checkout 20ab97abf8092c37344d108f2136ec4e5d131500
python3 -m pip install 'Pillow>=12,<13'
HNS_LUAJIT=/absolute/path/to/luajit python3 build_port.py --source hns-source --engine hns-gen1recomp --out build/hns_exploration
```

Run `tests/test_converter.py`; from the engine directory run `tests/test_native.lua MOD` with both the default and alternate cache roots. Use strict Modkit validation with `--base fixture`. Run each `tests/check_{world,fidelity,gameplay,presentation,services,dex_moves,expansion}.py` with source/engine/mod/LuaJIT paths. The Release workflow runs these checks automatically. Package with:

```bash
python3 release.py --mod /absolute/build/hns_exploration --out /absolute/dist --engine /absolute/hns-gen1recomp --luajit /absolute/path/to/luajit
```

## Releases and remaining work

Every release must update this README, the checklist and testing notes. Completed checklist entries remain visible with strikethrough; split partially completed work into completed and pending entries. Both manifests must match. Increment their mod version and `release/cart.json`'s cart version before publishing. The workflow builds from pinned source, validates and publishes the deterministic ZIP, sealed cart and SHA256SUMS. Cart tests use the native parser/importer to verify the GitHub pin, label, 1.0.0 upgrade, isolated save namespace and disabled mod edits. Published ZIP assets are immutable; never overwrite an existing version or change the stable cart ID.

Continue the unsupported enhanced battle mechanics/settings and expanded teaching paths, then later campaign scripts, puzzles, travel, contacts and rewards. The **final** campaign milestone remains the missing-trainer/Cut-tree/progression-blocker audit requested by the user. Keep testing travel open until that work is ready; do not invent new progression gates.

## Port progress checklist

This list is kept in every update. Checked entries stay struck through. A checked import is not a claim that its entire gameplay system is finished; remaining integration is listed separately.

- [x] ~~Import all source map layouts, interiors, tilesets, connections and static warps.~~
- [x] ~~Import source player walking/running states and trainer portraits.~~
- [x] ~~Import ordinary NPC walking, turning and counter interactions.~~
- [x] ~~Import supported overworld Pokémon normal/shiny sprites.~~
- [x] ~~Implement overworld stairs, opening doors and gold exit arrows.~~
- [x] ~~Import water/flower tileset animation and source town/route title artwork.~~
- [x] ~~Import source music/instruments, item jingles and healing sounds.~~
- [x] ~~Implement Pokémon Center healing animation and field healing fades.~~
- [x] ~~Implement Oak/Wooper, naming, source settings pages and new-game items.~~
- [x] ~~Implement bedroom start, clock/help, Mom, running shoes and Pokégear.~~
- [x] ~~Implement Elm/starter/nickname, aide gifts, Cherrygrove guide and Mr. Pokémon/Oak.~~
- [x] ~~Implement visible rival, investigation/name, Mystery Egg delivery and Mom farewell.~~
- [x] ~~Implement Sprout Tower and Violet Gym encounters, rewards and Roost TM.~~
- [x] ~~Import HnS bag/berry pouch, source berry tree graphics and harvesting.~~
- [x] ~~Import Pokédex list/detail/stats/moves pages and source UI animation.~~
- [x] ~~Implement capture registration/naming flow and consistent saved Pokédex counts.~~
- [x] ~~Import source trainer card, Pokégear/map/phone/condition screens and UI animation.~~
- [x] ~~Implement opening calls/ringing and source Elm call dialogue.~~
- [x] ~~Implement pause clock font, PC/pause settings controls and native GEN1RECOMP options tab.~~
- [x] ~~Identify unimplemented/partial settings inside OPTIONS and Game Modes.~~
- [x] ~~Import HnS Game Freak introduction, title background and source opening songs.~~
- [x] ~~Restore the original source PRET/RHH credits artwork and animated sequence.~~
- [x] ~~Implement saved Fake RTC, time transitions and native-species time encounter pools.~~
- [x] ~~Fix outdoor time tint across changing world viewports and zoom levels.~~
- [x] ~~Implement native-species followers, shiny palettes and trailing movement.~~
- [x] ~~Implement follower Poké Ball recall/release and basic named dialogue with source emotes.~~
- [x] ~~Import source species stats, move parameters, type chart and reviewed battle rules.~~
- [x] ~~Implement EXP. SHARE using the pinned source EXP ratios.~~
- [x] ~~Implement reviewed modern level-up/egg moves, Roost and battle move details prompt.~~
- [x] ~~Import selectable source battle terrain and Gen 3/4 healthboxes/status strips.~~
- [x] ~~Repair actual Modern grass selection, source battle frames/message windows and full R-ball prompt.~~
- [x] ~~Implement fast battle/intro, ball selection and Quick Run controls.~~
- [x] ~~Implement persistent status migration and source Escape Rope/Dig restrictions.~~
- [x] ~~Publish deterministic ZIP and sealed, save-isolated, hash-pinned custom cart.~~
- [ ] Finish enhanced battle effects, expanded abilities/items/species and distinct move animations.
- [ ] Finish expanded TM/HM/tutor learning, breeding and evolution behavior.
- [ ] Implement remaining Custom Game Mode rules and settings; retain visible pending notices until connected.
- [ ] Implement Randomizer settings and deterministic saved randomization.
- [ ] Implement Nuzlocke rules/clauses and remaining challenge restrictions.
- [ ] Finish difficulty/features/fishing/audio settings, including alternate GB SOUNDS playback.
- [ ] Match source battle platform entry motion and remaining battle presentation.
- [ ] Finish time palette-bank light immunity, alternate lights, swarms and expanded encounter species.
- [ ] Finish conditional follower reactions/scripts, caught-ball variants and female-specific graphics.
- [ ] Complete later Johto story scripts, gyms, puzzles, NPCs, items and rewards.
- [ ] Complete Kanto story scripts, gyms, puzzles, NPCs, items and rewards.
- [ ] Complete Pokégear contacts, later story calls, radio unlock/content and remaining pages.
- [ ] Complete field moves, travel, services, daily/time events and postgame systems.
- [ ] Audit remaining menus, effects and source UI details throughout the campaign.
- [ ] Final milestone: restore missing trainers, Cut trees and other source progression blockers; audit sequence breaks without inventing gates.
- [ ] Full Windows playthrough, save/upgrade compatibility and visual/audio regression pass.

## Provenance

HnS `Release-v2.0.6`: `167aa6d537b109bb229c231ddce4616974c4da71`. Gen1Recomp: `20ab97abf8092c37344d108f2136ec4e5d131500` (Windows v0.3.44 interfaces checked against `bd64bec97575b3a155b64791f1b058107ef31a0d`). Maps, dialogue, pixels, audio and data come from matching public HnS source; no ROM is included.

Credit PokemonHnS-Development, RHH's pokeemerald-expansion, resetes12's Modern Emerald, pret, the original developers and Gen1Recomp contributors. Upstream credits are retained. Converter, runtime glue and tests were authored for TheEelYT with Codex. Based on the Pokémon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC (https://github.com/bryanthaboi/gen1recomp). Private native derivatives retain `GEN1RECOMP_LICENSE.md` and its additional terms.
