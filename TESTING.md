# Player testing notes — 0.7.5

These are suggested checks for the ongoing port testing, separate from the general installation guide and permanent progress checklist. The four changes below still need player confirmation.

- [ ] Launch from a closed game. Copyright should lead into the source POWERED BY / PRET × RHH credits, including Dizzy Egg and Porygon animation, then Game Freak and the HnS title. Any game button can skip the credits after their initial fade.
- [ ] In a grass encounter, select OLD and MODERN terrain separately. MODERN should show the source forest/grass backdrop instead of the generic striped building background. Repeat at morning, day, evening and night.
- [ ] Check the action menu, move menu and ordinary battle messages under both GEN 3 and GEN 4 UI. Source window borders, message origin/width, move names and PP/type panels should remain aligned. Check another user-selected window frame too.
- [ ] With Poké Balls in the bag, watch the R prompt slide in. Its full window and source ball icon should align; arrows appear while R is held and disappear on release. Hold R with a direction to cycle, then release without cycling to throw. Continue into the bag, moves and message states and check that the prompt slides away.

## Updating these notes

Refresh this file with every release, using the latest player feedback. Remove checks confirmed as working, add checks for new changes and unresolved bugs, and re-add a confirmed check only when its behavior changes or a regression is reported. Keep the list focused on the current update instead of carrying forward the full historical test list.

The permanent progress checklist stays in [README.md](README.md), with completed work struck through. Automated validation results and their limitations stay in `reports/`.
