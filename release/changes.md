## Pokémon Heart & Soul — Mod 0.7.17

Use the `.g1rcart` download; it installs the pinned mod with isolated saves and mod edits disabled. Cart version is 1.0.16; Mod 1.0 is reserved for complete romhack parity. This release targets the latest G1R 0.3.87.

- Restore one missing final rest unit in every GB Pokémart channel. The 32-unit intro and two 448-unit bodies now finish at 928 units; loop timing retains fractional carry instead of drifting off the source MIDI's whole-bar grid.
- Supply the native player short-grass controller with the follower's source image/palette and animation commands. Both draw through the common outdoor time tint; this source palette is not blend-immune. Native movement restarts and cleanup are retained, and vanilla sessions keep their original assets.
- Remove confirmed follower walking and capture-jingle checks from TESTING.md. Keep the mart seam and player/follower day/night grass comparison for live feedback.
- Refresh README progress and pin all validation/builds to G1R 0.3.87.

Validation covers native integration under both cache roots, raw and installer-compressed assets, converter tests, strict Modkit validation, seven source audits and CPU UI captures. GB repeats are checked on exact expected MIDI-grid frames; real field draws confirm player/follower grass use the same texture and canvas at midday/night, with one common night tint. GPU uploads/shaders use a recorded boundary; Windows visual/audio confirmation remains in TESTING.md. Remaining expanded effects and later campaign are still in progress.
