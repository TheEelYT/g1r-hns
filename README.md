# Pokémon Heart & Soul → Gen1Recomp 0.7.22

A development port of HnS Release-v2.0.6 for Gen1Recomp v0.3.96. Version 0.7.22 connects the source Synchronize nature setting and Cute Charm encounter gender effect, makes Infinite TMs control machine consumption, and retains the confirmed field/cart corrections. The confirmed 0.7.17 GB mart loop and source percussion are unchanged.

**Estimated parity: about 42% complete / 58% remaining.** See [PROGRESS.md](PROGRESS.md) for the weighted feature inventory, evidence and measured coverage counters. This estimates feature parity, not engineering hours or binary matching; development version numbers are independent of completion.

**Download `pokemon_heart_soul-1.0.21.g1rcart` from [Releases](https://github.com/TheEelYT/g1r-hns/releases/latest) and import it as a custom cart.** The cart installs the exact hash-pinned mod, isolates HnS saves and ships sealed with mod edits disabled. `hns_exploration-0.7.22.zip` is the alternative manual mod download; a ZIP alone does not create the custom cart.

## Install

Use Gen1Recomp **v0.3.96**, with vanilla US Emerald already imported. Import the cart, accept its pinned mod installation and select Pokémon Heart & Soul. The mod version is **0.7.22** and the cart version is **1.0.21**. The existing `pokemon_heart_soul` identity and seal are preserved, including upgrades from the supplied 1.0.0 cart. Restart after updating. Existing HnS party/inventory/map/story/settings namespaces are retained; a New Game is needed to replay the opening.

Future cart packages render [the custom G1R Deluxe Heart & Soul label](release/pokemon-heart-soul.png) from [gbalabels.xcf](release/gbalabels.xcf). Packaging fills the editable `MOD_VERSION_NUMBER` layer inside `heartsoul` with the mod manifest's version, using bundled Cascadia Mono. The version fits its original box and lower-right anchor; the remaining artwork and child visibility are retained. The editable master is never overwritten. This release ships the generated versioned label; published downloads keep their original files. Artwork updates preserve the cart ID and existing save slots.

For a manual install, uninstall the prior same-ID mod, import the ZIP and enable it for Emerald. This does not select the custom cart or move vanilla saves into it. Disable the mod, select an Emerald slot and restart for ordinary Emerald. Hot reload is untested.

Arrow keys/WASD move; Z/Enter is A. Gen1Recomp's native key bindings apply.

The HEART & SOUL bubble uses the source HnS banner coordinates, fitting the notch under the Pokémon logo. The title screen retains the original `v2.0.6` banner flashing with PRESS START. A separate `Mod vX.Y.Z` label stays visible in the lower-right corner, using source-style bitmap lettering and normal screen fades. The mod version comes from the installed manifest; its periods no longer include neighboring source glyph pixels.

## Imported world and gameplay

The port retains all **564 maps/interiors**, **146 tileset pairs**, **550,536 layout cells**, **219 connections**, **1,419 static warps** and 11 dynamic-return headers. There are **2,216 map objects**, source avatar states, 37 trainer portraits and source walking/turning/counter interactions. The normal/shiny follower assets add **826 sheets for 413 native species/forms** to the prior 402 overworld sheets. Missing conditional residents and later campaign objects remain tracked.

Opening gameplay includes gender/name followed by the six source challenge pages, Oak's Wooper, the bed/clock/help sequence, Mom's Pokégear/running shoes, GB SOUNDS and key-item EXP. SHARE. Elm's email/starter picture/nickname/exit stop and number registration, the aide gifts, lab healing, Cherrygrove guide, Mr. Pokémon/Oak scene, visible Silver encounter and officer naming/Egg handoff are retained. The town Lass blocks departure until Elm initially, and until Mom after the return investigation.

Sprout Tower includes the Silver/Elder scene, Li battle, Flash reward and four item balls. Violet Gym includes Falkner's source team, Zephyr Badge/TM51 Roost, guide/statue updates, retryable rewards and Flash's badge check. Roost restores half maximum HP, has source 5 PP and removes Flying typing until the turn ends. **The pinned HnS scripts do not require Sprout Tower before Falkner**, so this port adds no such gate.

There are **232 reviewed trainer rosters**, 502 team members and 316 default wild pools across 150 maps. Unsupported teams/pools are omitted intact. Timed encounter pools are now imported with source NULL fallbacks; later HM/rod access, swarms and radio encounter effects still need their campaign bridges. Source water/flower tile callbacks, doors, gold exit arrows, stairs, field Pokémon, healing animations/fades, labels and item jingles are retained. The build includes 154 source songs/effects with native synchronous mixing and source gate/release/sustain timing. The user confirmed the previous music and early gameplay.

The Johto/National Pokédex, caught registration and nicknaming, animated statistics icons, unseen question portraits, list arrows and source button footers remain intact. The source move-information browser includes Totodile's full 87-entry modern list: 14 egg, 17 level-up and 56 teachable moves. Browsing an entry does not imply its battle effect or teaching path is implemented. Pokégear home/map/call/condition/ribbons/radio layouts, transitions/glow, Mom/Elm contacts and Elm's count/rating calls are retained. Goldenrod's radio quiz gate is implemented; later contacts, rematches, programs/rewards and Kanto card services remain pending.

The bag includes the berry pouch and source item artwork. Native berry-tree persistence, pickup/regrowth and prior save summary repairs remain intact. Native save loading restores real Dex state from `modData.hnsDexState`; launcher-compatible summary fields reflect actual caught and badge counts. No launcher changes are required.

## Optional practice saves

Save on dry ground first. Open **START → OPTIONS → GEN1RECOMP → PORT TEST TOOLS → Create practice copy**, then choose YES. The copy uses your last saved point, not unsaved changes. Exit to the launcher and select the new **HnS PRACTICE** save slot, then Continue. The regular slot stays selected until you choose another slot. Both the sealed cart and manual Emerald mod use their own native save namespaces.

The practice copy has a separate playthrough identity, copied story flags and PC, a fresh test bag, and two level-25 Poliwrath: NORMAL has one move for immediate TM teaching; SHINY has four for replacement/cancellation. Drain Punch, Water Pulse and Protect are supplied in stacks of nine. Its PORT TEST TOOLS menu can refill those TMs, swap the first two followers, jump to verified terrain strips and return to the copied save point. Test changes can be saved in that slot. Use the launcher to select your regular slot again when finished. No practice supplies, party edits or shortcuts are applied to your regular save.

Only converted, passable five-tile walking strips away from objects/events are offered; walk LEFT and RIGHT. Seaweed, pond/bridge/ice reflections, deep sand, puddles and controlled weather remain deferred where no suitable strip is supplied. Practice conveniences do not add source-parity credit to the progress estimate.

## Settings and battle coverage

All nine source settings pages and 88 rows are present with source defaults, descriptions, dependencies and lock policies. Oak shows the challenge pages after naming. Pause OPTIONS uses source L/R icons and saves with B/Start; R does nothing on its final HnS page. PC Game Modes has its own previous/next/save/cancel controls and final confirmation. Recommended/custom, randomizer and Nuzlocke dependent rows gray out appropriately. A GEN1RECOMP tab restores platform-appropriate native speed, video, graphics, audio, performance, extras, controls and mod options through their original persistence/actions.

The complete source move table is imported as `world.moveTable`: 1 empty row, 354 native bridges, 168 reviewed custom moves and 412 pending effects. Names/descriptions, parameters, targets, flags and original source field expressions are retained. Pending rows remain excluded from learned move lists; importing data does not implement their effects. Roost’s source row keeps its existing save ID 901 and the reviewed healing/temporary Flying-removal handler. New reviewed effects include exact 50/75/100% draining, 25/33/50% recoil, Shell Smash, Quiver Dance, Coil, Hone Claws, Work Up, Cotton Guard and Victory Dance. Drain/recoil use actual damage, including substitutes, and respect native Liquid Ooze/Rock Head behavior. Native stage limits and ordered source changes remain active; expanded ability interactions and distinct animations remain pending.

The native battle engine now uses HnS stats, catch rates, EXP yields, growth and EV yields for the supported species. Fixed move data, updated type chart, source critical odds, Hidden Power/Explosion/Facade and source physical/special choices remain active. HnS retains Gen 3 critical damage (2×), paralysis speed (¼), confusion chance (½), burn damage (⅛) and sleep rules. Gen 1 recharge, reduced escapes and Escape Rope/Dig restrictions are connected to their settings. Existing PP values are preserved; freshly learned moves use source PP.

The 26 reviewed rule/feature settings are recorded in `world.startup.rules.implemented`. This includes **partial Synchronize coverage** (ordinary wild/static encounters; Safari/Pokéblock interactions remain pending) and **partial Modern Moves coverage**: source level-up and egg lists translate existing native moves, Roost and explicitly reviewed compatible expanded moves. Unsupported effects are recorded in `world.expandedMoves.omitted`; they are never converted into generic damage. The R-ball and START-details prompts advance once on every native fixed step, finish sliding off during messages/attacks/throws, and clear when the battle closes. Menu input no longer owns their animation clock. Distinct expanded move animations still use native presentation. The source Synchronize setting now controls wild/static encounter nature matching (classic half-chance or source modern guarantee), using the first party slot even if fainted. Cute Charm gives its source two-in-three opposite-gender attempt and safely excludes fixed-gender targets; gifts, roamers, preset personalities and special encounter modes keep their native paths. Constrained personalities are generated before native stats, abilities and captures are built. The native RNG stream remains in use; this does not reproduce HnS SFC32 save-state randomness. Infinite TMs now retains ordinary TMs when enabled and consumes them after successful learning when disabled; HMs remain reusable. Failed/cancelled teaching consumes nothing. The source machine catalogue supports 92 TMs and 8 HMs, including HM08 Whirlpool. Source species compatibility, machine descriptions/type-colored icons, native learning/consumption and HM protection are connected. Unsupported effects show an explicit message and cannot be taught. Twelve exact source TM item-ball scripts now use persistent, bag-full-safe pickup grants. The level relearner uses the complete selected source list, removing the native twenty-row limit. A source-name tutor compatibility API is ready for later event bridges; tutor NPC menus, fees/unlocks and other machine rewards/shops remain pending. Unsupported abilities/species/items/effects remain unfinished. Randomizer, Nuzlocke and remaining challenge rules are saved with source menus but their unported effects remain pending. FASTER text falls back to FAST. GB SOUNDS now selects 123 mapped songs from 104 distinct source GB tracks, switching source music/fanfare bytecode on and off from the Bag or registered item, saving the source enable flag. Fractional note lengths, calls/loops, pitch changes, vibrato, duty patterns, wave tables and drums run through a source-scoped sequencer and the native PSG mixer. Songs without a source GB mapping retain normal playback. Pokégear ON/OFF/SELECT effects are included as source sequences on their original SE player channels, with open/close, cursor and page-transition callbacks connected. GB cry remaps, hardware SFX channel arbitration and exact analog PSG behavior remain pending.

Core Electric, Grassy, Misty and Psychic Terrain moves now set a separate five-turn field state. Source grounded checks control the 30% type-power boost, Dragon damage reduction, sleep/status/confusion protection, Grassy HP recovery and Psychic priority protection. Grassy also halves reviewed Earthquake/Magnitude power. Power uses the source fixed-point rounding before damage; healing and expiry use the native residual scheduler. Terrain Extender lasts eight turns; Damp/Heat/Smooth/Icy Rock extend matching move-created weather. These five source items have registered names, prices, descriptions and icons, with stable IDs 945–949. The four field backgrounds follow the source configuration independently of the old/Modern arena setting and restore the map background when terrain ends. Eight dependent attacks are connected: Terrain Pulse, Rising Voltage, Expanding Force, Misty Explosion, Psyblade, Grassy Glide, Steel Roller and Ice Spinner. Ground checks, separate source rounding steps, native spread targets, Damp/self-faint behavior, priority and successful-hit removal are covered by automated checks. Electric/Grassy Seeds raise Defense, Misty/Psychic Seeds raise Sp. Def, consuming the held item only when a stat can rise. As in the source, airborne Pokémon can activate seeds. Entry/terrain-change triggers use native callbacks and item persistence. Four Surge entry handlers set five/eight-turn terrain, with matching seed activation and same-terrain/sky-battle rejection. Their names, descriptions and stable numeric IDs are available through the scoped ability API; source normal/hidden slot identities now resolve for all 386 supported base species and Unown forms, including source fallback and the nine Legendary Abilities overrides. Existing party and sparse PC slots migrate on load/map entry; creation, battle construction and native evolution retain slot identity. Acquisition services, source ability popups and other expanded interactions remain pending. Pending abilities retain their true identity and description; their unimplemented effects remain tracked. Item acquisition and remaining field/weather rules also remain pending. Z/Max move rows are explicitly excluded until their transformations are implemented; 26 previously eligible special-form rows are now correctly pending. This does not complete the entire enhanced battle system.

EXP. SHARE uses the pinned source ratios: active participants split 2/3 of the base award, each eligible reserve receives 7/25, and one eligible party Pokémon receives the full award. Eggs/fainted members are excluded. Source `B_SCALED_EXP = GEN_3` does not weight awards by recipient level. Disabled mode delegates to native experience, and old bag-held EXP. SHARE migrates to the key item.

Outdoor tint uses the source's 5-bit arithmetic and time transitions. **Palette-bank light immunity and alternate-light high-bit behavior remain pending**; the current shader tints the outdoor field as a whole. Source battle terrain pixels, Modern entry layers/scroll progression and status strips are imported; battler/sprite orchestration and blend effects retain native integration. Followers animate two source idle poses with one-pixel bobbing and retain actor/position across seamless outdoor borders. Ledge jumps use the source high arc during player hops and faster normal arcs when the player resumes walking/running. New steps cannot restart an unfinished follower movement; its latest trailing destination is retained. Walking and normal/GB capture jingles have been confirmed by the player. Player and follower short-grass effects now share the source image/palette and draw in the same outdoor lighting pass; source palette tag 0x1005 is not time-blend immune. Shadows stay behind the owner and short-grass leaves across idle bobbing, camera rows and elevations; diagonal fog/underwater bubbles and current/previous water behaviors follow source suppression rules. Source species track types now select footprints, spot/bug trails or turning slither tracks on sand and footprint tiles, with the source 40-frame hold/flicker/expiry. Deep sand adds a moving foot-cover effect; puddles use owner splashes/ripples and the imported source SE channel, shallow water loops at the feet, hot springs cover the lower body, and water landings select splash sheets. Recalling a follower clears its attached effects; detached trails expire normally. Native reflections now use source pond/ice/bridge palettes, including normal/shiny followers, and the same follower poses as the visible actor. Seaweed emits source bubbles after completed steps. Full ball-transition reflection affine/blend effects, ash and further map-specific effects remain pending. Repeated game setup preserves the effect state referenced by existing collectors. Moving poses use source six/four-frame animation commands and phase alternation, preserving phase across steps and speed/direction changes. Building doors retain recall/release. Basic named follower dialogue and source emotes/ball transitions are active; full conditional interaction scripts, caught-ball variants and female-specific graphics remain pending. This release does **not** complete the entire enhanced battle system.

## Validation and rebuilding

Version 0.7.22 passes the native regression suite under both cache roots, 19 converter tests, strict Modkit validation and 121 CPU UI captures. Validation uses the real pinned native Lua modules with controlled boundaries for unavailable ROM data, GPU uploads and graphical effect handoffs. It exercises persistent status, source stats, all tower escape floors, saved Fake RTC, real grass-step encounter rolls in four time periods, changing tint viewports/error cleanup, follower idle draws, actual Azalea triple ledges with Down held into walking/running, seamless map origins in four directions, emotes and door recall, GB Bag/registered toggle/save flag, source compound Pokégear label and menu cue callbacks, all music channels and native buffered PCM, complete native action/move/message battle draws, source terrain/healthboxes, full R prompt, shortcuts and credits/intro/title completion alongside the retained campaign/UI/audio regressions. Seven independent audits compare world/presentation/gameplay/services/Dex data and the new expansion with source. A compiled oracle checks 1,078 frames of the actual source battle-entry C tasks; the tint oracle compiles HnS `TimeMixPalettes` and compares every ordinary 15-bit color at six transition points. Ability identities, names/descriptions and retained fields are checked against compiled source; seed stat/grounding and title-position contracts are audited independently. A separate oracle compiles the source terrain-boost functions and compares 40,960 power cases over all ground/field combinations; source pixels and Z/Max range checks are independent as well. A follower oracle compares 2,048 pose frames, 56 jump frames and 128 walking-bob frames with the actual source C routines. The source ability resolver is compiled for 3,860 slot/setting cases; 1,229 object shadow-size rows, 2,496 shadow-mask pixels and 2,816 follower grass pixels are audited. A mixer audit covers every distinct mapped GB song and verifies audible Pokémart wave output for the GBA force-75% register bit. The GB sequencer matches 233,238 frames (14,927,232 register bytes) against a host build of the unmodified source command/register routines; this checks register writes and timing, including 20,000 mart frames across multiple repeats, while audible PSG fidelity still needs player feedback. The GB mart conversion moves its loop past the 32-unit intro using the HG MIDI’s `[` marker; loop-entry octave/envelope state is restored. The mart retains 0.7.17's player-confirmed 928-unit arrangement and single-unit tail rest; the extra 1/16-note rest from 0.7.18 is removed. The converted assembly is byte-identical to 0.7.17, and repeat frames are checked without resetting fractional carry. Player feedback for 0.7.20 confirms Azalea short grass for both player and follower, normal follower pond reflections, and the versioned cart label. The player also hears the tonal percussion in the original romhack, with less prominence; its cause remains unconfirmed and source percussion is unchanged. Audible/analog PSG fidelity is still tracked separately. Inaccessible terrain, weather and shiny checks are deferred in TESTING.md. The source shadow predicates are independently compiled for all 243 behavior rows; actual native sorting checks all 16 elevations, 32 camera offsets and both idle heights, plus an overlapping source leaf/shadow pixel. Native frame-95 capture and capture-success wait callbacks are exercised with the current Emerald profile in both GB and normal modes, selecting HnS HG_EVOLVED then HG_CAUGHT. CPU UI captures rasterize actual Lua draw calls, enforce source-sheet bounds and verify Modern BG3/BG1 source scroll coordinates plus field replacement/restoration.

**No graphical LÖVE runtime or imported Emerald ROM/cache is available here.** Windows gameplay, listening and live GPU rendering require a player check. CPU previews are not running-game screenshots. Detailed results and limitations are recorded under `reports/`.

Use Linux/WSL with Python 3.10+, Pillow, LuaJIT, gcc/g++ and GNU binutils. No ROM or GBA compiler is needed to build. Keep upstream sources separate and output to a fresh directory:

```bash
git clone https://github.com/PokemonHnS-Development/pokehns-expansion.git hns-source
git -C hns-source checkout 167aa6d537b109bb229c231ddce4616974c4da71
git clone https://github.com/bryanthaboi/gen1recomp.git hns-gen1recomp
git -C hns-gen1recomp checkout 0e92b587468c2db7c386f055fc272e6505b0f401
python3 -m pip install 'Pillow>=12,<13'
HNS_LUAJIT=/absolute/path/to/luajit python3 build_port.py --source hns-source --engine hns-gen1recomp --out build/hns_exploration
```

Run `tests/test_converter.py`; from the engine directory run `tests/test_native.lua MOD` with both the default and alternate cache roots. Use strict Modkit validation with `--base fixture`. Run each `tests/check_{world,fidelity,gameplay,presentation,services,dex_moves,expansion}.py` with source/engine/mod/LuaJIT paths. The Release workflow runs these checks automatically. Package with:

```bash
python3 release.py --mod /absolute/build/hns_exploration --out /absolute/dist --engine /absolute/hns-gen1recomp --luajit /absolute/path/to/luajit
```

Cart packaging also needs GIMP 3. The release workflow installs the official GIMP 3.2.6 AppImage with a pinned SHA-256 and uses its extracted runtime, requiring no FUSE. For the same Linux setup, run `bash tools/setup_gimp.sh` and set `HNS_GIMP` to the absolute path of `.tools/gimp/squashfs-root/AppRun` before packaging. Cascadia Mono and its OFL license are bundled under `release/fonts`; no system font installation is needed. `python3 cart_label.py --out build/label-preview.png` previews the current mod version. Packaging renders a fresh `dist/pokemon-heart-soul.png` and embeds those exact bytes at the cart's top-level `labelArt`; it never reuses a stale preview PNG. The XCF and font are build inputs, excluded from the mod ZIP.

The reviewed `release/cart-label-artwork.png` supplies pixels outside the original version box. Its sidecar records both its hash and the XCF hash: this preserves the exact artwork despite GEGL's occasional one-unit blend rounding differences. The sidecar also stores a clean source version-box background. Each build exports fresh version glyphs from GIMP and composites them in linear light with fixed-point arithmetic over that reviewed background; this avoids GEGL one-unit rounding differences at text edges as well. After deliberately editing the XCF artwork, run `python3 cart_label.py --refresh-art`, review the result and commit the updated artwork reference and sidecar together. Version-only releases need no refresh.

`python3 tests/test_cart_label.py --engine /absolute/hns-gen1recomp --luajit /absolute/path/to/luajit` checks real version changes, longer versions, unchanged artwork outside the version box, reproducible packaging and native cart/save/seal behavior. Its tiny fixture mod exercises packaging without rebuilding game assets. The separate Cart label workflow runs this check without publishing a release.

## Releases and remaining work

**Version policy:** Mod **1.0.0 is reserved for 100% parity with the pinned HnS romhack**, including gameplay, settings, story, presentation and content. Development releases remain 0.x patch iterations; their numbers are not percentages of completion. The cart has an independent packaging version and does not indicate mod parity.

Every release must update this README, the progress checklist and the separate [player testing notes](TESTING.md). Completed checklist entries remain visible with strikethrough; split partially completed work into completed and pending entries. Both manifests must match. Increment their mod version and `release/cart.json`'s cart version before publishing. The workflow builds from pinned source, validates and publishes the deterministic ZIP, sealed cart and SHA256SUMS. Cart tests use the native parser/importer to verify the GitHub pin, label, 1.0.0 upgrade, isolated save namespace and disabled mod edits. Published ZIP assets are immutable; never overwrite an existing version or change the stable cart ID.

Continue remaining follower ground effects, hidden-ability acquisition, transfer/suppression rules, expanded interactions and held-item acquisition, remaining weather/complex turn-state effects, then tutor services and the remaining enhanced battle settings, then later campaign scripts, puzzles, travel, contacts and rewards. The **final** campaign milestone remains the missing-trainer/Cut-tree/progression-blocker audit requested by the user. Keep testing travel open until that work is ready; do not invent new progression gates.

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
- [x] ~~Connect follower idle poses/bobbing, consecutive ledge movement and persistent seamless-border following.~~
- [x] ~~Prevent continuous-input ledge restarts and connect source walking/running pose cadence.~~
- [x] ~~Use the source compound Pokégear start-menu label and connect menu open/close/navigation sounds.~~
- [x] ~~Match Pokégear menu ink, preserve follower poses across walking gaps and decode GBA wave-channel 75% overrides.~~
- [x] ~~Import persistent field shadow masks/sizes and connect follower tall/long-grass rustles.~~
- [x] ~~Correct GB Pokémart repeats using the source MIDI loop marker and native capture jingles in normal/GB modes.~~
- [x] ~~Match walking bob timing, prevent idle handoff during held walking and connect Azalea short-grass follower overlays.~~
- [x] ~~Complete the GB mart whole-bar boundary and share player/follower source short-grass images and palettes.~~
- [x] ~~Keep shadows behind bobbing followers/short grass and connect source fog/water shadow suppression.~~
- [x] ~~Connect source species-owned follower trails, deep-sand cover, puddle/ripple/shallow-water/hot-spring effects and water landings.~~
- [x] ~~Connect source pond/ice/bridge reflection palettes, shared follower poses and seaweed finish-step bubbles.~~
- [x] ~~Generate versioned cart labels from the checked-in editable XCF.~~
- [x] ~~Record weighted parity scope, evidence and measured coverage counters.~~
- [ ] Finish ball-transition reflection effects, ash, further map-specific follower effects and full weather parity.
- [x] ~~Import source species stats, move parameters, type chart and reviewed battle rules.~~
- [x] ~~Import the complete configured HnS move table, retaining pending effect/argument/flag/animation data.~~
- [x] ~~Implement EXP. SHARE using the pinned source EXP ratios.~~
- [x] ~~Implement reviewed modern level-up/egg moves, Roost and battle move details prompt.~~
- [x] ~~Import selectable source battle terrain and Gen 3/4 healthboxes/status strips.~~
- [x] ~~Repair actual Modern grass selection, source battle frames/message windows and full R-ball prompt.~~
- [x] ~~Import source Modern entry layers/scroll progression and fix healthbox text bounds/palettes.~~
- [x] ~~Implement fast battle/intro, ball selection and Quick Run controls.~~
- [x] ~~Implement persistent status migration and source Escape Rope/Dig restrictions.~~
- [x] ~~Match the manifest-derived Mod version caption to the original banner bitmap style and palette fades.~~
- [x] ~~Run ball/move-info prompt animations continuously through menu transitions, messages, attacks and throws.~~
- [x] ~~Implement four core terrain moves, grounded damage/status/priority rules, Grassy healing and timed expiry.~~
- [x] ~~Register the five source weather/terrain duration items and connect their turn extensions.~~
- [x] ~~Restore the original flashing source-version banner and a steady lower-right Mod caption with single periods.~~
- [x] ~~Import the four source field backgrounds and restore the arena background when terrain ends.~~
- [x] ~~Connect eight terrain-dependent attacks with grounded power/type changes, spread targets, priority and successful-hit removal.~~
- [x] ~~Import all 311 source ability identities/descriptions/fields with stable IDs and explicit coverage.~~
- [x] ~~Implement four terrain seed items and native entry/terrain-change activation and consumption.~~
- [x] ~~Implement the four Surge entry handlers with five/eight-turn terrain and seed triggers.~~
- [x] ~~Connect source normal/hidden ability slots, legacy-save migration and the Legendary Abilities setting.~~
- [ ] Connect hidden-ability acquisition, transfer/suppression rules and source ability popups.
- [ ] Finish other terrain ability interactions, held-item acquisition and remaining field/weather effects.
- [ ] Finish enhanced battle effects, expanded abilities/items/species and distinct move animations.
- [x] ~~Import all 92 source TMs/8 HMs, source species teaching lists, type-colored machine icons and stable item IDs.~~
- [x] ~~Connect native machine teaching, explicit pending-effect rejection, source HM protection and complete level relearner lists.~~
- [x] ~~Implement exact drain/recoil percentages and reviewed multi-stat setup effects.~~
- [x] ~~Restore twelve exact source TM item-ball pickups with bag-full retries and saved flags.~~
- [ ] Finish tutor NPC menus, fees/unlocks, remaining machine rewards/shops, field-HM progression, breeding and evolution behavior.
- [x] ~~Connect source Synchronize/Cute Charm encounter generation and configurable Infinite TMs.~~
- [ ] Implement remaining Custom Game Mode rules and settings; retain visible pending notices until connected.
- [ ] Implement Randomizer settings and deterministic saved randomization.
- [ ] Implement Nuzlocke rules/clauses and remaining challenge restrictions.
- [x] ~~Connect source GB SOUNDS music/fanfare playback, saved toggle and registered-item use.~~
- [ ] Finish GB cry remaps, hardware SFX arbitration, audible PSG parity and remaining difficulty/features/fishing/audio settings.
- [ ] Finish source battler/sprite entry orchestration, blend effects and remaining battle presentation.
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

HnS `Release-v2.0.6`: `167aa6d537b109bb229c231ddce4616974c4da71`. Gen1Recomp v0.3.96: `0e92b587468c2db7c386f055fc272e6505b0f401`, the latest release checked for this update. Older-engine validation runs have been retired. Raw and installer-compressed assets are checked against that same pinned release. Maps, dialogue, pixels, audio and data come from matching public HnS source; no ROM is included.

Credit PokemonHnS-Development, RHH's pokeemerald-expansion, resetes12's Modern Emerald, pret, the original developers and Gen1Recomp contributors. Upstream credits are retained. Converter, runtime glue and tests were authored for TheEelYT with Codex. Based on the Pokémon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC (https://github.com/bryanthaboi/gen1recomp). Private native derivatives retain `GEN1RECOMP_LICENSE.md` and its additional terms.
