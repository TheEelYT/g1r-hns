# Player testing notes — 0.7.10

Suggested checks for the current update. TM09 Bullet Seed pickup on Route 32 and teaching Bellsprout were confirmed working; that check is removed. Earlier confirmed Roost, capture, credits, terrain presentation and UI checks remain removed.

- [ ] Check `v2.0.6 · Mod v0.7.10` on the title: its outlines, block lettering and shading should match the original banner, with a clean centered line and normal palette fades.
- [ ] Enter FIGHT very quickly, choose a move immediately, back out, and throw a ball before the prompts finish entering. The R-ball and START-info prompts should always finish sliding off during the turn, without hanging until the next turn. Also check ordinary slower selection, message waits, target selection and both Gen 3/4 UI styles.
- [ ] When a terrain move becomes available, check its five-turn duration and core effect. Electric prevents grounded sleep; Misty prevents new grounded status/confusion; Psychic blocks opposing priority against grounded targets; Grassy heals grounded Pokémon at turn end. Terrain background replacement and dependent abilities/items remain pending.
- [ ] Outstanding: check newly taught expanded moves after saving/reloading, and draining/recoil/setup behavior as those moves become available. A pending-effect TM should give the explicit unavailable message.

## Updating these notes

Refresh with each release and the latest feedback. Remove confirmed checks, add new changes/unresolved bugs, and re-add a confirmed check only after a change or reported regression. The permanent checklist stays in [README.md](README.md), with completed work struck through; automated results stay in `reports/`.
