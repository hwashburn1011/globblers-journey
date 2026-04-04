# GLOBBLER'S JOURNEY — BUG FIX & POLISH TRACKER
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude (2026-04-04)
- **Last task completed:** Task 3.1 — Fixed dash_particles.one_shot to true so particles emit once per dash
- **Next task to do:** Task 3.2 — Fix mini-agent insult probability
- **Known issues:** 20 bugs identified in code review. Game is playable but has crashes, softlocks, and broken features.

---

## PASS 1: CRASH FIXES AND SOFTLOCKS
# These bugs will crash the game or trap the player. Fix first.

### 1.1 Fix recursive timer projectile in Local Minimum boss
- [x] In `scenes/enemies/local_minimum_boss/local_minimum_boss.gd`, find `_process_projectile()` (around line 651). It uses `get_tree().create_timer(0.016).timeout.connect(_process_projectile.bind(proj))` which creates exponential timer callbacks. Replace with a proper movement system: either attach a script with `_physics_process` to the projectile node, or move projectile processing into the boss's own `_physics_process` using an array of active projectiles. Make sure reflected projectiles still work.

### 1.2 Fix recursive timer projectile in System Prompt boss
- [x] In `scenes/enemies/system_prompt_boss/system_prompt_boss.gd`, find `_process_fragment()` (around line 687). Same exponential timer bug as 1.1. Replace with proper `_physics_process` movement on the fragment nodes. Check for any other `create_timer(0.016).timeout.connect` patterns in this file and fix them all.

### 1.3 Fix timer-based projectile movement in Foundation Model boss
- [x] In `scenes/enemies/foundation_model_boss/foundation_model_boss.gd`, find projectile processing (around line 584). Uses Timer nodes attached to projectiles with 0.016 wait_time. Replace with `_physics_process` based movement. Ensure hit detection still works after the change.

### 1.4 Fix tween callback in weight_path_puzzle.gd
- [x] In `scenes/puzzles/weight_path_puzzle.gd` around line 319, change `tween.tween_callback(_door.queue_free)` to `tween.tween_callback(func(): _door.queue_free())`. Search the file for any other bare `queue_free` tween callbacks and fix them too.

### 1.5 Fix tween callback in backprop_trace_puzzle.gd
- [x] In `scenes/puzzles/backprop_trace_puzzle.gd` around line 403, change `tween.tween_callback(_door.queue_free)` to `tween.tween_callback(func(): _door.queue_free())`. Search the file for any other bare `queue_free` tween callbacks and fix them too.

### 1.6 Fix terminal hack distance comparison logic
- [x] In `scenes/player/abilities/terminal_hack.gd` around line 75, the condition `dist >= closest_dist` should be `dist > closest_dist`. The current logic rejects closer hackables instead of accepting them. Fix the comparison operator.

### 1.7 Fix rm -rf boss hack terminal cleanup
- [x] In `scenes/enemies/rm_rf_boss/rm_rf_boss.gd`, find the phase 3 recovery logic (around line 305-318). When the boss recovers, any existing hack terminal is not cleaned up. Add code to check for and queue_free the hack terminal when the boss recovers and transitions back to phase 2. Also check for the shield double-break race condition around line 392 — add a `if shield_active` guard so phase 3 can't double-trigger.

---

## PASS 2: CORE GAMEPLAY FIXES
# These bugs break gameplay features but don't crash the game.

### 2.1 Implement pause system
- [x] In `scenes/player/globbler.gd`, find the pause input handling (around line 624). Currently it only toggles mouse capture. Replace with a real pause: when pause is pressed, set `get_tree().paused = true`, show a pause menu (simple ColorRect overlay with "PAUSED" label and Resume/Quit buttons), and capture input. On unpause, set `get_tree().paused = false` and hide the overlay. Set the pause overlay's `process_mode` to `PROCESS_MODE_WHEN_PAUSED`. Make sure the upgrade menu in `scenes/ui/upgrade_menu.gd` also pauses/unpauses when opened/closed.

### 2.2 Remove legacy glob firing system
- [x] Removed `glob_cooldown`, `GLOB_COOLDOWN_TIME`, `glob_projectile_scene` variables, `_fire_glob()` method, its input branch in `_unhandled_input`, the cooldown tick in `_physics_process`, `get_glob_cooldown_percent()`, and the legacy scene load. glob_command ability node handles all glob input now.

### 2.3 Fix camera arm parenting
- [x] Fixed: camera_arm now added as child of player with `top_level = true` so it doesn't inherit player rotation. Removed fragile `get_tree().current_scene.call_deferred()` pattern. Camera follow logic unchanged (uses global_position lerp).

### 2.4 Fix ProgressionManager dialogue call
- [x] Changed `show_dialogue("Globbler", ...)` to `quick_line("GLOBBLER", ...)` at line 250-251. Also updated the `has_method` check. No other `show_dialogue` calls found in the file.

### 2.5 Fix save system progression restore
- [x] Removed the `if not upg_data.is_empty()` guard so `prog.load_save_data(upg_data)` is always called, ensuring ProgressionManager resets properly on fresh saves.

### 2.6 Fix GameManager level state reset on chapter complete
- [x] Added `reset_level()` call after `current_level` increment in `complete_level()`. Also added `max_combo` and `level_goal_reached` resets to `reset_level()` which were missing.

### 2.7 Add chapter transitions after boss defeats
- [x] Check each boss file for what happens after victory. The game needs to transition from chapter N to chapter N+1 after the boss is defeated. In each boss's death/victory handler, add a call to `GameManager.complete_level()` if not present, then after a brief delay use `get_tree().change_scene_to_file()` to load the next chapter's scene. Files to check: `rm_rf_boss.gd` (→ chapter 2), `local_minimum_boss.gd` (→ chapter 3), `system_prompt_boss.gd` (→ chapter 4), `foundation_model_boss.gd` (→ chapter 5). Chapter 5's aligner_boss.gd should already transition to credits.

### 2.8 Fix base_enemy player lookup caching
- [x] In `scenes/enemies/base_enemy.gd` around line 189, `_player_lookup_done` is set to `true` even when no player is found. This means if the player spawns after the enemy, the enemy will never detect them. Fix by only setting `_player_lookup_done = true` when a valid player reference is actually found. Or remove the cache flag entirely and look up the player each time (it's cheap via groups).

### 2.9 Implement dialogue typing animation
- [x] dialogue_box.gd already had full typing animation logic (0.03s/char, fast mode on skip, SFX blips) but was never connected to DialogueManager signals. Added `dm.dialogue_started.connect(show_line)` and `dm.dialogue_ended.connect(hide_box)` in dialogue_box._ready(). The full chain now works: DialogueManager emits → dialogue_box receives and types out character by character.

---

## PASS 3: GAMEPLAY POLISH
# These improve quality but the game works without them.

### 3.1 Fix dash particles one_shot
- [x] In `scenes/player/globbler.gd` around line 539, `dash_particles.one_shot` is set to `false`. Change to `true` so particles emit once per dash instead of continuously.

### 3.2 Fix mini-agent insult probability
- [ ] In `scenes/player/abilities/mini_agent.gd` around line 305, `randf() < INSULT_CHANCE * delta` makes insults nearly impossible (0.3 * 0.016 = 0.48% per frame). Remove the `* delta` so the check is just `randf() < INSULT_CHANCE` (30% chance per check when cooldown expires).

### 3.3 Fix mini-agent infinite wander
- [ ] In `scenes/player/abilities/mini_agent.gd`, when agents can't find a task target they wander forever. In `_process_moving()` (around line 340), add a wander timeout: if the agent has been wandering for more than 5 seconds without finding a task, transition to FAILING state with reason "got lost". This prevents agents from wandering endlessly.

### 3.4 Fix mini-agent apply_impulse
- [ ] In `scenes/player/abilities/mini_agent.gd` around line 554, change `fetch_target.apply_impulse(dir * 8.0)` to `fetch_target.apply_central_impulse(dir * 8.0)` for correct Godot 4 API usage.

### 3.5 Fix audio manager timer memory leak
- [ ] In `scripts/autoload/audio_manager.gd` around lines 800-807, the lambda timer callbacks leak memory. Change each `get_tree().create_timer(X).timeout.connect(func(): ...)` to use `CONNECT_ONE_SHOT` flag: `get_tree().create_timer(X).timeout.connect(func(): ..., CONNECT_ONE_SHOT)`. Search the entire file for this pattern and fix all instances.

### 3.6 Fix audio SFX pool round-robin
- [ ] In `scripts/autoload/audio_manager.gd`, find the SFX pool steal logic (around line 524-536). Currently it always steals `_sfx_players[0]`. Add a `_sfx_steal_index := 0` variable and use round-robin: steal `_sfx_players[_sfx_steal_index]` then increment `_sfx_steal_index = (_sfx_steal_index + 1) % SFX_POOL_SIZE`.

### 3.7 Fix chapter 3 music
- [ ] In `scenes/levels/chapter_3/prompt_bazaar.gd` around line 149, change `am.start_music("chapter_1")` to `am.start_music("chapter_3")`. Check if AudioManager handles unknown track names gracefully (it should fall back). Do the same check in chapters 2, 4, and 5 — make sure each chapter calls the right music track name.

### 3.8 Fix glob_command hardcoded HUD paths
- [ ] In `scenes/player/abilities/glob_command.gd`, find `_get_hud()` (around line 328-335). Remove the hardcoded fallback paths (`/root/TestLevel/HUD`, `/root/MainLevel/HUD`). Instead, only use the group-based lookup: `get_tree().get_nodes_in_group("hud")`. Make sure the HUD is added to the "hud" group in hud.gd's `_ready()`.

### 3.9 Clean up unused code
- [ ] Remove `HIT_ARC` constant from `scenes/player/abilities/wrench_smash.gd` (declared but never used). Remove empty `_ready()` from `scenes/player/abilities/agent_spawn.gd`. Fix agent_spawn.gd task cycling to use `AgentTask.size()` instead of hardcoded `3` (around line 103).

### 3.10 Fix gravity wells not added to group
- [ ] In `scenes/enemies/local_minimum_boss/local_minimum_boss.gd`, find `_fire_gravity_well()` (around line 450). After creating each gravity well node, add it to a group: `well.add_to_group("gravity_wells")`. Then verify the cleanup code around line 781 that calls `get_tree().get_nodes_in_group("gravity_wells")` will properly find and free them.

---

## PASS 4: VALIDATION
# Run the game and verify fixes work.

### 4.1 Smoke test Chapter 1
- [ ] Use Godot MCP: run_project, wait 30 seconds, get_debug_output. Fix any errors. Then stop_project.

### 4.2 Smoke test Chapter 2
- [ ] Use Godot MCP: run_project with Chapter 2 scene. Wait 30 seconds, get_debug_output. Fix any errors. Then stop_project.

### 4.3 Smoke test Chapter 3
- [ ] Use Godot MCP: run_project with Chapter 3 scene. Wait 30 seconds, get_debug_output. Fix any errors. Then stop_project.

### 4.4 Smoke test Chapter 4
- [ ] Use Godot MCP: run_project with Chapter 4 scene. Wait 30 seconds, get_debug_output. Fix any errors. Then stop_project.

### 4.5 Smoke test Chapter 5
- [ ] Use Godot MCP: run_project with Chapter 5 scene. Wait 30 seconds, get_debug_output. Fix any errors. Then stop_project.

### 4.6 Final validation
- [ ] Use Godot MCP: run_project from main menu. Get debug output. Verify zero script errors on launch. Stop project. Commit with message: "V1.1 complete — all bug fixes validated via Godot MCP"
