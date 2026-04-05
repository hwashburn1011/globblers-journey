# GLOBBLER'S JOURNEY — RELEASE READINESS & AUDIO (V2.1)
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# Only change ONE checkbox per iteration. Commit. Stop.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude (2026-04-05)
- **Last task completed:** Task 2.12 — Download CC0 UI SFX
- **Next task to do:** Task 2.13 — Download CC0 enemy SFX
- **Known issues:**
  - **CRITICAL: New Game from main menu → dark green blank screen (unplayable)**
  - **Title screen has obsolete ASCII Globbler that should be removed**
  - ~~Text contrast problems across menus/HUD~~ **FIXED in Task 0.3**
  - Duplicate `globbler.glb` at project root (3.4MB waste)
  - `build_log_*.txt` files committed to repo
  - AudioManager uses AudioStreamGenerator procedural synth — no real music/SFX
  - Windows export build has never been verified to run standalone
  - No end-to-end playtest since V2.0 graphics pass landed

### GOAL OF THIS PASS
Make V2.0 shippable. Real audio assets (music + SFX), verified Windows builds, cleanup of known issues, and a full chapter-by-chapter playtest to catch regressions from the graphics overhaul. Optional: shipping extras (photo mode, speedrun timer, collectibles).

### V2.0 CARRYOVER REFERENCE
- 57 GLB models, 10 shaders, 5 HDRIs
- WorldEnvironment resources per chapter: `assets/environments/chapter_{1-5}.tres`
- Color palette locked per chapter (see ai-archive/4-5-26-1/CLAUDE.md.completed for reference table)
- Reduce-motion toggle gates CRT curvature, glitch effects, and animated shaders
- Screen-shake presets live in `scripts/utils/camera_shake.gd`

---

## PASS 0: CRITICAL PLAYTEST FIXES
# Real playtest feedback. Fix these FIRST before anything else — the game is unplayable without them.

### 0.1 Fix "New Game → dark green blank screen"
- [x] **FIXED:** Two root causes: (1) `ReflectionProbe3D` is not a valid Godot 4.4.1 class (correct name: `ReflectionProbe`) — caused parser error in main_level.gd and all 5 chapter scripts, preventing scene load entirely. (2) CRT curvature shader used deprecated `SCREEN_TEXTURE` builtin — added `uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;` declaration. Fixed in: scripts/main_level.gd, all 5 chapter level .gd files, assets/shaders/crt_curvature.gdshader. Verified: level now loads with player, camera, and HUD active, zero new runtime errors. Investigate in this order: (a) Godot MCP run_project, launch game, click New Game, capture debug output. (b) Check whether `scenes/ui/chapter_transition.tscn` (Task 15.6) fade-out is getting stuck — its ColorRect may never queue_free / tween back to alpha 0. (c) Check whether `crt_curvature` whole-screen post shader (Task 15.5) is rendering full-green when no main camera is active. (d) Check whether Chapter 1 scene actually loads — `scenes/levels/chapter_1/terminal_wastes.tscn` root node + camera/player spawn. (e) Check main_menu.gd new-game handler uses correct `change_scene_to_file` path. Fix whichever is broken. Re-test end to end — new game must land on playable Chapter 1 spawn with player visible and camera active.

### 0.2 Remove ASCII Globbler from title screen
- [x] **DONE:** Removed `GLOBBLER_ASCII` constant (14-line art block) and its Label creation from `_build_ui()` in `scenes/main/main_menu.gd`. Glitchy title text, 3D background, and all other menu elements preserved. Verified via Godot MCP — menu loads with zero errors.

### 0.3 Text contrast audit — global pass
- [x] **DONE:** Audited all UI screens for text contrast. Added dark drop-shadows (font_shadow_color + shadow_outline_size=2) to all dim/secondary text labels across 13 files. Brightened low-alpha and too-dim green colors (e.g. DIM_GREEN from 0.15→0.2+, alpha from 0.3-0.5→0.5-0.85) while preserving terminal-green aesthetic. Screens touched: **HUD** (hud.gd — upgrade hint, timer, combo, thought, level intro, minimap, ability labels, stat counters), **main menu** (main_menu.gd — subtitle, version label, settings subtitle, controls text, ESC hint, chapter descriptions), **pause menu** (globbler.gd — subtitle, ESC hint), **game over** (game_over.gd — error line, skull art, death count, input hint), **chapter summary** (chapter_summary.gd — stat names, dot leaders, sarcastic comment), **dialogue box** (dialogue_box.gd — advance hint), **dialogue history** (dialogue_history.gd — line numbers, entry count, footer), **upgrade menu** (upgrade_menu.gd — DIM_GREEN brightened, all labels get shadow via _make_label, close hint), **first-time hint** (first_time_hint.gd — border labels, footer), **loading screen** (loading_screen.gd — tip label), **credits** (credits.gd — DIM_GREEN brightened, all labels get shadow), **context window bar** (context_window_bar.gd — value label), **glob pattern input** (glob_pattern_input.gd — result label). Verified via Godot MCP — zero runtime errors.

### 0.4 Verify text contrast per chapter HUD
- [x] **DONE:** Tested all 5 chapters via Godot MCP (run_project with each chapter scene). All load with zero runtime errors. Analyzed HUD elements against each chapter's environment: paneled elements (top-left stats, minimap, abilities) are safe everywhere due to TERMINAL_BG dark backing. Floating elements (timer, combo, thought, level intro) are at risk in Ch5 (bg_energy=1.2, nearly-white fog). Fix: added subtle semi-transparent dark backdrop panel behind the always-visible timer label; strengthened thought label shadow outline from 2→4. Combo and level_intro already had outline=3 and are temporary/large text. Ch1 (dark green), Ch2 (blue-green, moderate), Ch3 (warm amber — complementary hue to green = good contrast), Ch4 (dark dusty) all fine. Verified Ch5 + Ch3 post-fix via Godot MCP — zero new errors.

---

## PASS 1: CLEANUP & KNOWN ISSUES
# Fix the documented debt before anything else.

### 1.1 Delete duplicate globbler.glb at project root
- [x] **DONE:** Duplicate files (`assets/globbler.glb`, `.import`, `globbler_globbler_ao.png`+`.import`) already absent from `assets/` root — cleaned up in a prior iteration. Canonical copy confirmed at `assets/models/player/globbler.glb`. Grep confirms no stale references. No action needed.

### 1.2 Gitignore build logs and generated artifacts
- [x] **DONE:** `.gitignore` already had `build_log_*.txt` and `/build/`. Added `build_log_*.md` and `*.pdb`. Ran `git rm --cached` on two tracked build log .md files (`build_log_2026-04-04_lighting.md`, `build_log_2026-04-05_performance.md`). All build artifacts now properly ignored.

### 1.3 Gitignore verification pass
- [x] **DONE:** Ran `git status` — no temp/generated artifacts tracked except one `.blend1` backup file (`assets/blender_source/globbler.blend1`). Removed it from tracking via `git rm --cached` and added `*.blend1` to `.gitignore`. Verified all `.import` files have corresponding source assets (no orphans). No `.tmp`, `.bak`, `.swp`, `.pyc`, or `.DS_Store` files tracked. `tools/blender-mcp/` correctly untracked.

### 1.4 Verify .gdkeep placeholders removed where unneeded
- [x] **DONE:** Found 8 `.gdkeep` files across `assets/` — all in directories now containing real assets (models/player, models/enemies, models/bosses, models/environment, blender_source, hdri, textures/pbr, environments). Removed all 8 via `git rm`. No genuinely empty scaffolding folders remain that need .gdkeep. Audio folders don't exist yet (created in Pass 2).

---

## PASS 2: REAL AUDIO ASSETS
# Replace procedural synth with real CC0 music + SFX.

### 2.1 Create audio asset folders
- [x] **DONE:** Created `assets/audio/music/`, `assets/audio/sfx/`, `assets/audio/ambient/` with `.gdkeep` files so git tracks them. Added 3 placeholder rows to `assets/LICENSES.md` for upcoming music, SFX, and ambient audio assets.

### 2.2 Download CC0 main menu music
- [x] **DONE:** Downloaded "Menu Music" by wipics from OpenGameArt.org (CC0). Synth/beat loop, ~90s, 901KB OGG. Saved to `assets/audio/music/menu.ogg`. Attribution added to LICENSES.md.

### 2.3 Download CC0 Chapter 1 music
- [x] **DONE:** Downloaded "A Wonderful Nightmare" by SpiderDave from OpenGameArt.org (CC0). Dark/spooky OGG track, 5.2MB. Saved to `assets/audio/music/chapter_1.ogg`. Attribution added to LICENSES.md.

### 2.4 Download CC0 Chapter 2 music
- [x] **DONE:** Downloaded "Experiment G" by tricksntraps from OpenGameArt.org (CC0). Cyberpunk/synth lab track, 6.1MB OGG, from T & T Free Cyberpunk Pack. Saved to `assets/audio/music/chapter_2.ogg`. Attribution added to LICENSES.md.

### 2.5 Download CC0 Chapter 3 music
- [x] **DONE:** Downloaded "Town4 - Bazaar" by SubspaceAudio (Juhani Junkala) from OpenGameArt.org (CC0). Warm bazaar/market loop, 3.8MB OGG, from JRPG Music Pack #2 [Towns]. Saved to `assets/audio/music/chapter_3.ogg`. Attribution added to LICENSES.md.

### 2.6 Download CC0 Chapter 4 music
- [x] **DONE:** Downloaded "EmptyCity" by yd from OpenGameArt.org (CC0). Dark atmospheric soundtrack evoking a devastated/desolate space — perfect for the eerie "Model Zoo" museum chapter. 2.0MB OGG, loopable. Saved to `assets/audio/music/chapter_4.ogg`. Attribution added to LICENSES.md.

### 2.7 Download CC0 Chapter 5 music
- [x] **DONE:** Downloaded "Elevator Music" by Pro Sensory (Alex McCulloch) from OpenGameArt.org (CC0). Clean corporate elevator muzak — perfect for the sterile "Alignment Citadel" corporate vibe. Downloaded as WAV (16.9MB), converted to OGG via ffmpeg. 1.8MB OGG, ~1:36 loop. Saved to `assets/audio/music/chapter_5.ogg`. Attribution added to LICENSES.md.

### 2.8 Download CC0 boss music
- [x] **DONE:** Downloaded "Trance Boss Battle" by MintoDog from OpenGameArt.org (CC0). Intense trance boss battle track, 150 BPM, loopable. 3.4MB OGG, stereo 44100 Hz. Saved to `assets/audio/music/boss.ogg`. Attribution added to LICENSES.md.

### 2.9 Download CC0 credits music
- [x] **DONE:** Downloaded "Lonely Night" by Centurion_of_war from OpenGameArt.org (CC0). Calm, contemplative chiptune loop with a reflective mood — suitable for credits roll. 3.6MB OGG, loopable. Saved to `assets/audio/music/credits.ogg`. Attribution added to LICENSES.md.

### 2.10 Download CC0 gameplay SFX pack
- [x] **DONE:** Downloaded 7 player SFX from 4 CC0 OpenGameArt sources: (1) yd's "Platformer Sounds" → player_footstep_1.ogg, player_footstep_2.ogg (metal platform steps), player_land.ogg (metal landing impact). (2) qubodup's "15 Vocal Male Strain/Hurt/Pain/Jump Sounds" → player_jump.ogg (effort grunt), player_hurt.ogg (pain grunt). (3) qubodup's "Swish - Bamboo Stick Weapon Swooshes" → player_dash.ogg (swoosh). (4) thebardofblasphemy's "Grunts of Male Death and Pain" → player_death.ogg (2s death grunt clip). All CC0, all saved to assets/audio/sfx/player_*.ogg, all attributions in LICENSES.md.

### 2.11 Download CC0 ability SFX
- [x] **DONE:** Downloaded 4 ability SFX from Kenney's "Sci-Fi Sounds" pack on OpenGameArt.org (CC0). All OGG format, ready to use: (1) ability_glob_cast.ogg ← laserLarge_000 (energy projectile cast, 25KB). (2) ability_wrench.ogg ← impactMetal_000 (metal wrench impact, 15KB). (3) ability_hack.ogg ← computerNoise_000 (computer beep sequence, 119KB). (4) ability_agent_spawn.ogg ← forceField_000 (force field activation pop, 25KB). All saved to assets/audio/sfx/ability_*.ogg. Attribution added to LICENSES.md.

### 2.12 Download CC0 UI SFX
- [x] **DONE:** Downloaded 7 UI SFX from Kenney's "Interface Sounds" pack on OpenGameArt.org (CC0). All OGG format: (1) ui_hover.ogg ← select_003 (rollover highlight, 7KB). (2) ui_click.ogg ← click_001 (button click, 5KB). (3) ui_dialogue_advance.ogg ← confirmation_001 (confirm/advance chime, 9KB). (4) ui_dialogue_blip.ogg ← tick_001 (typing blip tick, 4KB). (5) ui_pause_open.ogg ← open_001 (menu open, 10KB). (6) ui_pause_close.ogg ← close_001 (menu close, 10KB). (7) ui_token_pickup.ogg ← pluck_001 (token pickup pluck, 6KB). All saved to assets/audio/sfx/ui_*.ogg. Attribution added to LICENSES.md.

### 2.13 Download CC0 enemy SFX
- [ ] Generic enemy alert, attack, death (3 variants of each). Save to `assets/audio/sfx/enemy_*.ogg`. Record attributions.

### 2.14 Wire music tracks into AudioManager
- [ ] In `scripts/autoload/audio_manager.gd`, add a `_loaded_music: Dictionary` map. In `start_music(track_name)`, attempt to `load("res://assets/audio/music/" + track_name + ".ogg")` first. On success, play the loaded stream. On failure, fall back to existing procedural synth. Same pattern for `boss_music`. Keep procedural as safety net.

### 2.15 Wire SFX into AudioManager
- [ ] Add `_loaded_sfx: Dictionary` map. In the existing `play_sfx(sfx_name)` path, attempt to load `res://assets/audio/sfx/<name>.ogg` first, fall back to procedural synth. Covers player, ability, UI, and enemy SFX from Tasks 2.10–2.13.

### 2.16 Audio mix balance pass
- [ ] Playtest via Godot MCP: launch game, walk through menu → chapter 1 → combat → dialogue. Adjust `BASE_VOLUME_DB` offsets in audio_manager.gd so music sits below dialogue and SFX pop above music. Set sensible defaults in settings.cfg (music=0.6, sfx=0.8, dialogue=1.0). Document the chosen levels.

---

## PASS 3: EXPORT & RELEASE VALIDATION
# Prove the game actually builds and runs outside the editor.

### 3.1 Validate export_presets.cfg
- [ ] Read `export_presets.cfg`. Verify Windows Desktop preset exists, exclude filters don't skip `assets/audio/` or new shaders, embed_pck is set correctly. Document any fixes needed.

### 3.2 Add .export-ignore patterns
- [ ] Add patterns to export preset's `exclude_filter` for: `ai-archive/`, `tools/blender-mcp/`, `build_log_*`, `*.blend`, `*.blend1`. These shouldn't ship in the final build.

### 3.3 Build Windows export
- [ ] Run `export_game.ps1` or `export_game.sh` (whichever exists). Capture full build output. Report: did it complete? Where is the output? How big is it?

### 3.4 Verify exported build runs standalone
- [ ] Launch the exported .exe from outside the project directory. Confirm main menu appears, no missing resource errors, a chapter can be loaded. Capture first 30s of stdout/stderr. Note any issues.

### 3.5 Add version display to main menu
- [ ] Add `GAME_VERSION := "2.1.0"` constant to GameManager. Add a small version label (bottom-right corner) on `main_menu.tscn` showing `v2.1.0`. Subtle dim color.

### 3.6 Add commit hash display (dev builds only)
- [ ] If a `.git/HEAD` file exists at runtime, read the short commit hash and append to the version label (e.g. `v2.1.0 (a009cf1)`). Wrap in `OS.is_debug_build()` check so it only shows in editor/debug builds.

### 3.7 Finalize credits roll
- [ ] Read `scenes/main/credits.gd`. Ensure it lists: all CC0 attributions from `assets/LICENSES.md`, tools used (Godot 4.x, Blender 5.1, blender-mcp), project chapters, and sequel tease. Update if any V2.0/V2.1 contributors are missing.

---

## PASS 4: PLAYTEST & REGRESSION FIXES
# Chapter-by-chapter validation via Godot MCP.

### 4.1 Playtest Chapter 1
- [ ] Via Godot MCP: run_project, load chapter 1, spend 5 minutes exploring + combat + at least one puzzle. Capture debug output. List any visual bugs, script errors, missing SFX, broken interactions. Do NOT fix yet — just catalog.

### 4.2 Playtest Chapter 2
- [ ] Same as 4.1 for chapter 2. Catalog issues.

### 4.3 Playtest Chapter 3
- [ ] Same for chapter 3. Catalog issues.

### 4.4 Playtest Chapter 4
- [ ] Same for chapter 4. Catalog issues.

### 4.5 Playtest Chapter 5
- [ ] Same for chapter 5. Catalog issues.

### 4.6 Fix playtest batch 1 (gameplay-breaking)
- [ ] Fix the top 3 most gameplay-breaking bugs cataloged in 4.1–4.5. One fix per file where possible, minimal changes.

### 4.7 Fix playtest batch 2 (visual glitches)
- [ ] Fix the next 3 most visible visual bugs from 4.1–4.5. E.g. missing textures, z-fighting, broken shaders.

### 4.8 Fix playtest batch 3 (cleanup)
- [ ] Fix remaining cosmetic/minor issues from the playtest catalog. If nothing remains, mark the task done with "no remaining issues found".

---

## PASS 5: SHIPPING EXTRAS (OPTIONAL)
# Fun additions that add replayability. Skip if release-ready is the priority.

### 5.1 Photo mode
- [ ] Add photo_mode input action (F12). When pressed: pause game, hide HUD, detach camera from player, enable WASD camera movement + mouse look. Press F12 to exit. No recording — just framing.

### 5.2 Speedrun timer overlay
- [ ] Add a toggleable speedrun timer to HUD (display_speedrun_timer setting in GameManager, default off). Shows MM:SS.mmm since chapter start. Continues across deaths but stops on chapter complete.

### 5.3 Lore doc collectibles — data structure
- [ ] Add `lore_docs_found: Dictionary` to GameManager + `add_lore_doc(id, title, body)` + `has_found_lore_doc(id)`. Include in save data. Signal `lore_doc_collected(id)`.

### 5.4 Lore doc pickup scene
- [ ] Create `scenes/pickups/lore_doc.tscn` + `.gd` — floating terminal-tablet mesh that pulses. On player overlap + E press, calls `add_lore_doc` with the pickup's exported id/title/body, plays pickup VFX, queue_frees.

### 5.5 Place 15 lore docs across chapters
- [ ] Place 3 lore doc pickups per chapter in each level's `_ready()`. Write flavor text for each (Globbler voice). Use existing narrative (AGI, alignment, the Citadel, etc.). 15 total docs.

### 5.6 Lore doc viewer in pause menu
- [ ] Add "Archive" button to pause menu opening `scenes/ui/lore_viewer.tscn`. Scrollable list of found docs, title + body text panel. Shows "? / 15" at top.

### 5.7 Simple achievements framework
- [ ] Add `achievements: Dictionary` to GameManager + `unlock_achievement(id, title, desc)`. Persist in save data. Signal `achievement_unlocked(id, title, desc)`. Define 10 achievement IDs in a constant dict.

### 5.8 Achievement popup UI
- [ ] Create `scenes/ui/achievement_popup.tscn` — slides in from bottom-right, 3s display, shows title + desc + icon. Triggered by `achievement_unlocked` signal.

### 5.9 Wire achievement triggers
- [ ] Wire the 10 achievement IDs to actual game events: first kill, first death, first puzzle solved, chapter complete (5 achievements), boss defeat (5 achievements), max combo >= 10, all lore docs found.

---

## PASS 6: FINAL SHIP
# Tag and ship.

### 6.1 Final MCP smoke test all chapters
- [ ] Run_project via Godot MCP for each chapter. Confirm zero new runtime errors. Capture screenshots of polished state.

### 6.2 Build final Windows export
- [ ] Run export script. Capture output. Verify .exe launches + plays cleanly.

### 6.3 Tag V2.1 release
- [ ] Write summary at top of TASKS.md CURRENT STATUS. Commit any final changes. Note tag message "V2.1 — release-ready with real audio".
