## Pokémon Heart & Soul — Mod 0.7.16

Use the `.g1rcart` download; it installs the pinned mod with isolated saves and mod edits disabled. Cart version is 1.0.15; Mod 1.0 is reserved for complete romhack parity. This release targets G1R 0.3.86.

- Move the GB Pokémart repeat point past its one-time intro, using the HnS HG MIDI loop marker and restoring octave/envelope state at the loop entry.
- Match follower walking bob timing to the source callback and prevent the brief walking gap from entering idle animation. Confirmed running timing is retained.
- Add the source short-grass overlay for followers, including Azalea's actual tiles, attached positioning, movement restarts and cleanup.
- Correct the current native Emerald capture cue mapping: HnS HG_EVOLVED at ball frame 95, then HG_CAUGHT after its wait, in both normal and GB modes.
- Refresh README progress and TESTING.md; remove confirmed instrument and shadow checks.

Validation passes 119,494 native checks under both cache roots, raw and installer-compressed assets, 19 converter tests, strict Modkit validation, seven source audits and 121 CPU UI captures. The compiled source GB oracle covers 233,238 frames, including 20,000 mart frames through multiple repeats; the walking-bob callback matches 128 source frames. Windows visual/audio confirmation remains in TESTING.md. Remaining expanded effects and later campaign are still in progress.
