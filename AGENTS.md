# Dice Fight Godot Development Notes

## Project Context
- This is a Godot 4.6 project for `Dice Fight`, a two-player turn-based dice combat game.
- Treat `docs/GAME_DESIGN.md` as the gameplay source of truth and `docs/TECH_DESIGN.md` as the architecture source of truth.
- The current milestone is a local hot-seat single-client demo before LAN networking.
- Prioritize correct game logic, clear battle logs, and testable rule separation over polished visuals.

## Current Demo Scope
- Supported characters for the current playable slice: Swordsman, Archer, Witch Doctor, and Pyromancer.
- Implemented flow should remain: character select, augment select, battle, interactive judgment, game over, rematch.
- Keep rules data-driven where practical:
  - Character data lives in `data/characters/`.
  - Common and character augments live in `data/augments_common.json` and `data/augments_character.json`.
  - UI should submit local commands; it should not contain skill-resolution rules.

## Engineering Preferences
- Keep rule code under `scripts/rules/`, data loading under `scripts/data/`, and UI under `scripts/ui/`.
- Do not put damage, MP, shield, dice, or status resolution directly in button callbacks.
- Avoid `:=` in GDScript for values coming from JSON, dictionaries, or other `Variant` sources because this project treats type inference warnings as errors.
- Preserve Chinese display text in UTF-8.
- Use battle logs from the first version onward; logs are part of the debugging and player-understanding surface.

## Godot MCP
- A Codex MCP server named `godot` is expected to be configured globally in `C:\Users\BBJ\.codex\config.toml`.
- It uses `@coding-solo/godot-mcp` through `npx.cmd`.
- Godot is expected at `D:\Programs\Godot\godot.exe`, also available on `PATH`.
- In future Codex sessions, prefer using the Godot MCP to:
  - launch the editor,
  - run the project,
  - capture debug output,
  - verify script parse errors and runtime errors.
- If the MCP tool is not visible in a new session, restart Codex so it reloads the MCP config.

## Validation
- Run JSON parsing checks after editing data files.
- Run the Godot project after GDScript changes when the MCP is available.
- If Godot reports parse errors, fix the first reported script and rerun; many follow-on errors may be cascading.

## Git
- The repository remote is `git@github.com:hereisBBJ/dice_fight_godot.git`.
- Do not commit generated Godot cache files under `.godot/`.
