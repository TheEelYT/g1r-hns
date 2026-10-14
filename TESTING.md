# Player testing notes — 0.7.13

The title/bubble, original flashing version, steady Mod version and battle-menu prompt animations are confirmed correct; their checks are removed. Earlier confirmed checks remain removed.

- [ ] Use GB SOUNDS from the Bag, then toggle it off. Listen during travel, a wild/trainer battle, healing and item receipt; check that the saved selection survives loading.
- [ ] Leave a follower idle facing different directions; check its two poses and subtle bobbing.
- [ ] Hop Azalea's three ledges consecutively. Check that the follower advances on each hop without waiting for another walking input.
- [ ] Cross town/route borders in both directions. Check that a visible follower stays out, while building doors still recall/release it.
- [ ] If a terrain move becomes available in normal play, check its field background and restoration after expiry/removal.

Move effects and seed/Surge handlers rely on automated checks for now; there is no need to test every move or ability by hand. Source ability assignment/hidden slots and item acquisition remain unfinished. Report crashes or mismatches encountered in normal play; add a focused regression and manual check then.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
