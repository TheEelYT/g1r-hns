# Player testing notes — 0.7.20

Use G1R 0.3.95. The GB mart loop from 0.7.17 is player-confirmed; 0.7.18's extra 1/16-note rest is removed. That loop check is no longer pending. Confirmed hops/dust, walking/running, label shade, outdoor border following, capture jingles and earlier title/UI checks remain removed.

- [ ] Compare normal/shiny follower reflections on ponds, ice and bridges, including idle, walking and asymmetric right-facing poses. Full ball-transition affine/blend parity remains pending.
- [ ] In seaweed, check bubbles appear after completed follower steps, rise and expire independently, and clear on map changes.
- [ ] When crossing sand/footprint terrain, check that followers leave species-specific trails. Footprints should face the direction of travel, slither trails should turn, and marks should hold briefly before flickering away. Species configured without tracks should leave none.
- [ ] In deep sand, puddles, shallow water or hot springs, check that effects follow the follower's feet, clean up when it leaves/recalls, and do not change walking or hop timing. Ordinary ground landing dust is retained.
- [ ] Compare player and follower **short grass in Azalea**, at midday and night. The 0.7.18 shadow-order correction is retained; tall grass is unchanged.
- [ ] When encountered naturally, check source fog/water shadow suppression and terrain backgrounds restoring after expiry/removal.
- [ ] Compare the reported tonal percussion with the romhack in GB mode. The source mart drum 6 requests pitched 7-bit noise (NR43=0x2A); it is unchanged. If another track is affected, note its location and roughly where the hit occurs.

There is no need to test every move or ability by hand. Hidden acquisition, many expanded ability effects, source popups, full reflection transitions, ash effects, further field/weather rules and later campaign remain unfinished. Report mismatches encountered in normal play.

## Updating these notes

Refresh with each release and feedback. Remove confirmed checks, retain unresolved ones, and keep the permanent progress checklist in README with completed entries struck through. Automated evidence stays in `reports/`.
