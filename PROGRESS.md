# Port progress — 0.7.23

**Approximately 42% complete / 58% remaining.**

Weighted feature-parity estimate. Editorial scope weights; partial defaults to half credit unless measured. Not binary matching, hours, or a schedule. Revise weights when new scope is found.

Weights describe total feature scope. Map imports and small fixes do not count equally with battle systems or the full campaign. This estimate does not predict engineering hours or a release date.

| Area | Scope weight | Estimated complete |
|---|---:|---:|
| World data and assets | 12% | 83.3% |
| Menus, presentation and audio | 12% | 79.2% |
| Field and followers | 10% | 50.0% |
| Battle and Pokémon systems | 25% | 41.0% |
| Modes and challenges | 12% | 20.6% |
| Campaign, services and progression | 24% | 10.4% |
| Release and final validation | 5% | 50.0% |

Measured bridge coverage (not a claim of complete behavior):

- Abilities: 81/311 (26.0%).
- Moves: 168/580 (29.0%).
- Settings: 26/88 (29.5%).

The source scope inventory and evidence paths are in [progress.json](progress.json). `done` earns full credit, `pending` zero and `partial` half unless a coverage counter is specified. Each item has an explicit share of its category. Settings include partial Modern Moves and Synchronize coverage; expanded moves exclude the original native rows.

## Inventory

### World data and assets

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Layouts, tilesets, connections and warps | 5 | done | [tests/check_world.py](tests/check_world.py) |
| Supported overworld sprites and source portraits | 3 | done | [opening.py](opening.py) |
| Source encounter pools and unsupported species | 1 | partial | [world_encounters.py](world_encounters.py) |
| Conditional objects and complete species/forms | 3 | partial | [field_pokemon.py](field_pokemon.py) |

### Menus, presentation and audio

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Source menu/boot/bag/Dex/Pokégear pages | 4 | done | [tests/check_presentation.py](tests/check_presentation.py) |
| Normal and GB music, instruments and jingles | 3 | done | [audio.py](audio.py) |
| Battle entry, frames and source animation orchestration | 2 | partial | [battle_assets.py](battle_assets.py) |
| Outdoor tint and light-bank immunity | 1 | partial | [runtime/time_cycle.lua](runtime/time_cycle.lua) |
| Cries, hardware arbitration and audible parity | 1 | partial | [gbs.py](gbs.py) |
| Remaining Dex/contacts pages and details | 1 | partial | [runtime/pokedex.lua](runtime/pokedex.lua) |

### Field and followers

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Walking, hops, doors and seamless following | 2 | done | [tests/test_follower_motion.lua](tests/test_follower_motion.lua) |
| Source trails, covers, bubbles and reflection palettes | 2 | done | [runtime/field_reflections.lua](runtime/field_reflections.lua) |
| Conditional dialogue, caught-ball/female variants | 2 | partial | [runtime/followers.lua](runtime/followers.lua) |
| Remaining weather, ash and map-specific effects | 3 | pending | [runtime/field_shadows.lua](runtime/field_shadows.lua) |
| Reflection affine and blending during ball transitions | 1 | pending | [runtime/field_reflections.lua](runtime/field_reflections.lua) |

### Battle and Pokémon systems

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Source stats, move parameters, type chart and EXP rules | 3 | done | [gameplay.py](gameplay.py) |
| Supported source ability effects | 5 | partial | [abilities.py](abilities.py) |
| Reviewed expanded move effects | 5 | partial | [expanded_moves.py](expanded_moves.py) |
| Machines, tutors, breeding and evolution | 3 | partial | [teaching.py](teaching.py) |
| Held items, acquisition and interactions | 3 | partial | [runtime/battle_fields.lua](runtime/battle_fields.lua) |
| Expanded species/forms and transformation systems | 3 | partial | [pokedex.py](pokedex.py) |
| Remaining complex field/turn-state behavior | 3 | pending | [runtime/gameplay.lua](runtime/gameplay.lua) |

### Modes and challenges

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Reviewed rule/feature setting bridges | 5 | partial | [runtime/gameplay.lua](runtime/gameplay.lua) |
| Saved Fake RTC and time pools | 1 | done | [runtime/time_cycle.lua](runtime/time_cycle.lua) |
| Deterministic saved randomization | 3 | pending | [settings.py](settings.py) |
| Nuzlocke and remaining challenge restrictions | 3 | pending | [settings.py](settings.py) |

### Campaign, services and progression

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Opening through Violet Gym and Sprout Tower | 2 | done | [campaign.py](campaign.py) |
| Source marts, healing, phone and services | 1 | partial | [service_assets.py](service_assets.py) |
| Remaining Johto events, puzzles, travel and rewards | 8 | pending | [campaign.py](campaign.py) |
| Kanto campaign events and progression | 5 | pending | [campaign.py](campaign.py) |
| Other regions and postgame events | 4 | pending | [campaign.py](campaign.py) |
| Remaining contacts, tutors and service unlocks | 2 | pending | [service_assets.py](service_assets.py) |
| FINAL: missing trainers, Cut trees and route/sequence-break audit | 2 | pending | [PORT_STATE.md](PORT_STATE.md) |

### Release and final validation

| Milestone | Weight | State | Evidence |
|---|---:|---|---|
| Pinned immutable packages, isolated cart and editable label | 2 | done | [tests/test_cart_label.py](tests/test_cart_label.py) |
| Automated native and independent source coverage | 1 | partial | [tests/test_native.lua](tests/test_native.lua) |
| Windows GPU, gameplay and listening validation | 1 | pending | [TESTING.md](TESTING.md) |
| Final full-source parity audit | 1 | pending | [PROGRESS.md](PROGRESS.md) |

Missing progression trainers, Cut trees and other travel blockers stay **last**, alongside the route-order and sequence-break audit. Testing travel remains open. Mod 1.0.0 remains reserved for full romhack parity.

Windows GPU rendering, gameplay and listening remain player checks. See [TESTING.md](TESTING.md).

Regenerate: `python3 progress.py --mod build/hns_exploration --engine build/engine --luajit /path/to/luajit` (add `--check` in CI).
