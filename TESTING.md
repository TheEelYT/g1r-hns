# Player testing notes — 0.7.8

These are suggested checks for the ongoing port testing, separate from the general installation guide and permanent progress checklist. These checks cover the current fixes and outstanding visual confirmation.

- [ ] With a Pokémon that already learned TM51 Roost, highlight Roost in battle under GEN 3 and GEN 4 UI, open START details, and switch to another move. Roost should show FLYING/status, 5 PP and the source healing description without crashing.
- [ ] Use Roost when damaged. It should restore half maximum HP and remove Flying typing only for that turn; at full HP it should fail without changing typing. Save/reload should retain the same Roost move and PP.

## Updating these notes

Refresh this file with every release, using the latest player feedback. Remove checks confirmed as working, add checks for new changes and unresolved bugs, and re-add a confirmed check only when its behavior changes or a regression is reported. Keep the list focused on the current update instead of carrying forward the full historical test list.

The permanent progress checklist stays in [README.md](README.md), with completed work struck through. Automated validation results and their limitations stay in `reports/`.
