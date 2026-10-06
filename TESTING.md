# Player testing notes — 0.7.7

These are suggested checks for the ongoing port testing, separate from the general installation guide and permanent progress checklist. These checks cover the current fixes and outstanding visual confirmation.

- [ ] On G1R 0.3.53, import the updated cart and restart. Check that booting succeeds, then visit an interior and start a battle to verify the decoded maps, NPCs and battle graphics. Existing HnS saves should remain available.
- [ ] Catch a new species on G1R 0.3.53. After its Pokédex entry, the Pokémon should return to the battle center and the nickname Yes/No prompt should open; try both naming and declining.
- [ ] Launch from a closed game. Copyright should lead into the source POWERED BY / PRET × RHH credits, including Dizzy Egg and Porygon animation, then Game Freak and the HnS title. Any game button can skip the credits after their initial fade.
- [ ] Watch a MODERN grass encounter open, with FAST INTRO set to OFF. The trees/backdrop should scroll as complete source layers without isolated blocks jumping or leaving bands. Check another Modern environment if available, and compare day and night.
- [ ] Check the opponent name and level during the opening message and action menu in both GEN 3 and GEN 4 UI. The filled text region should end at the source border, without a block extending beyond the HP gauge. In GEN 4, its light gray color should match the source name/level strip, with the darker HP-number background preserved.
- [ ] Check the action menu, move menu and ordinary battle messages under both GEN 3 and GEN 4 UI. Source window borders, message origin/width, move names and PP/type panels should remain aligned. Check another user-selected window frame too.

## Updating these notes

Refresh this file with every release, using the latest player feedback. Remove checks confirmed as working, add checks for new changes and unresolved bugs, and re-add a confirmed check only when its behavior changes or a regression is reported. Keep the list focused on the current update instead of carrying forward the full historical test list.

The permanent progress checklist stays in [README.md](README.md), with completed work struck through. Automated validation results and their limitations stay in `reports/`.
