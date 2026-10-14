Changes in 0.7.11:

- Restores original source `v2.0.6` flashing with PRESS START; the separate manifest-derived Mod version stays visible in the lower-right corner. Fixes the custom zero glyph including its neighboring period.
- Imports Electric, Grassy, Misty and Psychic field backgrounds with source configuration. They replace the arena background while terrain is active and restore it after expiry/removal, on both Gen 3/4 UI and old/Modern arenas.
- Adds Terrain Pulse, Rising Voltage, Expanding Force, Misty Explosion, Psyblade, Grassy Glide, Steel Roller and Ice Spinner. Source ground checks/rounding, type changes, double-battle targeting, Damp/self-faint behavior, priority and successful-hit terrain removal use native battle paths.
- Excludes Z/Max move rows until their transformation mechanics are ported, correcting 26 previously eligible special-form rows. The full 935-row source table remains retained: 354 native bridges, 168 reviewed custom moves and 412 pending effects, plus the empty row.
- Reserves Mod 1.0.0 for complete romhack parity. Development releases remain 0.x patch iterations, independently of cart packaging versions.
- Removes player-confirmed prompt-animation checks. Individual move checks remain automated unless normal play reveals a crash or mismatch.

Terrain-triggered abilities/seeds, item acquisition, remaining field/weather effects and full enhanced battle/campaign parity are still pending. Live Windows presentation remains a player check.
