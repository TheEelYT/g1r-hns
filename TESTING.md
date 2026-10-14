# Player testing notes — 0.7.11

Battle-menu prompt animations are confirmed working; their manual check is removed. Earlier confirmed TM09/Bellsprout, Roost, capture, credits, ordinary arena backgrounds and Gen 3/4 UI checks remain removed.

- [ ] Check that the original `v2.0.6` flashes with PRESS START while the separate Mod version stays visible in the lower-right corner, with single periods and matching source lettering.
- [ ] If a terrain move becomes available in normal play, check its background appears and the map/arena background returns after terrain expires or is removed. No need to test every move by hand.

Individual move effects, terrain rules, spread targeting, priority and removal are accepted provisionally when their automated checks pass. Report a crash or behavior mismatch encountered during normal play; add a focused regression and manual check then. Save/reload and teaching are covered by the native automated suite as well.

## Updating these notes

Refresh with each release and the latest feedback. Remove confirmed checks, add new changes/unresolved bugs, and re-add a confirmed check only after a change or reported regression. The permanent checklist stays in [README.md](README.md), with completed work struck through; automated results stay in `reports/`.
