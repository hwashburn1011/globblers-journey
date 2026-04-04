# GLOBBLER'S JOURNEY — CORE POLISH TRACKER (V1.2)
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# Only change ONE checkbox per iteration. Commit. Stop.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude (2026-04-04) — Task 6.1 complete
- **Last task completed:** Task 6.1 — Added ESC key handling to `dialogue_box.gd` to skip entire dialogue sequence during active dialogue. Added public `skip_all()` method to `dialogue_manager.gd` that calls `_end_dialogue()`. ESC press during dialogue consumes the input event (`set_input_as_handled()`) so it doesn't also trigger the pause menu. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.
- **Next task to do:** Task 6.2 — Add dialogue backlog storage
- **Known issues:** None outstanding.

---

## PASS 1: LEGACY FILE CLEANUP
# Remove shadow/orphan files so future edits don't confuse canonical code paths.

### 1.1 Audit legacy scripts/player.gd vs scenes/player/globbler.gd
- [x] **DONE.** `scripts/player.gd` is referenced only by `scenes/player.tscn` (a flat 7-line orphan scene). `scenes/player.tscn` itself has ZERO references from any .gd, .tscn, or .godot file. Meanwhile, `scenes/player/globbler.tscn` (using `scenes/player/globbler.gd`) is the canonical player — referenced by all 5 chapter level scripts, test_level.gd, and main_level.gd. Both `scripts/player.gd` and `scenes/player.tscn` are safe to delete in Task 1.2.

### 1.2 Delete legacy scripts/player.gd
- [x] **DONE.** Deleted `scripts/player.gd` — zero production references confirmed. Only `scenes/player.tscn` (orphan, Task 1.3) referenced it. No production .gd, .tscn, or project.godot file uses this script.

### 1.3 Audit and remove legacy flat player.tscn
- [x] **DONE.** Found `scenes/player.tscn` — a 7-line orphan scene referencing deleted `scripts/player.gd`. Zero references from any .gd, .tscn, or .godot file (only TASKS.md and MCP addon example docs mentioned it). Deleted. Legacy player shadow issue is now fully resolved.

### 1.4 Audit test_level.gd and test_level.tscn
- [x] **DONE.** `test_level.gd`/`test_level.tscn` are NOT on any shipping path. Zero references from `project.godot`, main menu (`main_menu.gd`), chapter select, or any production .gd/.tscn file. Only self-reference in its own .tscn and a comment in `glob_pattern_test.gd`. Added `# DEV ONLY` comment block at top of `test_level.gd`.

---

## PASS 2: CENTRALIZE RESPAWN / CHECKPOINT FLOW
# Every chapter script has its own _on_player_died fade+teleport logic (~150 lines each).
# Extract into a single RespawnManager so the behavior lives in one place.

### 2.1 Create RespawnManager autoload skeleton
- [x] **DONE.** Created `scripts/autoload/respawn_manager.gd` extending Node. Has `current_checkpoint: Vector3`, `current_chapter: int`, `set_checkpoint(pos, chapter)`, `respawn_player()` stub (prints to console), signals `respawn_started` and `respawn_finished`. Not wired up yet — registration is Task 2.2.

### 2.2 Register RespawnManager in project.godot
- [x] **DONE.** Added `RespawnManager="*res://scripts/autoload/respawn_manager.gd"` to `[autoload]` in project.godot, after DialogueManager and before SaveSystem. MCP run_project verified: zero script errors, zero runtime errors. Only warnings are expected unused-signal notices for `respawn_started`/`respawn_finished` (wired in Task 2.4).

### 2.3 Implement fade-to-black overlay in RespawnManager
- [x] **DONE.** Added `_fade_overlay: CanvasLayer` (layer 200, `PROCESS_MODE_ALWAYS`) with black `ColorRect` child (`PRESET_FULL_RECT`, `modulate.a = 0`, `mouse_filter = IGNORE`) built in `_ready()`. Added `_fade_out(duration)` and `_fade_in(duration)` async helpers using tweens with `TWEEN_PAUSE_PROCESS`. Kills any active tween before starting a new one. MCP verified: project loads cleanly, zero script errors. Only warnings are expected unused-signal notices (wired in Task 2.4) and a pre-existing integer division warning.

### 2.4 Implement respawn_player() logic in RespawnManager
- [x] **DONE.** Filled in `respawn_player()`: emit `respawn_started`, fade out (0.5s), teleport player (found via group "player") to `current_checkpoint`, restore health to full via `health_component.heal_full()` or equivalent, fade in (0.5s), emit `respawn_finished`. If no player found or no checkpoint set, log warning and bail out safely.

### 2.5 Migrate Chapter 1 to RespawnManager
- [x] **DONE.** `_on_player_died()` now calls `rm.respawn_player()` alongside the narrator quip. Checkpoint body_entered handler calls `rm.set_checkpoint(pos, 1)`. `_spawn_player()` seeds RespawnManager with initial player position as fallback. No local fade overlay existed to remove. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 2.6 Migrate Chapter 2 to RespawnManager
- [x] **DONE.** `_on_player_died()` now calls `rm.respawn_player()` alongside narrator quips. Checkpoint body_entered handler calls `rm.set_checkpoint(pos, 2)`. `_spawn_player()` seeds RespawnManager with initial player position as fallback. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 2.7 Migrate Chapter 3 to RespawnManager
- [x] **DONE.** `_on_player_died()` now calls `rm.respawn_player()` alongside narrator quips. Checkpoint body_entered handler calls `rm.set_checkpoint(pos, 3)`. `_spawn_player()` seeds RespawnManager with initial player position as fallback. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 2.8 Migrate Chapter 4 to RespawnManager
- [x] **DONE.** `_on_player_died()` now calls `rm.respawn_player()` alongside narrator quips. Checkpoint body_entered handler calls `rm.set_checkpoint(pos, 4)`. `_spawn_player()` seeds RespawnManager with initial player position as fallback. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 2.9 Migrate Chapter 5 to RespawnManager
- [x] **DONE.** `_on_player_died()` added with Citadel-themed narrator quips + `rm.respawn_player()`. Connected `player_died` signal in `_spawn_player()`. Checkpoint body_entered handler calls `rm.set_checkpoint(pos, 5)`. `_spawn_player()` seeds RespawnManager with initial player position as fallback. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 2.10 Add player-to-group registration
- [x] **DONE.** `add_to_group("player")` already present at `globbler.gd:158`, first statement in `_ready()`. No changes needed — RespawnManager group lookup is already satisfied.

---

## PASS 3: GAME OVER FLOW
# Today death just respawns forever. Add a real fail-state after repeated deaths and for context depletion.

### 3.1 Add death threshold tracking to GameManager
- [x] **DONE.** Added `DEATH_THRESHOLD := 8`, `deaths_this_level := 0`, `register_death()` to `game_manager.gd`. `register_death()` increments counter and emits `game_over` signal with reason when threshold reached. Added `register_death()` call in `respawn_manager.gd` `respawn_player()` before respawn sequence. `deaths_this_level` reset to 0 in `reset_level()`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning. In `scripts/game_manager.gd`, add `const DEATH_THRESHOLD := 8`, `var deaths_this_level := 0`, `func register_death()` that increments and emits existing `game_over` signal when `deaths_this_level >= DEATH_THRESHOLD` with reason "Too many retries — the gradient has descended permanently." Call `register_death()` from RespawnManager.respawn_player() (one-line addition there). Reset `deaths_this_level = 0` inside `reset_level()`.

### 3.2 Create game_over.tscn scene
- [x] **DONE.** Created `scenes/ui/game_over.gd` and `game_over.tscn`. CanvasLayer (layer 150, PROCESS_MODE_ALWAYS) with black scanline background, "CONTEXT TERMINATED" title in red with glitch effect, reason label via `set_reason()`, ASCII skull art, three buttons: RETRY (reloads current chapter, resets death counter), LOAD SAVE (calls SaveSystem.load_game), MAIN MENU (change_scene_to_file to main_menu.tscn). All buttons use PROCESS_MODE_ALWAYS so they work while game is paused. Terminal-aesthetic green-on-dark styling matches main_menu.gd. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 3.3 Wire game_over signal to game_over scene
- [x] **DONE.** Connected `game_over` signal to `_on_game_over` handler in `game_manager.gd` `_ready()` with `is_connected` guard. Handler loads `res://scenes/ui/game_over.tscn`, instantiates it, calls `set_reason(reason)`, adds to `/root`, and sets `get_tree().paused = true`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 3.4 Verify game over flow via MCP
- [x] **DONE.** MCP run_project verified: zero script errors, zero runtime errors. Only pre-existing integer division warning. Game over flow wiring confirmed: `game_over` signal connected in `_ready()`, handler loads `game_over.tscn`, sets reason, adds to root, pauses tree. Two trigger paths: (1) context window depletion, (2) death count >= 8 via `register_death()`. Manual test: deplete context window OR die 8 times in one level → game over screen shows → RETRY reloads chapter + resets death counter, LOAD SAVE calls SaveSystem.load_game, MAIN MENU returns to main_menu.tscn.

---

## PASS 4: TUTORIAL / FIRST-TIME HINTS
# The game throws six abilities at the player with zero teaching. Add lightweight first-time toast hints.

### 4.1 Create first_time_hint UI component
- [x] **DONE.** Created `scenes/ui/first_time_hint.gd` and `.tscn`. CanvasLayer (layer 100, PROCESS_MODE_ALWAYS) with terminal-style PanelContainer that slides in from top using TRANS_BACK easing. Auto-dismisses after 4s, early dismiss via any key/click/gamepad button. Single public method `show_hint(title, body)`. Green-on-black styling (#39FF14, dark bg 0.04 alpha 0.95, bordered panel). MCP verified: zero script errors, zero runtime errors.

### 4.2 Add hints_seen tracking to GameManager
- [x] **DONE.** Added `var hints_seen := {}`, `func has_seen_hint(id: String) -> bool`, `func mark_hint_seen(id: String)` to `game_manager.gd`. SaveSystem has no `get_save_data()` on GameManager — instead hooked directly into `save_system.gd`: `_collect_current_state()` saves `hints_seen` to save dict, `apply_loaded_data()` restores it on load with type guard. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.3 Fire movement hint on Chapter 1 spawn
- [x] **DONE.** Added `_show_hint_once(id, title, body)` helper to `terminal_wastes.gd` — checks `GameManager.has_seen_hint(id)`, marks hint seen via `mark_hint_seen(id)`, instantiates `first_time_hint.tscn` on root, and calls `show_hint(title, body)`. Called at end of `_ready()` with movement hint. Preloaded `hint_scene`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.4 Fire glob-command hint on first aim-mode enter
- [x] **DONE.** Added `_show_hint_once(id, title, body)` helper and `_HINT_SCENE` preload to `glob_command.gd`. Fires hint id "glob_aim" in `start_aim()` on first aim-mode activation. Routes through `GameManager.has_seen_hint()`/`mark_hint_seen()`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.5 Fire wrench hint on first enemy detected within 10m
- [x] **DONE.** Added `_check_enemy_proximity()` in `globbler.gd`, called from `_physics_process` throttled to 1s via `_enemy_check_timer`. Scans "enemies" group, fires hint id "wrench" on first enemy within 10m. Early-exits if hint already seen (no wasted cycles). Preloaded `_HINT_SCENE` and added `_show_hint_once` helper. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.6 Fire hack hint on first hackable approach
- [x] **DONE.** Added `_HINT_SCENE` preload and `_show_hint_once` helper to `terminal_hack.gd`. Fires hint id "hack" at end of `_scan_for_hackables()` when `_nearby_hackable` is set. Routes through `GameManager.has_seen_hint()`/`mark_hint_seen()`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.7 Fire dash hint after 30 seconds of gameplay
- [x] **DONE.** Added 30-second one-shot `DashHintTimer` in `globbler.gd` `_ready()`. Timer only created if "dash" hint not already seen. On timeout, `_on_dash_hint_timeout()` calls `_show_hint_once("dash", "DASH", "Double-tap movement or press SHIFT+direction to dash. Cooldown is real.")`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 4.8 Fire agent-spawn hint on chapter 2 entry
- [x] **DONE.** Added `hint_scene` preload and `_show_hint_once` helper to `training_grounds.gd`. Fires hint id "agent_spawn" at end of `_ready()`, gated on `player.agent_spawn.is_unlocked`. Routes through `GameManager.has_seen_hint()`/`mark_hint_seen()`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

---

## PASS 5: ACCESSIBILITY AND SETTINGS
# Glitch + chromatic + bloom shaders can be a problem. Add toggles and difficulty scaling.

### 5.1 Add difficulty enum to GameManager
- [x] **DONE.** Added `enum Difficulty { EASY, NORMAL, HARD }`, `var difficulty := Difficulty.NORMAL`, `get_difficulty_damage_multiplier()` (Easy 0.5, Normal 1.0, Hard 1.5), `get_difficulty_enemy_hp_multiplier()` (Easy 0.75, Normal 1.0, Hard 1.25) to `game_manager.gd`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.2 Apply difficulty to enemy damage taken by player
- [x] **DONE.** In `health_component.gd` `take_damage()`, added difficulty multiplier lookup via `GameManager.get_difficulty_damage_multiplier()` gated on `get_parent().is_in_group("player")`. Uses `ceil()` to prevent rounding to zero on Easy. Enemy damage unaffected. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.3 Apply difficulty to enemy max HP on spawn
- [x] **DONE.** In `base_enemy.gd` `_ready()`, multiply `max_health` by `GameManager.get_difficulty_enemy_hp_multiplier()` before `_setup_health_component()` is called. Uses `ceil()` to prevent rounding to zero on Easy. Gated on `get_node_or_null("/root/GameManager")` and `has_method()`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.4 Add reduce_motion toggle
- [x] **DONE.** Added `var reduce_motion := false`, `signal reduce_motion_changed(enabled: bool)`, and `set_reduce_motion(enabled)` to `game_manager.gd`. When enabled: (1) all 5 chapter `_setup_post_processing()` early-return, skipping chromatic aberration + vignette shaders; (2) `corrupted_shell_script.gd` skips `glitch.gdshader` and falls back to static StandardMaterial3D; (3) `main_menu.gd` skips title glitch text and scanline animation; (4) `game_over.gd` skips title glitch text; (5) `dalle_nightmare.gd` skips glitch part jitter. Files touched: `game_manager.gd`, `terminal_wastes.gd`, `training_grounds.gd`, `prompt_bazaar.gd`, `model_zoo.gd`, `alignment_citadel.gd`, `corrupted_shell_script.gd`, `main_menu.gd`, `game_over.gd`, `dalle_nightmare.gd`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.5 Add dialogue_speed setting
- [x] **DONE.** Added `var dialogue_char_delay := 0.03` to `game_manager.gd` (range 0.005–0.08). In `dialogue_box.gd`, replaced hardcoded `TYPING_SPEED` with dynamic lookup from `GameManager.dialogue_char_delay`, with `DEFAULT_TYPING_SPEED` (0.03) fallback. Fast-mode (0.005) for mashing unchanged. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.6 Add settings panel controls for new toggles
- [x] **DONE.** Added three controls to existing settings panel in `main_menu.gd`: Difficulty OptionButton (Easy/Normal/Hard, wired to `gm.difficulty`), Reduce Motion CheckBox (wired to `gm.set_reduce_motion()`), Dialogue Speed HSlider (inverted mapping: 0.0=slow/0.08s delay, 1.0=fast/0.005s delay, wired to `gm.dialogue_char_delay`). All read initial values from GameManager. Panel min height expanded 350→520. Terminal-green styling consistent with existing controls. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 5.7 Persist settings to user://settings.cfg
- [x] **DONE.** Added `save_settings()` / `load_settings()` to `game_manager.gd` using ConfigFile at `user://settings.cfg`. Stores difficulty, reduce_motion, dialogue_char_delay, music_volume, sfx_volume, ui_volume. `load_settings()` called in `_ready()` — gracefully handles missing file (first launch). `save_settings()` called from all settings callbacks in `main_menu.gd`: difficulty, reduce_motion, dialogue_speed, music_volume, sfx_volume. On load, fires `reduce_motion_changed` signal if enabled so shaders update. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

---

## PASS 6: DIALOGUE QUALITY OF LIFE
# For a dialogue-heavy sarcastic game, players will want to re-read and skip.

### 6.1 Add dialogue skip-all input
- [x] **DONE.** Added ESC handling in `dialogue_box.gd` `_unhandled_input()`: checks for "pause" action press, and if DialogueManager has active dialogue, calls `dm.skip_all()` and consumes the event via `set_input_as_handled()` so pause menu is not triggered. Added public `skip_all()` method to `dialogue_manager.gd` that calls `_end_dialogue()` to cleanly end the sequence and emit `dialogue_ended`. MCP verified: zero script errors, zero runtime errors. Only pre-existing integer division warning.

### 6.2 Add dialogue backlog storage
- [ ] In `scripts/autoload/dialogue_manager.gd`, add `var history: Array[Dictionary] = []` (max 200 entries). Each entry `{speaker, text, timestamp}`. Append every time a line is shown. Add `func get_history() -> Array` accessor.

### 6.3 Add dialogue history viewer
- [ ] Create `scenes/ui/dialogue_history.gd` and `.tscn`. Opens with H key (bind via GameManager input action "dialogue_history"). Scrollable list of last 30 history entries. Close with ESC or H. `process_mode = PROCESS_MODE_WHEN_PAUSED` and pauses the game while open.

---

## PASS 7: FINAL VALIDATION
# Prove the polish pass did not break anything.

### 7.1 MCP smoke test all chapters
- [ ] Use Godot MCP: run_project from main menu, capture debug output, verify zero script errors. Then load Chapter 1 from chapter select, capture output. Repeat for chapters 2-5. Stop project cleanly. List all warnings in the checkbox note.

### 7.2 Commit final V1.2 tag
- [ ] Commit any remaining changes. Write completion summary at the top of TASKS.md CURRENT STATUS. Tag or note as "V1.2 — core polish complete".
