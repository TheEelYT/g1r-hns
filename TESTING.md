# Player testing notes — 0.7.23

Use G1R 0.3.96. These notes are the normal place to reply after an update; report any other bug you notice too. Checks must fit the player's current location and available Pokémon. An inaccessible check is deferred, not a failure and not a confirmation.

## Current player checks

Use the existing **HnS PRACTICE** slot for these optional checks. Its party and supplies remain separate from the regular save. Access tools at **START → OPTIONS → GEN1RECOMP → PORT TEST TOOLS**.

- **Four-move TM learning:** use a supplied TM on SHINY. Press A through the already-four-moves message; it should ask whether to delete/replace a move, then open the move-selection summary. Selecting an ordinary move should teach it. Declining or cancelling should keep the original moves and TM count. Infinite TMs is already player-confirmed; no repeat ON/OFF consumption test is requested.
- **Shadow order:** while walking north with the follower behind, shadows should remain behind their owning sprites. Observe ordinary nearby NPCs too if convenient; no special trip is needed.
- **Ice follower:** use the Ice shortcut and move left/right. The follower should stay out, slide along and finish its trailing step without recalling into a Poké Ball. Normal/shiny ice reflections can be checked there once movement is working; their live appearance is still unconfirmed.

Sand, short-grass and shallow-water footsteps are confirmed by the latest feedback and are removed from active checks. No terrain hunt or backtracking is requested.

## Feedback received for 0.7.22

- Infinite TMs works. The reply does not establish OFF consumption or successful four-move replacement.
- Sand, short grass and shallow-water footsteps look right to the player's knowledge.
- Four-move TM teaching cancels after the already-four-moves message instead of offering deletion/replacement.
- The follower enters its Poké Ball while moving on ice, blocking meaningful ice-reflection testing.
- Sprite shadows draw above sprites, especially while moving north with the follower behind.

The three reported bugs are repaired in 0.7.23 but await player confirmation. Automated coverage now drives the real TM message/choice/summary input path, the complete camera-aware collector chain and native Ice Path forced movement.

## Feedback received for 0.7.20

- **Azalea short grass: confirmed correct for both player and follower.** Remove this from active checks. The reply did not separately establish every time-of-day case.
- **Normal follower pond reflections: confirmed working as intended.** Ice/shiny ice checks have optional practice access once the reported recall bug is repaired; bridge and shiny pond checks remain deferred.
- **New cart label: confirmed correct, including the mod version.**
- **Ordinary ground landing dust: reported unchanged.** No new dust retest is requested.
- **GB tonal percussion: the same tonal hit is audible in the original romhack, but less prominent.** Its presence is confirmed as source behavior; the difference in prominence remains an audio-fidelity observation. The cause is unconfirmed. Do not remove/change the source percussion or repeat the source-presence comparison.
- The player is currently in **Azalea** and has no shiny available for testing.

The confirmed 0.7.17 GB mart loop and removal of 0.7.18's extra 1/16-note rest remain settled. Earlier confirmed walking/running, hops, label shade, outdoor border following, capture jingles and title/UI checks remain removed.

## Deferred visual checks

These remain unverified in live player testing. Automated evidence is retained separately; it does not turn an inaccessible check into a player confirmation.

| Check | Why deferred | Prerequisite before requesting it |
|---|---|---|
| Bridge follower reflections | Normal pond reflections are confirmed; bridge cases have not been confirmed | Verified nearby location or quick test access |
| Pond/bridge shiny reflection palette | Shiny practice follower supplied; pond/bridge sites still not supplied | Verified reflection location/quick access |
| Seaweed finish-step bubbles, rising/expiry and cleanup | No known accessible seaweed location from current Azalea play | Verified location and quick access |
| Deep-sand cover, puddle/ripple/hot-spring effects and water landings | Suitable locations have not been established for the player | Verified location and quick access |
| Fog/water shadow suppression | Fog has not been encountered | Natural encounter or a controlled weather test |
| Terrain backgrounds restoring after expiry/removal | Not confirmed by this reply | A relevant encounter during normal play or a supplied test setup |

## Developer follow-up

The opt-in practice copy supplies a normal/shiny follower, TM kit and four verified terrain strips with return. Keep other terrain/weather/reflection checks deferred until their own quick access is supplied. Practice changes stay within the separate save slot. The documented native developer-console warp is Gen 1-only; it is not a verified Emerald shortcut.

Keep the GB mart arrangement and source percussion unchanged. Investigate the remaining difference in prominence at the playback/mixing/filtering/resampling boundary if audio work is resumed. Lower sample rate is a player hypothesis, not an established diagnosis.

Full reflection transition affine/blend parity, ash/weather effects, hidden acquisition and expanded battle/campaign work remain tracked in README and PROGRESS.md.

## Updating these notes

Refresh after each release and player reply. Remove confirmed checks from the active list, retain deferred/unresolved checks with their reason, and distinguish source behavior from port differences. Do not infer additional confirmations from a broader sentence. Keep README's permanent implementation checklist and the validation reports separate from player confirmations.
