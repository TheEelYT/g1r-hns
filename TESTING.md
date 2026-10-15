# Player testing notes — 0.7.17

Use G1R 0.3.88 for this update. Confirmed follower walking, capture jingles in both modes, restored GB instruments and visible shadows are removed. Previously confirmed idle, title/version and battle-prompt checks remain removed.

- [ ] Leave GB SOUNDS playing in Pokémart for several loops. Check the slight missing-note hitch at the loop seam is gone.
- [ ] Hold Down across Azalea's three ledges and keep moving afterward. Check that the follower lands and continues following without releasing Down or turning sideways.
- [ ] Check that the compact Pokégear label has the same ink/shadow color as its neighboring menu rows.
- [ ] Compare player and follower short-grass effects in Azalea at midday and night using Fake RTC. Both should use the same colors and receive outdoor darkening; check movement restarts and cleanup after leaving or recalling.
- [ ] Check an existing Pokémon's ability in its summary and after loading a save. Legendary Abilities should respond to its setting when the relevant species becomes available.
- [ ] Cross town/route borders in both directions. Check that a visible follower stays out, while building doors still recall/release it.
- [ ] If a terrain move becomes available, check its field background and restoration after expiry/removal.

Ability identities and reviewed move/seed/Surge effects rely on automated checks for now; there is no need to test every move or ability by hand. Hidden acquisition, many expanded ability effects, source popups, weather shadow rules and the full follower ground-effect set remain unfinished. Report crashes or mismatches encountered in normal play.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
