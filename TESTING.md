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


## Dashboard import format — maintainer instructions

Keep the single fenced `test-dashboard` JSON block below in sync with the current
player-check scope above. The schema is version 1, documented in
[Projects Dashboard](https://github.com/TheEelYT/projects-dashboard-site/blob/main/docs/TESTING-FORMAT.md).

Instructions for future maintainers and assistants:
- Preserve the project ID. Keep version and check IDs stable while editing the same
  update, so reimport preserves recorded results and notes.
- When a new release requires fresh checks, assign a new version ID and update its
  name, title, runtime, description, date and affected check definitions together.
  Do not carry a previous pass forward as confirmation of a new implementation.
- Keep ordinary testing instructions, acceptance history, limits and access
  prerequisites in the prose above. Update the JSON steps, expected result and
  context when those instructions change.
- The block contains definitions only: no checkbox statuses, player results,
  private notes, tokens or generated game data. Record results in the dashboard.
  New imported checks start untested; inaccessible checks need an explicit
  blocked result and reason.
- Checking a box must never commit this file. Export a report and review it before
  deliberately publishing feedback to GitHub. Definition edits are ordinary
  reviewed project changes.
- The dashboard currently imports a local file explicitly; it does not poll GitHub.
  Pull the repo while online before importing if the latest definitions are needed.
  Offline testing uses the last imported snapshot.
- Validate strict JSON (no comments/trailing commas), unique check IDs, and the
  dashboard import preview before accepting a format change. Keep exactly one
  `test-dashboard` block. Use the dashboard's Export check definitions action
  or its template when adding a project or changing the format.

```test-dashboard
{
  "schemaVersion": 1,
  "project": {
    "id": "hns",
    "name": "g1r-hns",
    "subtitle": "Pokémon Heart and Soul · Gen1Recomp",
    "repo": "https://github.com/TheEelYT/g1r-hns",
    "metric": "42%",
    "metricNote": "Weighted feature-parity estimate; not release readiness."
  },
  "version": {
    "id": "v0723",
    "name": "v0.7.23",
    "title": "TM flow, shadows & ice followers",
    "runtime": "0.3.96",
    "cart": "1.0.22",
    "createdAt": "2026-10-24",
    "description": "Three reported bugs are repaired in this update and await player confirmation. Use the separate HnS PRACTICE slot for optional checks."
  },
  "checks": [
    {
      "id": "TM-001",
      "title": "Four-move TM replacement",
      "area": "Battle & moves",
      "required": true,
      "priority": "high",
      "steps": [
        "Open HnS PRACTICE and use a supplied TM on SHINY, which has four moves.",
        "Press A through the already-four-moves message. Choose to replace a move.",
        "Select an ordinary move in the summary, then confirm the new move is taught.",
        "Try declining or cancelling; check that moves and TM count stay unchanged."
      ],
      "expected": "Offer deletion/replacement, open the move-selection summary and teach the selected move. Cancelling preserves moves and the TM.",
      "context": "Reported in v0.7.22: teaching cancelled after the four-moves message. Fixed in v0.7.23; player retest pending. Infinite TM consumption needs no repeat test."
    },
    {
      "id": "VIS-001",
      "title": "Sprite shadows stay behind sprites",
      "area": "Field & followers",
      "required": true,
      "priority": "high",
      "steps": [
        "Walk north with the follower behind the player.",
        "Watch shadows as player and follower overlap and the camera moves.",
        "Observe ordinary nearby NPCs if convenient."
      ],
      "expected": "Each shadow remains behind its owning sprite, including northward movement with a trailing follower.",
      "context": "Reported in v0.7.22: shadows draw over sprites. v0.7.23 repairs draw order; player confirmation is still needed."
    },
    {
      "id": "FLW-001",
      "title": "Follower stays out while sliding on ice",
      "area": "Field & followers",
      "required": true,
      "priority": "high",
      "steps": [
        "In HnS PRACTICE, open START → OPTIONS → GEN1RECOMP → PORT TEST TOOLS.",
        "Use the Ice shortcut and move left and right.",
        "Let the follower finish its trailing step after each slide."
      ],
      "expected": "The follower stays out, slides along and finishes the step without recalling into a Poké Ball.",
      "context": "Reported in v0.7.22: the follower enters its Poké Ball while moving on ice. Repaired in v0.7.23; live retest pending."
    },
    {
      "id": "REF-001",
      "title": "Normal & shiny ice reflections",
      "area": "Reflections",
      "required": false,
      "priority": "normal",
      "steps": [
        "First verify follower ice movement (FLW-001).",
        "At the Ice shortcut, observe normal and shiny practice followers."
      ],
      "expected": "Both reflection palettes and positions look correct while moving and stopping on ice.",
      "context": "Blocked by FLW-001 until movement is confirmed. Live ice and shiny ice appearance remains unconfirmed."
    },
    {
      "id": "REF-002",
      "title": "Bridge follower reflections",
      "area": "Reflections",
      "required": false,
      "priority": "normal",
      "steps": [
        "Use a verified nearby bridge reflection location or supplied quick access.",
        "Observe the follower and reflection as they move and stop."
      ],
      "expected": "Bridge follower reflections remain aligned and visually correct.",
      "context": "Deferred: no verified nearby location or quick access is supplied. No special trip or backtracking is requested."
    },
    {
      "id": "REF-003",
      "title": "Shiny pond / bridge reflection palette",
      "area": "Reflections",
      "required": false,
      "priority": "normal",
      "steps": [
        "Use a shiny practice follower at a verified pond or bridge reflection location.",
        "Compare reflection palette and placement while moving and stopping."
      ],
      "expected": "Reflection uses the appropriate shiny palette and stays aligned.",
      "context": "Deferred: shiny practice follower is supplied; verified pond/bridge test access is still needed."
    },
    {
      "id": "FX-001",
      "title": "Seaweed bubbles & cleanup",
      "area": "Terrain effects",
      "required": false,
      "priority": "normal",
      "steps": [
        "At a verified seaweed location, let a step finish.",
        "Observe bubble rise, expiry and cleanup after leaving."
      ],
      "expected": "Finish-step bubbles rise, expire and clean up correctly.",
      "context": "Deferred: no known accessible seaweed location from Azalea. Needs a verified location and quick access."
    },
    {
      "id": "FX-002",
      "title": "Deep sand, ripples & water landings",
      "area": "Terrain effects",
      "required": false,
      "priority": "normal",
      "steps": [
        "Use supplied access to deep sand, puddles, hot springs and water landings when available.",
        "Observe cover, ripple and landing effects and their cleanup."
      ],
      "expected": "Each relevant terrain effect matches its surface and clears correctly.",
      "context": "Deferred: suitable accessible locations have not been established. No terrain hunt is requested."
    },
    {
      "id": "VIS-002",
      "title": "Fog / water shadow suppression",
      "area": "Field & followers",
      "required": false,
      "priority": "normal",
      "steps": [
        "Observe a natural fog encounter or use a supplied controlled weather test.",
        "Check shadow suppression in fog and on relevant water surfaces."
      ],
      "expected": "Shadows suppress appropriately for the weather and surface.",
      "context": "Deferred: fog has not been encountered. Needs natural access or a controlled weather setup."
    },
    {
      "id": "BTL-001",
      "title": "Terrain backgrounds restore after expiry",
      "area": "Battle & moves",
      "required": false,
      "priority": "normal",
      "steps": [
        "Use a relevant encounter during normal play or a supplied test setup.",
        "Apply a terrain effect, then let it expire or remove it."
      ],
      "expected": "The battle background restores after terrain expiry or removal.",
      "context": "Deferred: no relevant encounter/setup has been confirmed."
    }
  ]
}
```
