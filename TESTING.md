# Player testing notes — 0.7.9

Suggested checks for the current update; confirmed checks are removed. Roost, credits, capture naming, Modern terrain, followers and Gen 3/4 battle UI were already reported as working.

- [ ] Check the title footer reads `v2.0.6 · Mod v0.7.9`, below PRESS START, and fades with the title.
- [ ] Check a newly restored TM item ball (for example TM54 in Ilex Forest or TM60 on Route 39). It should grant once, remain if the bag is full, and stay collected after saving/reloading.
- [ ] When you obtain a new machine, check its number, description and colored disc in the TM pocket. Teach a compatible Pokémon, decline replacement on a full move list, and check inventory/moves after reloading. Pending effects such as Fling should give a clear unavailable message.
- [ ] As moves become available, check draining/recoil and setup moves such as Quiver Dance, Coil or Shell Smash in an actual battle. Confirm START details and PP; report incorrect animations separately, since distinct expanded move animations remain pending.

## Updating these notes

Refresh this file with every release using the latest feedback. Remove confirmed checks, add new changes/unresolved bugs, and re-add a confirmed check only after a change or reported regression. The permanent progress checklist stays in [README.md](README.md), with completed work struck through; automated results stay in `reports/`.
