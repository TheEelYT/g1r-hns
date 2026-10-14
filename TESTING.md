# Player testing notes — 0.7.14

Follower idle animation is confirmed working; its check is removed. The title/bubble, original flashing version, steady Mod version and battle-menu prompt animations are confirmed correct; their checks are removed. Earlier confirmed checks remain removed.

- [ ] Use GB SOUNDS from the Bag, then toggle it off. Listen during travel, a wild/trainer battle, healing and item receipt; check that the saved selection survives loading.
- [ ] Hold Down across Azalea's three ledges and keep moving afterward, both walking and running. Check that the follower lands and continues following without releasing Down or turning sideways.
- [ ] Watch follower walking/running poses, including transitions from idle and changes of direction or speed. Check their cadence against HnS.
- [ ] Check the compact Pokégear start-menu label against the supplied screenshot; listen for open/close sounds and selection sounds when moving between pages.
- [ ] Cross town/route borders in both directions. Check that a visible follower stays out, while building doors still recall/release it.
- [ ] If a terrain move becomes available in normal play, check its field background and restoration after expiry/removal.

Move effects and seed/Surge handlers rely on automated checks for now; there is no need to test every move or ability by hand. Source ability assignment/hidden slots and item acquisition remain unfinished. Report crashes or mismatches encountered in normal play; add a focused regression and manual check then.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
