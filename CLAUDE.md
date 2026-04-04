# GLOBBLER'S JOURNEY — Core Polish Build (V1.2)

## YOU ARE POLISHING CORE SYSTEMS IN AN EXISTING GODOT 4.x PROJECT (GDScript)

This is a complete 5-chapter game. V1.1 finished all crash fixes and smoke-tested every chapter. This pass closes CORE gameplay gaps before the art/asset pass: legacy cleanup, centralized respawn, game-over flow, tutorial hints, accessibility settings, and dialogue QoL.

**For what to do next, see TASKS.md — that is the source of truth.**

---

## RULES

- Do NOT create new chapters, enemies, puzzles, or bosses. Content is complete.
- Do NOT refactor code outside the file(s) the task names.
- Do NOT touch assets, shaders, models, sprites, or materials in this pass — that comes AFTER.
- Follow the task's file-path hints exactly. If a path is wrong, search for the pattern rather than guessing.
- Keep changes minimal and surgical. One task = one commit.
- GDScript only. Sarcastic comments in Globbler's voice where appropriate.
- After finishing a task, update TASKS.md and commit.

---

## PROJECT LAYOUT

```
scenes/
  player/globbler.gd, globbler.tscn                 # canonical player
  player/abilities/glob_command.gd, wrench_smash.gd, terminal_hack.gd, agent_spawn.gd, mini_agent.gd
  enemies/base_enemy.gd + per-enemy .gd files
  enemies/rm_rf_boss/, local_minimum_boss/, system_prompt_boss/, foundation_model_boss/, aligner_boss/
  puzzles/base_puzzle.gd + per-puzzle .gd files
  levels/chapter_1/terminal_wastes.gd, chapter_2/training_grounds.gd, chapter_3/prompt_bazaar.gd, chapter_4/model_zoo.gd, chapter_5/alignment_citadel.gd
  ui/hud.gd, dialogue_box.gd, context_window_bar.gd, glob_pattern_input.gd, upgrade_menu.gd
  main/main_menu.gd, loading_screen.gd, credits.gd
scripts/
  game_manager.gd (autoload)
  player.gd                                          # LEGACY — scheduled for deletion (Task 1.1/1.2)
  autoload/glob_engine.gd, dialogue_manager.gd, save_system.gd, audio_manager.gd, progression_manager.gd
  components/glob_target.gd, health_component.gd
```

---

## AUTOLOADS (registered in project.godot)

GameManager, GlobEngine, DialogueManager, SaveSystem, AudioManager, ProgressionManager
**Planned this pass:** RespawnManager (Task 2.1/2.2).

---

## KEY PATTERNS

- All autoload lookups use `get_node_or_null("/root/AutoloadName")` — never assume they exist.
- Enemies extend base_enemy.gd with state machine: Patrol, Alert, Chase, Attack, Stunned, Death.
- Puzzles extend base_puzzle.gd with states: Locked, Active, Solved, Failed.
- Level scripts build everything in code via `_ready()` (no prebuilt scene trees). They are large (1500–2100+ lines).
- Dialogue uses `DialogueManager.start_dialogue(lines_array)` or `.quick_line(speaker, text)`.
- Abilities are child nodes of the player, set up in globbler.gd `_ready()`.
- Player is in group "player". HUD is in group "hud". Use `get_tree().get_first_node_in_group(...)` for lookups.
- Signals are connected with `is_connected(...)` guards to avoid double-connect errors.

---

## GODOT MCP SERVER

Validation tools:
- `run_project` — Launch game in debug mode
- `stop_project` — Stop the running game
- `get_debug_output` — Capture console errors/warnings
- `get_project_info` — Project structure details

When a task says "verify via MCP", run the project, capture debug output, and paste any non-trivial warnings into the task's checkbox note.

---

## COMMON PATTERNS FOR THIS PASS

**Autoload registration in project.godot:**
```ini
[autoload]
GameManager="*res://scripts/game_manager.gd"
RespawnManager="*res://scripts/autoload/respawn_manager.gd"
```
The `*` prefix makes it a singleton.

**Fade overlay that survives scene changes:**
```gdscript
_fade_overlay = CanvasLayer.new()
_fade_overlay.layer = 200
_fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
add_child(_fade_overlay)
# Add a ColorRect child with anchors_preset = Control.PRESET_FULL_RECT
```

**First-time hint gate:**
```gdscript
var gm = get_node_or_null("/root/GameManager")
if gm and not gm.has_seen_hint("hint_id"):
    gm.mark_hint_seen("hint_id")
    _show_hint("TITLE", "Body text.")
```

**Difficulty multiplier lookup:**
```gdscript
var gm = get_node_or_null("/root/GameManager")
var mult := 1.0
if gm and gm.has_method("get_difficulty_damage_multiplier"):
    mult = gm.get_difficulty_damage_multiplier()
```

**Dialogue history entry:**
```gdscript
history.append({"speaker": speaker, "text": text, "timestamp": Time.get_unix_time_from_system()})
if history.size() > 200:
    history.pop_front()
```

---

## THINGS TO LEAVE ALONE IN THIS PASS

- Enemy AI logic, boss phase timing, puzzle mechanics.
- Audio mix, music tracks, SFX.
- Shader files under `assets/shaders/` (they are touched only via the `reduce_motion` toggle).
- Level geometry / CSG construction inside chapter `_ready()` functions.
- Save format version changes (additive only — add keys, don't remove).
