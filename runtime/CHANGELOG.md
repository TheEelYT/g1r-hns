## 0.7.2 — Complete source Dex move lists, Pokégear polish and sealed cart releases

- Browse complete egg, level-up, TM/HM and tutor lists, with all 934 source move descriptions/parameters and correct source item icons. Read the configured generation-seven modern learnsets: Totodile now shows 87 entries. Legacy move aliases are resolved without changing native battle IDs; expanded battle effects and learning remain pending.
- Animate source stats-page Pokémon icons, restore red scroll arrows and unseen circled question portraits, widen list text to its source frame, and remove the unused window-mask rectangle over START/SELECT.
- Restore the common grey footer on Map and Call, center home help text, pulse the selected Pokégear button with source five-bit brightness, and order Elm before Mom. Condition becomes available once the party has a Pokémon.
- Use PREVIOUS/NEXT/SAVE and B CANCEL only for PC Game Modes. R on the last PC challenge page opens confirmation; R on the last loaded pause-options page remains inactive. Oak's initial confirmation is retained.
- Publish a sealed custom cart alongside the mod ZIP. The cart preserves pokemon_heart_soul, the embedded label and isolated saves; its GitHub pin contains the exact mod version and ZIP SHA-256. Recommend the cart download in release notes and installation guidance.
- Preserve existing map/script/text definitions, asset pixels, numeric IDs and save namespaces. Progression blockers remain deferred; no inferred Falkner gate or launcher changes.

## 0.7.1 — Source screen repairs and restored engine options

- Restore the native Gen1Recomp options in their own in-game tab: platform-appropriate speed, video, graphics, audio, performance, extras, controls and mod settings use the original row actions and saved options. HnS cartridge options stay on their source pages.
- Make R do nothing on the rightmost settings page in a loaded game, including the new engine tab. Preserve Oak's initial confirmation and PC challenge confirmation.
- Repair the invisible exit arrow by selecting frames from the actual horizontal source sheet. Retain native exit detection, source Gold/Kris palettes and flashing.
- Correct Pokédex list masking and three-picture carousel, stats spacing/fonts, ability and move windows, source icons and button glyphs. A-toggle uses source EV/egg-group and contest information. Egg/TM/tutor browsing and other unfinished Dex pages remain pending.
- Correct Pokégear Call foreground layering, the complete cursor and PKMN glyph spacing; draw the Map help bar behind its source location window.
- Preserve all 564 maps, 1,752 earlier scripts, 2,000 texts, prior non-code assets and saved IDs. Falkner has no Sprout Tower prerequisite in the pinned HnS source; no gate is added. The launcher is unchanged.
- Pass 79,796 native checks under each cache root, 19 converter tests, strict Modkit and independent source audits; inspect 53 CPU-rendered UI snapshots. Windows playtesting remains required.

## 0.7.0 — Source menus, bag, berries, entrances and saved counts

- Refine Pokégear Map/Call headings, contact labels, help/button icons, cursor/player positions and blink timing. Gate Condition at the source Elm unlock. Add source header/button slides and page fades.
- Add Pokédex fades, eight-tick list movement, rotating scroll ball and twenty-five-tick selected portrait movement. Keep later evolution/forms/size/cry features pending.
- Render the pause clock in the source bitmap font and source window. In-game options use source L/R icons without extra Back/Next/Save header text; dependencies and saved choices remain intact.
- Add source six-pocket bag presentation, separate displayed Medicine, berry pouch, source icons/names/descriptions, Gold/Kris bags and chrome. Retain native saved storage and item effects; repeated opening never mutates the source pocket order.
- Restore all 35 unconditional, in-bounds source berry objects, using 33 native saved tree IDs and source art/yields. Harvest with the source cue, automatically replant, retain full-bag retries and preserve regrowth after save/reload.
- Import source door sheets/palettes and opening/closing timing, including delayed script closes. Render exit arrows with source Gold/Kris palettes and flash frames.
- Correct Emerald title counts and save-only launcher compatibility. Preserve the real Dex and unlock state in modData; export a summary the existing launcher can count. Restore exact gameplay state on load, including nonregional catches. Save once after updating to refresh older launcher summaries. No launcher or engine patch is required.
- Preserve all prior terrain/assets/IDs and earlier story scripts except the reviewed source Condition-unlock guard. Keep remaining progression blockers for the final campaign pass. Full Windows playthrough remains user testing.

## 0.6.9 — Capture continuation, source Dex pages and Elm ratings

- Restore the capture-to-nickname handoff from the battle update after the registration modal closes. Use the HnS nickname prompt; clear obsolete battle text state. Exercise the real native Yes/No, naming keyboard, nickname write and repeat-catch decline flow.
- Replace the generic Pokédex list and details panels with HGSS Plus source backgrounds, fonts, normal portraits, footprints and source units. Add source statistics, EV/hidden-ability toggling and scrollable level-up move information. Use HnS's regional and obtainable-national order; unbridged species remain reserved. Source move/ability display data does not implement their remaining battle effects.
- Use one HnS counter for the save menu, Continue panel, trainer card, browser and Elm. Handle numeric/string saved keys and caught/owned aliases without duplicate counts. Preserve earned badges and native saved catch flags.
- Continue Elm's call through actual seen/caught totals and source Johto/national ratings. Retain errand/robbery calls and source completion exclusions. Browsing contacts cannot acknowledge Dex completion.
- Correct phone list fill, foreground and shadow colors. Decode source Dex OBJ counters tile by tile. Fix native image-table handling for Unown/Spinda and condition portraits.
- Split generated world datasets into separate Lua functions to avoid LuaJIT's per-function constant limit. Preserve all prior maps, scripts, save IDs and static assets. Evolution/forms, size/cry visualization, expanded battle mechanics and later campaign remain in progress.

## 0.6.8 — Pokégear services, field animations and collection screens

- Replace generic Pokégear subpages with source Map, Phone, Radio, Condition and Ribbons art/fonts/layouts. Preserve Mom/Elm calls and radio unlocks; restore map music on radio exit. Condition shows saved values using source graph geometry; Ribbons lists party/storage winners and displays earned icons/descriptions.
- Import pinned C tileset callback schedules for 69 animated pairs/124 banks, including water, flowers, waterfalls, interior effects and palette cycles. Bind after cache resets, apply native under/middle/over quadrant blits and upload changed textures.
- Animate the START move hint one pixel/frame over 28 frames on entry and exit. Preserve move details and native controls.
- Play HnS’s HG_EVOLVED capture-click cue followed by HG_CAUGHT, with session-scoped SE/wait translation.
- Use HGSS Plus caught registration with source data/art for all 386 supported species, source type icons/footprints, cry, fade and sprite slide. Retain native catch storage, first-catch detection and nickname continuation. Display the saved metric/imperial option.
- Show HnS trainer card palettes, Gold/Kris portraits, source stars/Johto badges and saved party on the reverse. Retain native statistics, flip animation and modal close.
- Keep earlier map/script/save namespaces unchanged. Reserve missing progression trainers, Cut trees and other route blockers for the final campaign pass, as requested. Later phone/radio gameplay and expanded battle content remain pending.

## 0.6.7 — Move information, capture timing and Pokégear home

- Restore the source START move-information hint and description window during battle move selection. Show source descriptions for all 354 supported moves, current category, power and accuracy. Directions change the selected move while details remain open; A, B or START closes details without choosing an attack.
- Automatically advance the initial Poké Ball announcement after printing, matching HnS's printstring → handleballthrow script. Retain native capture animation, result messages, storage and naming flows. Ordinary Emerald and scripted tutorials keep their original behavior.
- Replace the generic Pokégear home list with HnS backgrounds, device outline, animated icon, source button sprites, row positions and description box. Match source unlock order for Phone, Condition, Radio and Ribbons. Clock remains available in the pause display and Center clock service.
- Verify enabled EXP Share with different recipient levels. The pinned release configures B_SCALED_EXP as GEN_3 and EXP_CAP_NONE, so it does not add catch-up scaling. Retain source 2/3 participant and 7/25 reserve awards. Expanded battle content, later phone services and remaining Pokégear subpage layouts remain in progress.

## 0.6.6 — First HnS battle rules and opening regressions

- Play the source level-up fanfare while handing Elm the Mystery Egg in both the officer scene and manual fallback.
- Restore the post-errand New Bark departure gate until Mom's farewell, with a separate persistent flag and her source music. Earlier Mom conversations do not unlock this gate.
- Preserve the HnS Oak intro when EXIT recreates the boot menu and a new game is started.
- Import fixed HnS power, accuracy, PP, priority and types for all 354 existing moves; use the source type chart and 1/24, 1/8, 1/2, guaranteed critical odds. Hidden Power has 60 power, Explosion retains full defense, and Facade ignores the burn penalty. These rules apply independently of settings. Keep HnS's configured Gen 3 critical damage, paralysis speed, confusion chance, burn damage and sleep rules.
- Activate nine source settings: physical/special split, Fairy retyping, Sturdy, quarter-HP Sitrus, field poison survival, EXP multiplier, player EVs, player battle items and trainer battle items. Keep Poké Balls allowed when player medicine is banned. Test actual Counter history, Hustle accuracy, multi-hit/confusion Sturdy and native item/EV/EXP/poison behavior.
- Preserve existing world assets, save namespaces and earlier scenes except five reviewed Mom/gate script replacements. Audit all move parameters and type matchups using a C expression oracle. Expanded species/moves/abilities, modern learnsets, remaining settings and later campaign are still in progress. Windows playthrough remains a live test.

## 0.6.5 — Opening presentation and Cherrygrove

- Restore Oak’s Wooper release cue and the source red challenge warning.
- Use HnS bitmap settings fonts/frames, multiple choices, greyed dependencies, presets and YES/NO confirmation. PC GAME MODES respects source mid-run lock policies; unfinished effects remain PENDING.
- Show the full startup information overlay. Add source starter pictures/cries, nickname offers and persistent real nicknames.
- Add Elm’s email pause/sounds/question mark; the exit stop now releases control so his directions require a manual conversation. Restore Silver’s source shove.
- Restore all three Cherrygrove guide-entry lanes, five tour stops and departure indoors. Permit source running on Cherrygrove paths.
- Replace fullscreen phone text with source field call windows: ring, ellipsis, spinning icon, caller name, typed pages and hang-up.
- Preserve prior world/banner/battle-back/terrain/music/healing/stair/quest data. Expanded rules, later story and contacts remain in progress.

## 0.6.4

- Correct HnS new-game order: gender/name, then all six source challenge pages. Add all three source option pages, retaining 88 source rows/defaults/descriptions and saved pending choices.
- Use source Oak theme, brown-coat portrait and purple/gray intro backdrop. Spawn at the source bed; restore clock information, Mom’s Pokégear gift and pause-menu time. Center wall clocks can reset saved RTC with R.
- Make EXP. SHARE a key-item toggle with source party award ratios, native level-ups and exclusion of eggs/fainted Pokémon. Migrate older bag items without duplicating them.
- Restore early town blocker/window Silver/Route 29 grass man; Elm stops departure after a starter, steps the player back, gives source directions and registers his number automatically.
- Add Pokégear Johto/Kanto maps and source section labels, Mom/Elm phone and the yielded incoming errand call, condition/ribbon data and source quiz-gated Johto radio tuning/music. Later phone/radio rewards/content remain in progress.
- Replace generic border-banner backgrounds with source title/outline artwork/palettes and Emerald battle backs with source Gold/Kris animation strips.
- Preserve previous terrain, sprites, progress and music mixing. Add source-pixel, native UI/VM/RTC/XP/migration checks. Expanded rules, followers, later campaign and GB playback remain pending.

## 0.6.3

- Fix rival-name confirmation using the saved naming result instead of Emerald's MAY/BRENDAN placeholder.
- Import source lab-exit aide triggers and approach/departure movement, retaining one-time gifts and full-bag retries.
- Enable source town/route banners and append Gold/Kris player graphics for all native avatar states.
- Add Oak/Wooper introduction, source pictures/default names and supported native settings. New games start with GB SOUNDS/EXP. SHARE in the bedroom, set the saved clock and receive running shoes from Mom.
- Preserve previous maps, sprites, quest flags, inventory and audio. Expanded challenge rules, party-wide EXP. SHARE, alternate GB music and Pokegear remain unported.

# Changelog

## 0.6.2

- Implement source sideways-stair diagonal movement and blocked edges, occupied landing checks and source stair walking/running speeds. Stair tops no longer masquerade as ladders.
- Correct Mystery Egg to the source key-item fanfare and add the missing Pokédex item fanfare. Start receipt sounds with the text visible; preserve inventory guards and previous script bytes.
- Restore 1,368 ambient Pokémon objects, 104 supported source cry/dialogue interactions and 321 additional sheets. Preserve source palettes, form aliases, asymmetric right-facing frames, movement/ranges, and day/night visibility using the saved RTC. Bridge the two additional source movement types. Story-controlled and out-of-bounds source objects remain audited.
- Start the native Center healing effect with converted HnS ball/monitor art and source monitor timing. Turn the nurse toward the machine and back, exclude eggs from ball placement, wait for the effect/jingle, then heal once. Scripted non-Center healing fades to black, waits through the source jingle, restores the party and fades back in.
- Add native movement/VM/animation/fade/party/GPU-boundary regressions and independent source pixel/coverage checks. Preserve the user-confirmed 0.6.1 music mix. Desktop visuals still need live testing.

## 0.6.1

- Fix premature note cutoffs and missing instrumental layers: the native player was capped at five sampled voices while HnS initializes fifteen. Tag owned songs with source sound settings and use the pinned native sequencer with a configurable channel limit only for those slots. Vanilla sequences keep their original allocator.
- Use the source mixer rate of 304 samples per GBA VBlank for fixed-rate instruments, retaining pitched-sample tuning and the existing note clock.
- Reproduce early sustain loss in New Bark, Route 29, Violet and trainer battle music, then verify no premature looped-note cuts in the same passages and identical note start times/pitches/velocities. Add actual native gate-extension, tie/end-tie, sustain, release-envelope, chord and vanilla-isolation checks.
- Preserve world/party/inventory/progression data and all source song bytes. The user confirmed 0.6.0 playback; this corrected mix needs a Windows listening test.

## 0.6.0

- Add 133 HnS source songs and jingles through the native M4A sequencer/mixer: all map themes, source trainer encounter cues, battle/victory music, Oak, healing, level-up and item/egg/berry/TM/badge rewards. Preserve source MIDI settings, instruments, loops and intentional HGSS/DPPt voice-bank continuation. No game ROM is built or included; native Emerald sound effects and cries remain delegated.
- Restore New Bark Town's man and wandering Wooper with source dialogue, coordinates, walking frames and native Wooper cry. Add the six-frame follower-to-nine-frame native sprite conversion without renumbering previous sheets.
- Port Sprout Tower's Silver/Elder scene, Li battle and guarded Flash gift, plus four source tower pickups. Add source Falkner team, Zephyr Badge, guide/statue updates and guarded TM51 Roost. Battle losses do not award progress; bag rejection permits reward retry without refighting or duplicating gifts.
- Bridge Roost TM eligibility and move teaching, native half-HP recovery, and removal of Flying typing until turn end. Retain source PP. Match Johto's first-badge Flash requirement while keeping Cut behind the second badge.
- Verify every source song produces PCM, actual native audio pause/restoration, campaign scenes/rewards/persistence and TM/battle behavior. Preserve prior map pixels, IDs, script bytes and save namespaces; desktop sound/playthrough testing remains pending.

## 0.5.0

- Add source Elm entrance/email choreography, automatic Mr. Pokémon/Oak meeting, visible approaches/departures and the officer/name/Elm investigation. Native rival name persists through saves; already-delivered errands can complete naming without duplicate gifts. Add source broken window and stolen starter ball.
- Restore high-ID HnS sprite visibility in connected-map pools and normalize legacy scripted position rows to native operands.
- Replace the HnS start-menu Pokédex with Johto source ordering, HGSS Plus backgrounds, seen/caught list/entries, source descriptions/measurements, native portraits/base stats, paging and owned filtering. Expanded species retain reserved numbers; additional pages remain unported.
- Add 21 reviewed residents, including safe autoclose/multi-message source dialogue, conditional guide/neighbor and one-time CHERI BERRY with full-bag retry. Retain all previous sprite IDs and script bytes.
- Test source scenes through the actual VM/movement/visibility/entry tables, native naming save schema and menu modal rendering/input. Preserve all existing maps, quest IDs, party and graphics corrections.

## 0.4.2

- Serve a complete merged overworld sprite manifest through the HnS overlay. Replace the one-time in-memory placeholder with the normal OwSprites.install path, so readiness and NPC images survive renderer/sprite cache invalidation. Preserve vanilla sheet rows and Emerald player/avatar states, with unowned sprite bytes delegated unchanged.
- Extend FieldView.draw regressions to render actors in New Bark, Elm’s lab, Cherrygrove, the Center and mart; reject blue NPC placeholders. Load/draw all 62 HnS sheets across two cache resets, including standing and walking frames. Test manifest/Brendan/May preservation with an imported-manifest fixture. Select Emerald’s importer tables explicitly in the ROM-free SDK, matching desktop import.
- Reproduce 0.4.1’s blue placeholders in all five sampled scenes; all native checks pass with the corrected runtime. User confirmed 0.4.1 restored the world; the NPC correction still needs desktop retest. Terrain, events, source image bytes and save handling remain unchanged.

## 0.4.1

- Resolve HnS atlas blobs, overworld sheets and trainer portraits by exact owned identifiers across mounted cache roots. Clear native atlas readiness/images when binding the overlay. Reproduce 146 atlas-readiness failures in 0.4.0 with a cache-root change; the corrected build passes this fixture. The reported Windows red screen still needs desktop confirmation.
- Preserve Mr. Pokémon entry scripts and Silver coordinate/entry triggers when the real map loader reattaches event bundles.
- Add actual FieldView.draw coverage for New Bark Town, Elm’s lab and Cherrygrove, using real source bytes, atlas loading/baking, sampling and batches with a recorded GPU boundary. Retain all maps, gameplay assets and save namespaces; save handling is unchanged.

## 0.4.0

- Add persistent Mr. Pokémon → Silver → Elm errand, source conversations, native Mystery Egg key item, Oak’s Pokédex unlock and party healing. Silver uses the stronger level-5 source starter, source approach/departure movement and all three return triggers. Losses remain retryable.
- Add one-time aide gifts: one Potion after choosing a starter and five Poké Balls after egg delivery. Failed bag transactions do not consume gift flags. Cherrygrove stock upgrades to source zero-badge stock after delivery.
- Import 227 ordinary single trainer events across 72 maps, with 230 total source rosters including three Silver teams. Preserve species, levels, uniform IVs, explicit moves/held items, source portraits, class names/prize money and basic AI. Native trainer sight and defeat flags prevent repeat fights and persist through reload.
- Import 316 active daytime/default wild pools across 150 maps, preserving all 2,795 slots and source rates/levels. Unsupported expanded species, source-disabled pools and malformed pools are audited and omitted intact. Native capture stores monsters in party or PC.
- Preserve all 564 prior map/layout/terrain assets, sprite IDs/pixels, starter flags/variables and original script tails. Existing saves can Continue after replacing the mod and restarting. Add regression coverage for quest loss/retry, inventory rejection, three entry paths, all imported rosters and pools, capture storage and source compatibility.
- Automatic Mr. Pokémon/police choreography, phone calls, rival naming, rematches, Gym/badge progression and the later campaign remain unported. Battle data still comes from vanilla Emerald.

## 0.3.1

- Preserve native counter collision instead of overwriting it with generic blocking. Nurse Joy and mart employees can be reached by the real A-button interaction across desks; counters still block walking.
- Import ordinary NPC source movement types and movement ranges by name into the Emerald engine. Restore wandering, looking, rotations, walking sequences and in-place movement. Extend 37 existing sprite sheets with their original walking frames while preserving graphics IDs and standing pixels.
- Add 22 basic money-mart clerks with source pre-quest/zero-badge inventories and explicit equivalent Emerald item names. Use the native shop, bag and money system. Three expanded-item vendors remain audited omissions; exchange services and progression-dependent restocking remain later work.
- Regress all 28 nurse desks, all 22 imported mart desks, healing through an A-selected nurse, shop open/close and actual purchase/cancel/insufficient-money paths. Observe native NPC wandering/turning, collision, range, walking-frame selection and freeze/resume.
- Preserve all 564 maps, terrain assets, existing scripts, starter flags and variables from 0.3.0. Continue existing HnS saves after replacing the mod and restarting.

## 0.3.0

- Import all 560 HnS maps, including every interior, plus the four shared Emerald rooms referenced by the Frontier. Convert all 146 native tileset pairs and preserve 550,536 source layout cells.
- Restore 219 source map connections and 1,419 valid static warps. Preserve 11 dynamic-return headers using native session handling; eight have active source warp terrain and three are dormant source placeholders. Correct both shared Artisan Cave exits to their reciprocal HnS Frontier entrances.
- Reopen Violet trainer school: missing lower-layer padding is completely covered by known source foreground pixels. Reject exposed missing pixels; document the one transparent farmland placeholder. Handle short palettes and source-default Emerald layouts.
- Add 475 ordinary source dialogue NPCs, 28 basic healing nurses and 19 source-backed town return checkpoints. Convert 55 native NPC sheets, with standing poses for the new stationary NPCs. Keep conditional/story/trainer/shop events in a detailed omission report.
- Preserve the prior 35 maps, their original rendered tile pixels/palettes, six opening sprite sheets, scripts and starter save namespaces. The user confirmed the 0.2.1 starter, battle, leveling, healing and save/reload loop in-game.
- Keep story-driven map changes, scripted transport, wild tables outside Route 29, expanded battle data, water animations, area labels and music for subsequent milestones.

## 0.2.1

- Fix the crash entering Elm's lab and other interiors by reproducing HnS's map-load rule: set the first primary background palette entry to black. Seven of the twelve converted tileset pairs previously retained a nonblack source backdrop and failed the renderer's assertion.
- Preserve all other palette colors, NPC sheets, map layouts, scripts and save namespaces from 0.2.0.
- Validate all twelve pairs through the real renderer palette loader and RGBA baker, in addition to the binary decoders.

## 0.2.0

- Add eight source-positioned objects in Elm's lab and Mom's house, using six converted HnS NPC/Poke Ball sprite sheets.
- Bridge a simplified Elm introduction and three level-5 starter choices to the native Emerald party system. Map species by name rather than HnS numeric IDs.
- Persist starter-choice flags, hide the selected ball and prevent repeated gifts after save/continue. Declining or failing a gift leaves the choice open.
- Add lab healing through the engine's HealPlayerParty handler.
- Register the source daytime Route 29 land encounter table. Gate rolls until the player has a usable partner.
- Keep all 35 exploration maps and the corrected Route 30/31 and New Bark/Route 27 boundaries.
- Leave the full opening scenes, later quests, HnS battle rules, water animations, area labels and music for later milestones.

## 0.1.1

- Restore the missing Route 30 → Route 31 and New Bark Town → Route 27 connections. Their terrain now supplies the boundary instead of repeating the tree border.
- Extend the slice to 35 maps, including Violet City and its supported interiors, Sprout Tower, Route 46 and its gate, Dark Cave, and Tohjo Falls.
- Keep the trainer school closed because its source metatiles reference tile pixels absent from the supplied PNG.
- Keep existing exploration map IDs and save markers compatible with 0.1.0.
- Add native neighbor-sampling regression checks for both reported edges.

## 0.1.0

- Convert HnS source maps into native layered Gen1Recomp data.
- Register the bounded opening-area exploration world and simple signs.
- Enter New Bark Town from New Game using a separate save slot.
- Produce a campaign-port inventory; campaign logic is not implemented.
