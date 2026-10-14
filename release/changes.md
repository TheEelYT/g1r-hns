## Pokémon Heart & Soul — Mod 0.7.13

Use the `.g1rcart` download; it installs the pinned mod with isolated saves and mod edits disabled. Cart version is 1.0.12; Mod 1.0 is reserved for complete romhack parity.

- GB SOUNDS now toggles source Game Boy music and fanfares, including travel, battles and healing, with the choice saved. The source bytecode sequencer retains fractional timing and continuous loops; it uses the native PSG mixer.
- Followers idle with source poses/bobbing and move on each consecutive ledge hop. Outdoor town/route crossings preserve the follower instead of releasing it again; building doors retain their ball transitions.
- The confirmed title check is removed from the separate TESTING.md; new checks cover GB playback and the reported follower issues. README progress retains completed items with strikethrough.

Automated validation uses both supported native engines, source C GB timing/register comparisons, actual Azalea ledge collision, native audio/UI paths and retained audits. Audible PSG fidelity, GB cry remaps/SFX arbitration and remaining source ability assignment/effects are still pending.
