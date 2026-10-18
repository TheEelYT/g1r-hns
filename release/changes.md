## Pokémon Heart & Soul — Mod 0.7.19

Use the `.g1rcart` download for isolated saves and disabled mod edits. Cart version is 1.0.18. Mod 1.0 remains reserved for complete romhack parity. This release targets G1R 0.3.89.

- Restore the confirmed 0.7.17 GB Pokémart loop by removing only 0.7.18's extra 1/16-note rest. Keep the source MIDI-grid correction, intro exclusion, note lengths and fractional timing. The converted mart assembly matches 0.7.17 byte for byte.
- Import species-owned follower track types, directional footprints, spot/bug trails and turning slither tracks, with source palettes, frame flips and track flicker/expiry.
- Add deep-sand foot cover, owner-bound puddle splashes/ripples, looping shallow-water effects, hot-spring overlays and water-landing splash selection. Recall removes attached effects while detached trails expire; map changes clear old effects.
- Retain all 0.7.18 short-grass/shadow-order and fog/shoreline shadow fixes. Walking/running, hops/dust and seamless outdoor border following remain covered by regressions.
- Update the README progress checklist and separate TESTING.md; remove the confirmed mart-loop check.

Native tests cover actual follower movement/recall, all source track families, directional flips, every track lifetime tick and sand/water transitions. Independent audits compare imported pixels and compiled source animation commands/track-fade callbacks, alongside existing world/gameplay/UI/audio source checks. Raw and installer-compressed assets use the latest G1R. Real GPU/audio listening remains a player check; reflections, seaweed/ash, further field/weather effects, expanded battle rules and later campaign remain unfinished. Source percussion is unchanged.
