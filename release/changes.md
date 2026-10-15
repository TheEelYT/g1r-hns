## Pokémon Heart & Soul — Mod 0.7.18

Use the `.g1rcart` download; it installs the pinned mod with isolated saves and mod edits disabled. Cart version is 1.0.17; Mod 1.0 is reserved for complete romhack parity. This release targets the latest G1R 0.3.88.

- Fix the follower shadow being drawn over Azalea short-grass leaves during idle bobbing. Ground shadows now stay behind their owner and grass across camera rows/elevations and scripted priorities. Source leaf colors and outdoor tint are retained.
- Extend the GB Pokémart's final silent gap by one sixteenth-note unit, separately tracked from the existing MIDI-grid repair. All four channels stay synchronized; note lengths, intro exclusion and fractional timing are preserved. This listening adjustment still needs comparison with the romhack.
- Import source shadow priority tables, diagonal-fog/underwater-bubble suppression and the complete source grass/water behavior sets, including previous-water suppression when reaching shore.
- Audit the mart percussion: source drum 6 explicitly requests 7-bit noise (NR43=0x2A). Keep that source sound; the reported tonal difference remains open for audible comparison.
- Update README progress and TESTING.md, removing confirmed hop/dust, label-shade, ability-summary and border-following suggestions.

Validation covers native integration under both cache roots, raw and installer-compressed assets, converter tests, strict Modkit validation, seven source audits and CPU UI captures. Shadow tests exercise all camera-row offsets/elevations/idle heights, an overlapping source leaf/shadow pixel and weather/water transitions. Source predicates are compiled independently for 243 behavior rows. The GB test measures the all-channel silent seam over multiple loops and checks source noise registers/clock. GPU uploads/shaders use recorded boundaries; Windows visual/audio confirmation remains in TESTING.md. Expanded effects and later campaign remain in progress.
