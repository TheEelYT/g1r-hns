# Player testing notes — 0.7.12

The flashing original `v2.0.6` and steady Mod version are confirmed correct; their check is removed. Battle-menu prompt animations and earlier confirmed UI/gameplay checks remain removed.

- [ ] Check the HEART & SOUL bubble fits the notch under the Pokémon logo after its eight-pixel upward correction.
- [ ] If a terrain move becomes available in normal play, check its field background and restoration after expiry/removal.

Move effects and the new seed/Surge handlers rely on automated checks for now; there is no need to test every move or ability by hand. Source ability assignment/hidden slots and item acquisition are not completed by importing identities or handlers. Report crashes or mismatches encountered in normal play; add a focused regression and manual check then.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
