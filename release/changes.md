## Pokémon Heart & Soul — Mod 0.7.14

Use the `.g1rcart` download; it installs the pinned mod with isolated saves and mod edits disabled. Cart version is 1.0.13; Mod 1.0 is reserved for complete romhack parity.

- Fix followers repeatedly restarting the last ledge jump when Down remains held. Unfinished movement completes before the latest trailing step starts.
- Connect source faster ledge hops when the player resumes walking/running, and source walking/running pose timers with phase continuity.
- Replace the written-out Pokégear start-menu label with the source compound glyph and connect source ON/OFF/SELECT sound effects.
- Remove the confirmed idle-animation check from TESTING.md and add continuous-input and movement-cadence checks. Retain the README progress history.

Checks cover real imported Azalea ledges with held Down while walking/running, source jump/animation routines, both supported native engines and retained integration/audits. Live Windows movement/animation confirmation remains in TESTING.md. Other port limitations remain tracked in README.
