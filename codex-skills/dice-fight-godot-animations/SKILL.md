---
name: dice-fight-godot-animations
description: Create, repair, validate, and import Godot-ready Dice Fight character animation assets from portraits, concept art, or generated row strips. Use when Codex needs to make or update character select idle loops, battle idle, attack, skill cast, guard, hurt, victory, defeat, rebirth, or other 2D sprite animations for the Dice Fight Godot project, including spritesheets, transparent frame extraction, contact sheets, SpriteFrames .tres resources, and character JSON integration guidance.
---

# Dice Fight Godot Animations

## Overview

Build Dice Fight character animation assets with the same separation that makes `$hatch-pet` reliable: `$imagegen` creates visual row strips, local scripts do deterministic manifest, frame extraction, atlas, QA, and Godot resource work.

This skill is project-specific. It should respect `docs/GAME_DESIGN.md`, `docs/TECH_DESIGN.md`, and `AGENTS.md`: animation belongs to UI/presentation, while rules remain under `scripts/rules/` and network authority remains host-side.

## Workflow

1. Read the current character data and docs before changing assets.
   - Character JSON lives in `data/characters/`.
   - Character art lives under `assets/characters/<character_id>/`.
   - Existing `portrait_path` should stay as a safe fallback.
2. Choose a run shape.
   - Use `references/animation-spec.md` for default animation names, frame counts, loop flags, and prompt intent.
   - Default cell size is `128x128` for new combat sprites; use `96x96` for small character-select-only pixel sprites when it matches the UI.
3. Prepare a run folder and prompts:

```bash
python <skill-dir>/scripts/prepare_animation_run.py \
  --project-path /absolute/path/to/dice_fight_godot \
  --character-id swordsman \
  --display-name Swordsman \
  --reference /absolute/path/to/reference.png \
  --animations select_idle,battle_idle,attack,hurt,guard,victory,defeat \
  --cell-size 128x128
```

4. Generate row visuals with `$imagegen`.
   - Load and follow the installed `$imagegen` skill.
   - For each ready job in `imagegen-jobs.json`, use the exact prompt file plus every listed input image.
   - Treat original references and `references/layout-guides/<animation>.png` as grounding inputs.
   - Do not draw, tile, warp, or synthesize missing row art locally. Local scripts only process selected generated images.
   - For batches, use subagents when available for independent row generation; the parent must own manifests, recording, finalization, and project writes.
5. Record selected generated rows:

```bash
python <skill-dir>/scripts/record_row_result.py \
  --run-dir /absolute/path/to/run \
  --job-id attack \
  --source /absolute/path/to/generated_images/.../ig_0001.png
```

   Record rows sequentially. `record_row_result.py` updates the shared manifest, so do not run multiple record commands in parallel.

6. Finalize deterministic assets:

```bash
python <skill-dir>/scripts/finalize_animation_run.py \
  --run-dir /absolute/path/to/run \
  --project-path /absolute/path/to/dice_fight_godot \
  --install
```

7. Review before accepting.
   - Inspect `qa/contact-sheet.png`, `qa/review.json`, and `final/animation_manifest.json`.
   - Block acceptance when identity drifts, rows crop the character, feet baseline jumps, chroma key remains, frames overlap, or an animation no longer communicates its gameplay state.
   - Run the smallest relevant Godot validation after integrating assets.

## Godot Integration

Prefer `AnimatedSprite2D + SpriteFrames` for battle character views. Use `AnimationPlayer` only when sequencing sprite playback with movement, hit flash, sound, particles, or camera shake.

For character select UI, either:

- use the same `SpriteFrames` resource through a small `AnimatedSprite2D` component embedded in the card, or
- use a `TextureRect` atlas-frame component if the screen stays purely Control-based.

Keep animation paths data-driven and optional:

```json
"animation_sprite_frames_path": "res://assets/characters/swordsman/animations/swordsman_sprite_frames.tres",
"animation_manifest_path": "res://assets/characters/swordsman/animations/swordsman_animation_manifest.json"
```

If these fields are missing or fail to load, fall back to `portrait_path`.

Read `references/godot-integration.md` before editing project scenes or scripts.

## Visual Rules

- Preserve the character identity from the canonical reference: silhouette, palette, face, weapon, body proportions, handedness, and readable role.
- Use flat cel/pixel-adjacent game sprites unless the project art direction changes.
- Use a uniform chroma-key background in generated row strips; the final atlas should have alpha.
- Keep each frame centered inside its cell with a stable foot baseline.
- Do not add UI text, frame numbers, grids, watermarks, scenery, detached symbols, speed lines, motion blur, cast shadows, floor shadows, or soft glows unless the specific animation spec explicitly allows an attached gameplay effect.
- Use effect sprites as separate assets for large fire, poison, shield, or hit effects; do not bake large detached VFX into the character row.

## Repair

Regenerate the smallest failing scope. If only `hurt` has bad cropping, repair `hurt`; do not regenerate the full character. Use the canonical base/reference, failed row, contact sheet, and precise failure note as grounding context.

After repair, rerun `record_row_result.py` for the repaired job and rerun `finalize_animation_run.py`.

## Resources

- `scripts/prepare_animation_run.py`: create run manifests, prompts, and layout guides.
- `scripts/record_row_result.py`: copy selected `$imagegen` output into the run and record provenance.
- `scripts/finalize_animation_run.py`: extract transparent frames, compose atlas, create SpriteFrames `.tres`, QA contact sheet, and optional project install.
- `references/animation-spec.md`: default Dice Fight animation states and prompt intent.
- `references/godot-integration.md`: recommended Godot scene/data integration patterns.
