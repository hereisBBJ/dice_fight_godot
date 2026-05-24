# Godot Integration

Use this reference when importing finalized animation assets into Dice Fight.

## Asset Layout

Install generated assets under:

```text
assets/characters/<character_id>/animations/
  <character_id>_animations.png
  <character_id>_sprite_frames.tres
  <character_id>_animation_manifest.json
```

Keep the existing `portrait_path` unchanged unless the user explicitly asks to replace the portrait.

Add optional fields to `data/characters/<character_id>.json` only when project code is ready to consume them:

```json
"animation_sprite_frames_path": "res://assets/characters/swordsman/animations/swordsman_sprite_frames.tres",
"animation_manifest_path": "res://assets/characters/swordsman/animations/swordsman_animation_manifest.json"
```

## Battle Character View

Recommended scene shape:

```text
CharacterView (Node2D or Control adapter)
  AnimatedSprite2D
  AnimationPlayer
  AudioStreamPlayer
```

Use `AnimatedSprite2D` for frame playback:

```gdscript
animated_sprite.sprite_frames = load(sprite_frames_path)
animated_sprite.play("battle_idle")
```

For Control-based UI components that must work on a freshly cloned project before Godot has rebuilt `.godot/imported`, prefer loading `animation_manifest_path` first and building `AtlasTexture` frames from the source atlas with `Image.load()`. Keep `SpriteFrames` as an editor-friendly resource, but avoid making runtime UI depend on `.godot/imported/*.ctex` caches.

Use `AnimationPlayer` for presentation sequences that combine playback with movement, flash, sound, particles, or screen shake:

```gdscript
animated_sprite.play("attack")
await animated_sprite.animation_finished
animated_sprite.play("battle_idle")
```

Rules should emit or imply presentation events; they should not contain animation resource paths or timing logic.

## Character Select

Character select can use either `AnimatedSprite2D` inside a small scene component, or a Control-native atlas player. Prefer a reusable component over adding animation code directly in button callbacks.

Fallback behavior:

1. Try `animation_sprite_frames_path` and play `select_idle`.
2. If missing, try `battle_idle`.
3. If animation loading fails, show `portrait_path`.
4. If portrait loading fails, use the existing color fallback.

## Import Settings

For pixel-art or pixel-adjacent sprites:

- disable texture filter,
- disable mipmaps,
- preserve alpha,
- avoid lossy compression if edges become muddy.

After adding `.png` assets, let Godot import them and run:

```bash
godot --path . --headless --quit
```

Do not use bare `godot --path . --headless --check-only` for this project. On Godot 4.6.2 for Windows, `--check-only` is intended to be paired with `--script`; the bare command can leave a headless Godot process running.

Use the Godot MCP when it is available. If `run_project` is used only for validation, call `stop_project` after collecting debug output.
