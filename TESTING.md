# Player testing notes — 0.7.18

Use G1R 0.3.88. Confirmed follower hops/landing dust, Pokégear label shade and both-direction outdoor border following are removed. Walking, capture jingles, instruments, visible shadows and earlier title/UI checks remain removed. Ability identity checks rely on automation unless normal play exposes a mismatch.

- [ ] Listen to the GB Pokémart loop seam. Its final silent gap is now one sixteenth-note unit longer; the last notes and intro are unchanged. Check whether the pause now matches the romhack.
- [ ] Compare the tonal percussion hit with the romhack in GB mode. The source mart drum 6 requests pitched 7-bit noise (NR43=0x2A); its source setting is retained. If a different track is affected, record its location and roughly where the hit occurs. Audible/analog PSG parity remains open.
- [ ] Compare player and follower **short grass in Azalea**, at midday and night. Shadows now draw behind grass even during the follower's idle bob; the leaf colors should match. Tall grass is unchanged.
- [ ] When encountered naturally, check that diagonal fog/underwater bubbles hide object shadows and a step from water onto shore does not leave a stray shadow. Ordinary rain/horizontal fog and dry ground retain them.
- [ ] If a terrain move becomes available, check its field background and restoration after expiry/removal.

There is no need to test every move or ability by hand. Hidden acquisition, many expanded ability effects, source popups, remaining weather rules and the full follower ground-effect set remain unfinished. Report crashes or mismatches encountered in normal play.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
