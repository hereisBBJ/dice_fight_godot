# Dice Fight Godot Development Notes

## Project Context
- This is a Godot 4.6 project for `Dice Fight`, a two-player turn-based dice combat game.
- Treat `docs/GAME_DESIGN.md` as the gameplay source of truth and `docs/TECH_DESIGN.md` as the architecture source of truth.
- Milestone 1 local hot-seat rules demo is implemented.
- Milestone 2 LAN Host/Join foundation is implemented with host-authoritative commands and full snapshot sync.
- Milestone 3 first UI pass is in progress: the main flow now uses editor-adjustable scene screens/components with placeholder visual assets.
- Prioritize correct game logic, clear battle logs, and testable rule separation over polished visuals.

## Current Demo Scope
- Supported characters for the current playable slice: Swordsman, Archer, Witch Doctor, Pyromancer, Frost Swordsman, Arcanist, Vampire, and Stormcaller.
- Implemented flow should remain: character select, augment select, battle, interactive judgment, game over, rematch.
- LAN mode currently supports a host as P1 and one client as P2 over ENet on port `7777`.
- During LAN battle, each player should only see their own dice and pending skill choice; opponent dice, pending action, and related private submit/reroll/modify log entries are hidden/redacted.
- Implemented status logic includes guard, immune, sure evasion, poison, cold, burn, fire shield, eagle eye, flame tide, frost tide, ice wind, static cage, and Pyromancer rebirth.
- UI screens/components for the current flow live under `scenes/ui/` with scripts under `scripts/ui/`; `scripts/ui/main.gd` remains the app controller and network command bridge.
- Placeholder portraits, skill icons, status icons, dice art, and audio slots live under `assets/`; JSON asset path fields are optional and should fall back safely.
- Burn judgment currently auto-accepts rolled dice; the design-doc interaction for rerolling/modifying burn dice is not implemented yet.
- Audio feedback has editable stream slots, but final sound assets are not present yet.
- Keep rules data-driven where practical:
  - Character data lives in `data/characters/`.
  - Common and character augments live in `data/augments_common.json` and `data/augments_character.json`.
  - UI should submit local commands; it should not contain skill-resolution rules.

## Engineering Preferences
- Keep rule code under `scripts/rules/`, data loading under `scripts/data/`, and UI under `scripts/ui/`.
- Keep LAN/network code under `scripts/network/`; clients submit commands and hosts mutate `BattleState`.
- Prefer scene/component edits for UI layout work; keep screen scripts focused on rendering snapshots and emitting commands.
- Do not put damage, MP, shield, dice, or status resolution directly in button callbacks.
- Avoid `:=` in GDScript for values coming from JSON, dictionaries, or other `Variant` sources because this project treats type inference warnings as errors.
- Preserve Chinese display text in UTF-8.
- Use battle logs from the first version onward; logs are part of the debugging and player-understanding surface.

## Progress Hygiene
- After every important modification, explicitly re-check project progress before stopping:
  - compare the change against `docs/GAME_DESIGN.md`, `docs/TECH_DESIGN.md`, and this `AGENTS.md`;
  - update `docs/FORMAL_UI_DEVELOPMENT_PLAN.md` when changing formal UI scope, assets, scene/component structure, or workstream status;
  - update this file if the supported scope, milestones, test commands, known limitations, or tooling assumptions changed;
  - run the smallest relevant validation set for the modified area;
  - inspect `git status --short --branch` and summarize dirty files or commits needed.
- Important modifications include adding or changing character rules, status rules, networking behavior, save/snapshot shape, UI flow, tests, project config, or MCP/tooling assumptions.
- Do not present a milestone as complete unless the matching smoke tests and Godot startup/debug check pass, or explicitly state what could not be validated.

## Godot MCP
- A Codex MCP server named `godot` is expected to be configured globally in `C:\Users\BBJ\.codex\config.toml`.
- It uses `@coding-solo/godot-mcp` through `npx.cmd`.
- Godot is expected at `D:\Programs\Godot\godot.exe`, also available on `PATH`.
- In future Codex sessions, prefer using the Godot MCP to:
  - launch the editor,
  - run the project,
  - capture debug output,
  - verify script parse errors and runtime errors.
- When using MCP `run_project` only for validation, call `stop_project` after capturing debug output so no Godot runtime remains alive.
- If the MCP tool is not visible in a new session, restart Codex so it reloads the MCP config.

## Codex Skills
- A project-local skill for character animation asset production lives at `codex-skills/dice-fight-godot-animations/`.
- Use it when creating or repairing Dice Fight character animation rows, transparent spritesheets, QA contact sheets, Godot `SpriteFrames` resources, or animation asset manifests.
- The skill reuses the hatch-pet style pipeline: generate visual row strips with `$imagegen`, then use deterministic local scripts for recording selected rows, cutting frames, composing atlases, creating contact sheets, and writing Godot-ready resources.
- For automatic discovery in future Codex sessions, copy or install the `dice-fight-godot-animations` skill folder into `C:\Users\BBJ\.codex\skills\` when filesystem approval is available.

## Validation
- Run JSON parsing checks after editing data files.
- Run the Godot project after GDScript changes when the MCP is available.
- If Godot reports parse errors, fix the first reported script and rerun; many follow-on errors may be cascading.
- Do not use bare `godot --path . --headless --check-only`: in Godot 4.6.2 on Windows, `--check-only` is intended for `--script` and the bare form can leave a headless Godot process running. Use `--headless --quit` for startup/debug checks.
- Current useful checks:
  - `godot --path . --headless --quit`
  - `godot --path . --headless --script res://tests/rules/rule_smoke_test.gd`
  - `godot --path . --headless --script res://tests/rules/status_and_new_characters_test.gd`
  - `godot --path . --headless --script res://tests/network/network_controller_smoke_test.gd`
  - `godot --path . --headless --script res://tests/ui/main_network_lifetime_test.gd`
  - `godot --path . --headless --script res://tests/ui/presentation_screens_smoke_test.gd`

## Git
- The repository remote is `git@github.com:hereisBBJ/dice_fight_godot.git`.
- Do not commit generated Godot cache files under `.godot/`.
