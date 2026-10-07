Changes in 0.7.8:

- Imports all 935 configured HnS move rows into a shared source table, preserving source IDs, names/descriptions, parameters, targets and every original field expression, including effect arguments, flags and animation references. Existing port IDs remain stable.
- Moves Roost into the shared reviewed HnS move lookup, fixes selection without an Emerald ROM row, and supplies its source START details. Healing and temporary Flying removal retain the existing reviewed handler.
- Keeps all 420 pending move effects explicit and excluded from learned move lists; data import does not claim to implement them.
- Removes player-confirmed boot/credits, caught naming, Modern terrain and GEN 3/4 battle UI checks from TESTING.md.

Both G1R 0.3.44 and 0.3.53 remain supported. Tests remove the nonexistent Roost ROM row, exercise move selection/details/healing and compare the complete imported data against source. Live Windows/GPU confirmation remains a player check.
