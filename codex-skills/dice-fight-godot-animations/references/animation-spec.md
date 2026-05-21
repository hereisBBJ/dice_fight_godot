# Dice Fight Animation Spec

Use this file when choosing rows, frame counts, loop flags, and prompt intent.

## Defaults

| Animation | Frames | FPS | Loop | Purpose |
| --- | ---: | ---: | --- | --- |
| `select_idle` | 8 | 6 | yes | Character select loop with subtle personality motion. |
| `battle_idle` | 6 | 6 | yes | Combat-ready breathing loop. |
| `attack` | 6 | 10 | no | Primary weapon or basic attack anticipation, strike, recover. |
| `skill_cast` | 8 | 10 | no | Larger class-specific skill action without detached VFX. |
| `guard` | 4 | 8 | no | Defensive brace, block, shield, or ward pose. |
| `hurt` | 4 | 8 | no | Short hit reaction. |
| `victory` | 6 | 6 | yes | Game-over winner loop. |
| `defeat` | 6 | 6 | no | Loss/downed pose; end on readable defeated frame. |
| `rebirth` | 8 | 10 | no | Pyromancer-specific rebirth motion. |

Use only the animations needed for the task. For a first pass, `select_idle`, `battle_idle`, `attack`, `hurt`, `guard`, `victory`, and `defeat` are usually enough.

## Prompt Intent

- `select_idle`: gentle visible motion, hair/tunic/weapon sway, small forward-back body rock.
- `battle_idle`: calmer, combat-ready breathing; weapon remains readable and stable.
- `attack`: anticipation, attack peak, recovery. Do not include target, damage numbers, or detached slashes.
- `skill_cast`: class flavor in body pose and held prop. Put large fire, poison, shield, arrow, or spell VFX in separate effect assets.
- `guard`: defensive stance, weapon or body protects torso; no floating shield icon.
- `hurt`: compact recoil, blink or grimace, no blood or gore.
- `victory`: confident but small celebratory loop; no text or trophy prop unless it is part of the character identity.
- `defeat`: readable loss pose, not grotesque, final frame stable.
- `rebirth`: character-contained flame recovery for Pyromancer; attached hard-edged flame is allowed, but no large detached aura.

## Geometry

Recommended cell sizes:

- `96x96`: small character-select sprites and compact pixel-art previews.
- `128x128`: default combat character sprites for the current UI scale.
- `192x192`: larger future battle presentation, only if UI layout is updated.

Every row strip should be one horizontal row with exactly `frame_count` implied equal cells. The generated source may be larger than the final atlas, but the subject must fit each cell with generous padding and a stable baseline.

## Acceptance

Accept a row only when:

- the character remains the same person in every frame,
- the frame count is visually clear,
- the body and weapon never cross into the neighboring frame slot,
- feet or grounding baseline do not jitter except intentionally for jump-like motions,
- background is flat and removable,
- no guide marks, labels, grids, or watermarks are visible.
