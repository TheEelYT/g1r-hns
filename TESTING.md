# Player testing notes — 0.7.22

Use G1R 0.3.96. These notes are the normal place to reply after an update; report any other bug you notice too. Checks must fit the player's current location and available Pokémon. An inaccessible check is deferred, not a failure and not a confirmation.

## Current player checks

Optional checks now have a separate practice save. Nothing needs to be tested in your regular Azalea save.

1. **Save on dry ground, off your bike.** Open **START → OPTIONS → GEN1RECOMP → PORT TEST TOOLS → Create practice copy → YES**. This copies your last SAVED point. It does not include unsaved changes or select the new slot.
2. Exit to the launcher. Choose the new **HnS PRACTICE** save slot and Continue. Your regular slot is still available with its original name/party/bag.
3. The test party contains **NORMAL** and **SHINY** Poliwrath, level 25. The Bag has **9 each TM03 Water Pulse, TM17 Protect and TM60 Drain Punch**. NORMAL has one move for immediate learning. SHINY has four to try replacement/cancellation. **Refill TM supplies** restores the three stacks to 9 in this copy only.
4. Optional TM check: with **Infinite TMs ON**, teach a supplied TM and check it stays at 9. With it OFF, a successful teaching uses one. Changing this requires Custom mode on the source Mode page. Declining replacement should consume none. Use a fresh practice copy if both learners already know the move. No search for another TM is needed.
5. Optional field check: the practice tools offer **Terrain shortcuts** for sand, short grass, shallow water and ice. Walk **LEFT and RIGHT** across the arrival strip. **Swap first two followers** selects the supplied normal/shiny lead. Ice Path has an icy reflection field; ice may slide you until you reach an edge. **Return to copied point** returns within the practice save.
6. When finished, exit to the launcher and select your regular save slot again. Test changes may be saved in HnS PRACTICE; they stay in that slot. Deleting the practice slot later is optional.

Please report if creating/selecting the practice copy, the TM counts, a shortcut/return, or one of the supplied terrain effects misbehaves. Synchronize/Cute Charm remain covered by automated checks; no bulk encounter sampling is requested.

Seaweed, bridge/pond reflection test sites, deep sand, puddles and controlled fog are **not supplied yet**. These checks stay deferred. Ice Path supplies an icy reflection field for the normal/shiny presets; pond/bridge sites are still not supplied. No backtracking or shiny hunt is requested.

## Feedback received for 0.7.20

- **Azalea short grass: confirmed correct for both player and follower.** Remove this from active checks. The reply did not separately establish every time-of-day case.
- **Normal follower pond reflections: confirmed working as intended.** Ice/shiny ice checks now have optional practice access; bridge and shiny pond checks remain deferred.
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
| Species-owned sand/footprint trails, turning, hold/flicker/expiry (now accessible, still unconfirmed) | Previously inaccessible; sand shortcut now supplied in practice copy | Optional practice feedback only; no walk back requested |
| Deep-sand cover, puddle/ripple/hot-spring effects and water landings | Suitable locations have not been established for the player | Verified location and quick access |
| Fog/water shadow suppression | Fog has not been encountered | Natural encounter or a controlled weather test |
| Terrain backgrounds restoring after expiry/removal | Not confirmed by this reply | A relevant encounter during normal play or a supplied test setup |

## Developer follow-up

The opt-in practice copy supplies a normal/shiny follower, TM kit and four verified terrain strips with return. Keep other terrain/weather/reflection checks deferred until their own quick access is supplied. Practice changes stay within the separate save slot. The documented native developer-console warp is Gen 1-only; it is not a verified Emerald shortcut.

Keep the GB mart arrangement and source percussion unchanged. Investigate the remaining difference in prominence at the playback/mixing/filtering/resampling boundary if audio work is resumed. Lower sample rate is a player hypothesis, not an established diagnosis.

Full reflection transition affine/blend parity, ash/weather effects, hidden acquisition and expanded battle/campaign work remain tracked in README and PROGRESS.md.

## Updating these notes

Refresh after each release and player reply. Remove confirmed checks from the active list, retain deferred/unresolved checks with their reason, and distinguish source behavior from port differences. Do not infer additional confirmations from a broader sentence. Keep README's permanent implementation checklist and the validation reports separate from player confirmations.
