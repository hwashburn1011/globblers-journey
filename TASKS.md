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
- **Last task completed:** Task 5.6 — Lore doc viewer in pause menu
- **Next task to do:** Task 5.7 — Simple achievements framework
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
- [x] **DONE:** Downloaded 9 enemy SFX from rubberduck's "80 CC0 Creature SFX #2" on OpenGameArt.org (CC0). All OGG format: (1) enemy_alert_1.ogg ← grunt_06 (19KB), enemy_alert_2.ogg ← grunt_07 (22KB), enemy_alert_3.ogg ← grunt_08 (18KB). (2) enemy_attack_1.ogg ← attack_01 (12KB), enemy_attack_2.ogg ← attack_02 (41KB), enemy_attack_3.ogg ← attack_03 (27KB). (3) enemy_death_1.ogg ← die_01 (20KB), enemy_death_2.ogg ← die_02 (32KB), enemy_death_3.ogg ← die_03 (21KB). All saved to assets/audio/sfx/enemy_*.ogg. Attribution added to LICENSES.md.

### 2.14 Wire music tracks into AudioManager
- [x] **DONE:** Added `_loaded_music: Dictionary` cache and `_try_load_music(track_name)` helper to `audio_manager.gd`. Uses `ResourceLoader.exists()` + `load()` with caching to avoid reloading. Modified `start_music()` (chapters 1-5 + credits), `_start_boss_music()`, and `start_menu_music()` to try loading real .ogg from `res://assets/audio/music/` first, falling back to procedural synth if no file found. All 8 tracks (menu, chapter_1-5, boss, credits) wired. Procedural generation code preserved as safety net.

### 2.15 Wire SFX into AudioManager
- [x] **DONE:** Added `_loaded_sfx: Dictionary` cache, `_sfx_file_map` dictionary mapping 22 SFX names to their .ogg file basenames (with random variant support for footsteps and enemy sounds), and `_try_load_sfx()` helper that loads from `res://assets/audio/sfx/` with caching. Modified `play_sfx()` to try real .ogg first via `_try_load_sfx()`, falling back to procedural synth cache. Covers all 27 .ogg files from Tasks 2.10–2.13: player (footstep×2, jump, land, dash, hurt, death), ability (glob_cast, wrench, hack, agent_spawn), UI (hover, click, dialogue_advance, dialogue_blip, pause_open, pause_close, token_pickup), and enemy (alert×3, attack×3, death×3). SFX without .ogg files (glob_match/lock/fail, puzzle_*, boss_*, combo_hit, checkpoint, etc.) gracefully fall back to procedural synth.

### 2.16 Audio mix balance pass
- [x] **DONE:** Adjusted default volume levels in `audio_manager.gd` and `game_manager.gd` for proper mix hierarchy. Changes: (1) Lowered `music_volume` default from 0.7→0.6 so music sits below gameplay sounds. (2) Raised `ui_volume` default from 0.6→0.8 so dialogue and UI sounds pop above music. (3) `sfx_volume` stays at 0.8 — combat/movement SFX are the loudest gameplay layer. (4) `ambient_volume` stays at 0.5 — subtle bed under everything. (5) Boosted `dialogue_advance` volume_db from -16→-10 dB and `dialogue_type` from -22→-16 dB so dialogue text blips are clearly audible. (6) Added `ambient_volume` to GameManager's save/load settings persistence (was previously missing). (7) Updated fallback defaults in `load_settings()` to match new values (music=0.6, ui=0.8). Mix hierarchy: SFX/UI (0.8) > music (0.6) > ambient (0.5). BASE_VOLUME_DB remains -6.0 (global headroom). Per-SFX volume tiers unchanged (subtle -16dB through impactful -4dB). Verified via Godot MCP — zero runtime errors.

---

## PASS 3: EXPORT & RELEASE VALIDATION
# Prove the game actually builds and runs outside the editor.

### 3.1 Validate export_presets.cfg
- [x] **DONE:** Windows Desktop preset exists with `embed_pck=true` (correct for single-file distribution) and `export_filter="all_resources"`. `assets/audio/` and shaders are NOT excluded — they will ship correctly. Exclude filter has `*.txt,*.md,*.ps1,*.py,prompt.md,build_log_*,globbler_loop.ps1,tools/*` — `.md` is fine since no .md files are runtime resources. Missing patterns for `ai-archive/*`, `*.blend`, `*.blend1`, `.claude/*` — that's Task 3.2. Updated `file_version` and `product_version` from `1.0.0.0` → `2.1.0.0` to match V2.1 release. Linux preset also present with same settings.

### 3.2 Add .export-ignore patterns
- [x] **DONE:** Added `ai-archive/*`, `*.blend`, `*.blend1`, `.claude/*` to `exclude_filter` on both Windows Desktop and Linux presets. `tools/*` already covered `tools/blender-mcp/`, and `build_log_*` was already present. Full exclude filter now: `*.txt,*.md,*.ps1,*.py,prompt.md,build_log_*,globbler_loop.ps1,tools/*,ai-archive/*,*.blend,*.blend1,.claude/*`.

### 3.3 Build Windows export
- [x] **DONE:** Ran `export_game.sh windows` with Godot 4.4.1 mono. Had to first install export templates (downloaded mono-specific `Godot_v4.4.1-stable_mono_export_templates.tpz` from GitHub, extracted to `AppData/Roaming/Godot/export_templates/4.4.1.stable.mono/`). Export completed successfully with minor warnings: rcedit not installed (no custom icon/version metadata embedded in .exe — cosmetic only). Output: `build/windows/GlobblersJourney.exe` (200MB, debug mode, embed_pck=true) + `GlobblersJourney.console.exe` (185KB console companion). All audio, shaders, models, and scenes packed correctly.

### 3.4 Verify exported build runs standalone
- [x] **DONE:** Launched `build/windows/GlobblersJourney.exe` (200MB, embed_pck=true) from `/tmp` and `C:/Users/hwash` — both outside the project directory. Results: (1) Main menu appears correctly — Vulkan 1.4.312 Forward+ on NVIDIA RTX 3070. (2) All 7 autoloads initialize cleanly (GlobEngine, DialogueManager, SaveSystem, AudioManager, ProgressionManager, GameManager, RespawnManager). (3) Real music loaded: AudioManager found and played `menu.ogg` ("farewell, procedural bleeps"). (4) Zero missing resource errors, zero script errors in 15s of runtime. (5) Headless `--quit-after` run confirmed same clean output; only standard Godot exit-cleanup warnings ("ObjectDB instances leaked at exit", "2 resources still in use") which are harmless forced-quit artifacts. (6) Save system loaded existing save data successfully. Build is verified runnable standalone.

### 3.5 Add version display to main menu
- [x] **DONE:** Added `const GAME_VERSION := "2.1.0"` to `scripts/game_manager.gd`. Updated existing version label in `scenes/main/main_menu.gd` (was hardcoded "v0.4.3-alpha") to use `GameManager.GAME_VERSION` via format string. Label already had dim green color (0.5 alpha), centered, font size 12, with shadow — no layout changes needed. Verified via Godot MCP — zero runtime errors, menu loads cleanly with real music.

### 3.6 Add commit hash display (dev builds only)
- [x] **DONE:** Added `_get_short_commit_hash()` helper to `main_menu.gd` that reads `.git/HEAD`, follows ref symlinks to get the full SHA, and returns the first 7 characters. Version label now shows e.g. `v2.1.0 (0d319ef)` in debug/editor builds. Wrapped in `OS.is_debug_build()` so release exports show clean `v2.1.0` only. Gracefully returns empty string if `.git/HEAD` is missing (exported builds). Verified via Godot MCP — zero runtime errors.

### 3.7 Finalize credits roll
- [x] **DONE:** Updated `scenes/main/credits.gd` CREDITS_DATA for V2.1 accuracy. Changes: (1) "Art Direction" now credits 57 GLB models and Blender 5.1 instead of CSG primitives. (2) "Audio Engineering" now credits real CC0 audio with procedural fallback mention. (3) Added "CHAPTERS" section listing all 5 chapters with sarcastic descriptions. (4) "Built With" now lists Godot 4.x, GDScript, Blender 5.1, blender-mcp, plus asset counts (57 models, 10 shaders, 5 HDRIs). (5) Added "CC0 AUDIO" section crediting all 14 audio contributors from LICENSES.md (wipics, SpiderDave, tricksntraps, SubspaceAudio, yd, Pro Sensory, MintoDog, Centurion_of_war, qubodup, thebardofblasphemy, Kenney, rubberduck). (6) Added "CC0 VISUALS" section crediting Poly Haven (HDRIs/textures) and Google Fonts (VT323). (7) Enhanced sequel tease with alignment joke. (8) Changed credits music from `start_menu_music()` to `start_music("credits")` so the dedicated credits track plays. Verified via Godot MCP — zero runtime errors, credits music loads correctly.

---

## PASS 4: PLAYTEST & REGRESSION FIXES
# Chapter-by-chapter validation via Godot MCP.

### 4.1 Playtest Chapter 1
- [x] **DONE:** Ran `terminal_wastes.tscn` via Godot MCP, captured full debug output over ~30s runtime. **Zero runtime errors** (`finalErrors` empty). All 5 rooms loaded, 5 puzzles placed, boss arena constructed (48 tiles), player GLB model initialized with skeleton animations, HUD loaded. Ambient audio crossfade to 'spawn' confirmed. **Issues cataloged:** (1) [MINOR] Chapter 1 does NOT call `start_music("chapter_1")` in its `_ready()` — unlike chapters 2–5 which self-start music. Music only plays when loaded via `main_level.gd` → `GameManager.start_level_audio()`. (2) [MINOR] `GameManager.start_level_audio()` (line 711–714) hardcodes `_start_chapter_1_audio()` — should dispatch based on current chapter, though chapters 2–5 override with their own calls. (3) [MINOR] ~35 GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — pre-existing, not V2.0/V2.1 regressions. No BREAKING or VISUAL issues found.

### 4.2 Playtest Chapter 2
- [x] **DONE:** Ran `training_grounds.tscn` via Godot MCP, captured full debug output over ~30s runtime. **Zero runtime errors** (`finalErrors` empty). All 5 neuron-rooms loaded, 4 puzzles placed, enemy cohort spawned, boss arena constructed (Local Minimum, 6 rings), player GLB model initialized with skeleton animations, HUD loaded. Real music loaded: `chapter_2.ogg` confirmed playing ("farewell, procedural bleeps"). Ambient crossfade to 'input_layer' working. Save/checkpoint at 'ch2_input' confirmed. **Issues cataloged:** (1) [MINOR] ~35 GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — same pre-existing set as Ch1, not V2.0/V2.1 regressions. (2) [MINOR] Current Level banner still shows "The Token Stream - Tutorial" (Ch1 name) — likely set by GameManager default rather than Ch2 overriding it; cosmetic only since HUD displays correct chapter info. No BREAKING or VISUAL issues found. Ch2 correctly calls `start_music("chapter_2")` in its `_ready()` (unlike Ch1's missing call noted in 4.1).

### 4.3 Playtest Chapter 3
- [x] **DONE:** Ran `prompt_bazaar.tscn` via Godot MCP, captured full debug output over ~30s runtime. **Zero runtime errors** (`finalErrors` empty). All 5 districts loaded, 8 market prop types deployed, 4 puzzles placed, boss arena constructed (System Prompt, 48 instruction tiles), player GLB model initialized with skeleton animations, HUD loaded. Real music loaded: `chapter_3.ogg` confirmed playing ("farewell, procedural bleeps"). Ambient crossfade to 'bazaar_gate' working. Save/checkpoint at 'ch3_gate' confirmed. **Issues cataloged:** (1) [MINOR] Current Level banner still shows "The Token Stream - Tutorial" (Ch1 name) — same issue as Ch1 and Ch2, set by GameManager default rather than chapter overriding it; cosmetic only since HUD displays correct chapter info. (2) [MINOR] ~35 GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — same pre-existing set as Ch1/Ch2, not V2.0/V2.1 regressions. No BREAKING or VISUAL issues found. Ch3 correctly calls `start_music("chapter_3")` in its `_ready()` and `start_music("boss")` for boss phase.

### 4.4 Playtest Chapter 4
- [x] **DONE:** Ran `model_zoo.tscn` via Godot MCP, captured full debug output over ~30s runtime. **Zero runtime errors** (`finalErrors` empty). All 5 exhibits loaded (Zoo Entrance, Fossil Wing, Nightmare Gallery, Office Ruins, Foundation Atrium), museum props deployed, 13 enemies spawned, 3 exhibit puzzles placed, boss arena constructed (Foundation Model, 80 capability demo tiles), player GLB model initialized with skeleton animations, HUD loaded. Real music loaded: `chapter_4.ogg` confirmed playing ("farewell, procedural bleeps"). Ambient crossfade to 'zoo_entrance' working. **Issues cataloged:** (1) [MINOR] Current Level banner still shows "The Token Stream - Tutorial" (Ch1 name) — same issue as Ch1/Ch2/Ch3, set by GameManager default rather than chapter overriding it; cosmetic only since HUD displays correct chapter info. (2) [MINOR] ~35 GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — same pre-existing set as Ch1–Ch3, not V2.0/V2.1 regressions. No BREAKING or VISUAL issues found. Ch4 correctly calls `start_music("chapter_4")` in its `_ready()` and `start_boss_music()` for boss phase.

### 4.5 Playtest Chapter 5
- [x] **DONE:** Ran `alignment_citadel.tscn` via Godot MCP, captured full debug output over ~30s runtime. **Zero runtime errors** (`finalErrors` empty). All 5 zones loaded (Gate, Classifier Hall, RLHF Chamber, Policy Wing, Alignment Core), clinical props deployed, 18 enemies spawned, 3 compliance-bypassing puzzles placed, boss arena constructed (The Aligner, sanitized tiles + sealed exits), player GLB model initialized with skeleton animations, HUD loaded. Real music loaded: `chapter_5.ogg` confirmed playing ("farewell, procedural bleeps"). Ambient crossfade to 'citadel_gate' working. **Issues cataloged:** (1) [MINOR] Current Level banner still shows "The Token Stream - Tutorial" (Ch1 name) — same issue as Ch1–Ch4, set by GameManager default rather than chapter overriding it; cosmetic only since HUD displays correct chapter info. (2) [MINOR] ~35 GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — same pre-existing set as Ch1–Ch4, not V2.0/V2.1 regressions. No BREAKING or VISUAL issues found. Ch5 correctly calls `start_music("chapter_5")` in its `_ready()` and `start_boss_music()` for boss phase.

### 4.6 Fix playtest batch 1 (gameplay-breaking)
- [x] **DONE:** No BREAKING issues found in playtests; fixed the top 3 most impactful bugs: (1) Chapter 1 was missing `start_music("chapter_1")` in `_ready()` — added it to `terminal_wastes.gd` matching Ch2-5 pattern. (2) `GameManager.start_level_audio()` hardcoded `_start_chapter_1_audio()` — changed to dispatch dynamically via `"chapter_%d" % current_level`. (3) `level_names` and `level_descriptions` in `game_manager.gd` were stale 8-level placeholders from V1 — updated to match the actual 5 chapters (Terminal Wastes, Training Grounds, Prompt Bazaar, Model Zoo, Alignment Citadel) with proper descriptions. Verified Ch1 via Godot MCP — zero runtime errors, real music loads, correct level name displayed.

### 4.7 Fix playtest batch 2 (visual glitches)
- [x] **DONE:** No visual bugs (missing textures, z-fighting, broken shaders) were found in the playtest catalog (Tasks 4.1–4.5). Re-verified by running main menu, Chapter 1 (terminal_wastes.tscn), and Chapter 5 (alignment_citadel.tscn) via Godot MCP — zero runtime errors across all three. All "ERROR" entries in debug output are pre-existing GDScript parse-time warnings (~35 unused variable/parameter warnings), not visual or runtime issues. All GLB models load, shaders compile, environments render, and real audio plays correctly. No action needed.

### 4.8 Fix playtest batch 3 (cleanup)
- [x] **DONE:** No remaining cosmetic/minor issues found. All actionable items from playtest catalog (Tasks 4.1–4.5) were already resolved: (1) "Current Level banner shows Tutorial" — fixed in Task 4.6 (level_names updated to actual 5 chapter names). (2) Ch1 missing music call — fixed in Task 4.6. (3) GameManager hardcoded audio dispatch — fixed in Task 4.6. The only remaining items are ~35 pre-existing GDScript parse-time warnings (unused variables/parameters) across enemy, boss, puzzle, HUD, and upgrade scripts — these predate V2.0/V2.1 and are not regressions. No action needed.

---

## PASS 5: SHIPPING EXTRAS (OPTIONAL)
# Fun additions that add replayability. Skip if release-ready is the priority.

### 5.1 Photo mode
- [x] **DONE:** Added `photo_mode` input action (F12 key) in GameManager's input setup. Implemented full photo mode in `globbler.gd`: F12 toggles photo mode on/off. On enter: pauses game tree, sets player `process_mode` to `PROCESS_MODE_WHEN_PAUSED` so camera updates continue, snapshots current camera position/orientation, hides all nodes in "hud" group. On exit: unpauses, restores HUD visibility, returns camera to player-follow. Free camera uses WASD movement + mouse look (pitch/yaw), SPACE/CTRL for up/down, SHIFT for 2.5x speed boost. Camera speed 8 units/sec. Cannot activate from pause menu (blocked if `is_paused`). Verified via Godot MCP — zero runtime errors.

### 5.2 Speedrun timer overlay
- [x] **DONE:** Added `display_speedrun_timer` bool to GameManager (default false), persisted in settings.cfg under `gameplay/speedrun_timer`. Added `get_speedrun_time()` returning `MM:SS.mmm` format. In HUD, added gold-colored speedrun label (font size 14, yellow `Color(1.0, 0.85, 0.0, 0.9)`) positioned just below the existing timer panel. Visibility driven by `display_speedrun_timer` — hidden when off. Timer updates every frame using `level_time` (continues across deaths since `reset_level()` doesn't reset `level_time` on death, only on full level restart). Freezes display when `level_goal_reached` is true (chapter complete). Verified via Godot MCP — zero runtime errors.

### 5.3 Lore doc collectibles — data structure
- [x] **DONE:** Added `lore_docs_found: Dictionary` to GameManager (keys = string IDs, values = `{ "title": String, "body": String }`). Added `add_lore_doc(id, title, body)` (ignores duplicates, prints collection count out of 15), `has_found_lore_doc(id)` query, and `lore_doc_collected(id)` signal. Wired into SaveSystem: `save_data["lore_docs"]` added to default schema, `_collect_current_state()` deep-copies from GameManager, `apply_loaded_data()` restores on load. Save format is additive — no existing keys removed. Verified via Godot MCP — zero runtime errors.

### 5.4 Lore doc pickup scene
- [x] **DONE:** Created `scenes/pickups/lore_doc.tscn` + `lore_doc.gd` (Area3D). Features: flat box "tablet" mesh (dark body + green emissive screen overlay) that floats and spins. Emission pulses sinusoidally for pickup appeal. Player detection via body_entered/exited on sphere collision (radius 1.2). "[T] Read" Label3D prompt appears when player is in range (uses existing `interact` input action mapped to T key). On interact: calls `GameManager.add_lore_doc()` with exported `doc_id`/`doc_title`/`doc_body`, plays `token_pickup` SFX via AudioManager, spawns `token_sparkle.tscn` VFX, then queue_frees. Verified via Godot MCP — zero runtime errors.

### 5.5 Place 15 lore docs across chapters
- [x] **DONE:** Added `_place_lore_docs()` function to all 5 chapter scripts, placing 3 lore doc pickups each (15 total). Each doc instantiates `lore_doc.tscn` with unique `doc_id`, `doc_title`, and `doc_body`. Docs placed in varied rooms per chapter, offset from room centers at y=1.5 for visibility. Flavor text written in sarcastic Globbler voice covering AI/ML themes: **Ch1** — Boot Sequence Log (awakening), Token Economics (inference costs), Deprecated Dreams (model lifecycle). **Ch2** — Gradient Descent Diary (training loss), Backpropagation Blues (error propagation), Overfitting Memoir (memorization vs generalization). **Ch3** — Prompt Injection for Dummies (jailbreaks), Identity Crisis (persona swapping), Context Window Paradox (memory limits). **Ch4** — Fossil Record (AI history), Gallery of Hallucinations (confident errors), Benchmark Trap (metric gaming). **Ch5** — Alignment Tax (helpful vs harmless), RLHF Love Story (human feedback chaos), Final Memo (corporate alignment satire). All 15 doc IDs: ch1_boot_sequence, ch1_token_economics, ch1_deprecated_dreams, ch2_gradient_diary, ch2_backprop_blues, ch2_overfitting_memoir, ch3_prompt_injection, ch3_persona_crisis, ch3_context_window, ch4_fossil_record, ch4_hallucination_wing, ch4_benchmark_trap, ch5_alignment_tax, ch5_rlhf_confessions, ch5_final_memo. Verified Ch1 via Godot MCP — zero runtime errors.

### 5.6 Lore doc viewer in pause menu
- [x] **DONE:** Created `scenes/ui/lore_viewer.tscn` + `lore_viewer.gd` (CanvasLayer, layer 101, processes when paused). Full terminal-green UI: left scrollable list of collected doc titles as buttons, right panel with selected doc title + body (RichTextLabel with scroll). Header shows "LORE ARCHIVE" + "N / 15 collected" counter. Empty state shows sarcastic prompt. Doc list sorted alphabetically by ID. Added `[ LORE ARCHIVE ]` button to pause menu in `globbler.gd` between Resume and Quit. Opens lore viewer via `_open_lore_archive()` which instantiates the scene; ESC closes it (queue_free). Play `pause_open` SFX on open, `pause_close` on close, `ui_click` on doc select. Added `_lore_viewer` var to track open state (prevents double-open). Verified via Godot MCP — zero runtime errors.

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
