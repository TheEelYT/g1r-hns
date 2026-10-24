# Player testing notes — 0.7.21

Use G1R 0.3.96. These notes are the normal place to reply after an update; report any other bug you notice too. Checks must fit the player's current location and available Pokémon. An inaccessible check is deferred, not a failure and not a confirmation.

## Current player checks

Synchronize/Cute Charm encounters and Infinite TMs are covered by automated checks in this update. If you use these naturally, report a mismatch; no bulk encounter sampling or spending rare TMs is requested.

No special testing trip is requested from the current Azalea save. Continue normal play and report anything that looks or sounds wrong. There is no need to obtain a shiny, hunt for a terrain/weather effect, walk back to Cherrygrove, or test every move or ability.

Future active checks should name a nearby, verified location or provide a quick, repeatable way to reach the test. If neither is available, keep the check deferred.

## Feedback received for 0.7.20

- **Azalea short grass: confirmed correct for both player and follower.** Remove this from active checks. The reply did not separately establish every time-of-day case.
- **Normal follower pond reflections: confirmed working as intended.** Ice/bridge and shiny reflection checks remain deferred.
- **New cart label: confirmed correct, including the mod version.**
- **Ordinary ground landing dust: reported unchanged.** No new dust retest is requested.
- **GB tonal percussion: the same tonal hit is audible in the original romhack, but less prominent.** Its presence is confirmed as source behavior; the difference in prominence remains an audio-fidelity observation. The cause is unconfirmed. Do not remove/change the source percussion or repeat the source-presence comparison.
- The player is currently in **Azalea** and has no shiny available for testing.

The confirmed 0.7.17 GB mart loop and removal of 0.7.18's extra 1/16-note rest remain settled. Earlier confirmed walking/running, hops, label shade, outdoor border following, capture jingles and title/UI checks remain removed.

## Deferred visual checks

These remain unverified in live player testing. Automated evidence is retained separately; it does not turn an inaccessible check into a player confirmation.

| Check | Why deferred | Prerequisite before requesting it |
|---|---|---|
| Ice and bridge follower reflections | Normal pond reflections are confirmed; ice/bridge cases have not been confirmed | Verified nearby location or quick test access |
| Shiny reflection palette | No shiny on the current save | A supplied test preset/save or a naturally obtained shiny; no shiny hunt requested |
| Seaweed finish-step bubbles, rising/expiry and cleanup | No known accessible seaweed location from current Azalea play | Verified location and quick access |
| Species-owned sand/footprint trails, turning, hold/flicker/expiry | Cherrygrove backtracking is impractical | Quick access or a nearby verified patch; no walk back requested |
| Deep-sand cover, puddle/ripple/shallow-water/hot-spring effects and water landings | Suitable locations have not been established for the player | Verified location and quick access |
| Fog/water shadow suppression | Fog has not been encountered | Natural encounter or a controlled weather test |
| Terrain backgrounds restoring after expiry/removal | Not confirmed by this reply | A relevant encounter during normal play or a supplied test setup |

## Developer follow-up

Before reactivating distant terrain/weather/shiny checks, provide an opt-in test area or equivalent quick-access setup, with an easy return and a supplied normal/shiny test follower. Keep test changes away from ordinary story progress and permanent party data. The documented native developer-console warp is Gen 1-only; it is not a verified Emerald shortcut.

Keep the GB mart arrangement and source percussion unchanged. Investigate the remaining difference in prominence at the playback/mixing/filtering/resampling boundary if audio work is resumed. Lower sample rate is a player hypothesis, not an established diagnosis.

Full reflection transition affine/blend parity, ash/weather effects, hidden acquisition and expanded battle/campaign work remain tracked in README and PROGRESS.md.

## Updating these notes

Refresh after each release and player reply. Remove confirmed checks from the active list, retain deferred/unresolved checks with their reason, and distinguish source behavior from port differences. Do not infer additional confirmations from a broader sentence. Keep README's permanent implementation checklist and the validation reports separate from player confirmations.
