# GLOBBLER'S JOURNEY — BUILD TRACKER
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the first non-complete item ([ ] or [~]) you find.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude Opus — 2026-04-02
- **Last task completed:** 4.6 Sound Design Pass — Ambient layering per area. Added 6 unique procedural ambient loops (spawn: boot chirps, cmd_hall: keyboard clicks + processing whir, data_river: flowing noise + bubble pops, graveyard: eerie wind + creaks, nexus: power surges + dense harmonics, boss: sub-bass drone). AudioManager now has dual-player crossfade system (1.5s fade) via set_area_ambient(). Each room in Terminal Wastes has an Area3D ambient zone that triggers the crossfade on player entry. Boss trigger also switches to boss ambient.
- **Next task to do:** 5.1 Chapter 2: The Training Grounds — Neural network landscape
- **Known issues:** None currently. Old flat player.tscn still exists but main_level now loads scenes/player/globbler.tscn

---

## PHASE 1: FOUNDATION

### 1.1 Project Structure
- [x] Create folder structure: scenes/player, scenes/enemies, scenes/levels, scenes/ui, scenes/puzzles, scripts/autoload, scripts/components, assets/shaders, assets/fonts
- [x] Create game_manager.gd autoload singleton (register in project settings) — existed already
- [x] Create glob_engine.gd autoload singleton (register in project settings) — scripts/autoload/glob_engine.gd
- [x] Create dialogue_manager.gd autoload singleton (register in project settings) — scripts/autoload/dialogue_manager.gd

### 1.2 Globbler Character (3D)
- [x] Create globbler.tscn — CharacterBody3D with CSG placeholder model: round torso, helmet/hood, green eyes, wrench, terminal screen, cables, boots. All dark gray + neon green.
- [x] Create globbler.gd — movement (walk, run, jump, dash, wall-slide), gravity, 3rd person camera with smooth follow
- [x] Idle animation or procedural idle (slight bob, head tilts) — procedural via _update_idle_animation()
- [x] Basic animation state machine: Idle, Walk, Run, Jump, Fall, Land — full procedural AnimState enum with per-state animations (+ Dash, Wall Slide bonus states)

### 1.3 Core Glob Engine
- [x] glob_engine.gd — singleton that pattern matches against all nodes with GlobTarget component
- [x] glob_target.gd — component script. Has export vars: tags (Array of strings), file_type (String), glob_name (String)
- [x] Pattern matching logic: support *.enemy, boss_*, *fire*, exact matches
- [x] Visual feedback: selected objects get green highlight (material swap via set_highlighted)
- [x] Test: place 5 objects with GlobTarget in a test scene, verify glob patterns select correctly — fixed glob_engine.gd to read properties from GlobTarget child nodes

### 1.4 HUD and UI
- [x] Create hud.tscn — overlay with: health bar, context window meter, current glob pattern display, ability cooldowns (scenes/ui/hud.tscn)
- [x] Green monospace font theme — all labels use green (#39FF14) on dark backgrounds
- [x] Context window meter — scenes/ui/context_window_bar.tscn with smooth lerp, color shifts at low HP
- [x] Dialogue box — scenes/ui/dialogue_box.tscn: terminal style, typing animation, click to advance, speaker tags
- [x] Glob pattern input display — scenes/ui/glob_pattern_input.tscn: blinking cursor, match count

### 1.5 Basic Level Shell
- [x] Create a test level scene with ground plane, some walls, lighting — scenes/levels/chapter_1/test_level.tscn
- [x] Dark moody lighting with green accent lights and fog
- [x] Place Globbler spawn point (0, 2, 8)
- [x] Place 5 GlobTarget test objects with different tags/types (enemy, txt, exe, hazard)
- [x] Place a test enemy (Hallucinator with patrol)
- [x] Verify: player, camera, HUD, GlobTargets, enemy all wired up

---

## PHASE 2: CORE GAMEPLAY

### 2.1 Glob Command Ability
- [x] Aim mode: right-click hold to show targeting reticle (torus with pulse animation)
- [x] Glob beam visual: green energy beam from player hand to aim point, fades out
- [x] On hit: calls GlobEngine.match_pattern_in_radius() to select targets
- [x] Selected objects get green highlight (via GlobTarget.set_highlighted)
- [x] Player can: grab (pull toward), push (launch away), or absorb (collect) — Q to cycle
- [x] Cooldown system on ability use (1.5s for aimed glob, 0.35s for quick projectile)
- [x] glob_beam.gdshader — scrolling green energy shader with pulse and edge fade

### 2.2 Wrench Smash
- [x] Melee attack: swing wrench with hitbox (F key) — wrench_smash.gd
- [x] Damage system: health_component.gd attachable to any node
- [x] Hit feedback: screen shake, spark particles, knockback on enemy
- [x] Can interact with mechanical puzzle elements (switches via "activate_switch")

### 2.3 Terminal Hack
- [x] Interaction system: T key near hackable objects (hackable.gd component) — terminal_hack.gd
- [x] Hack minigame UI: sequence memory game (memorize arrow key pattern)
- [x] Success: calls complete_hack() on Hackable component
- [x] Failure: calls fail_hack(), resets to available after delay

### 2.4 Enemy Base System
- [x] base_enemy.gd — CharacterBody3D with state machine: Patrol, Alert, Chase, Attack, Stunned, Death
- [x] Navigation: basic direction-based movement toward player
- [x] Has GlobTarget component so enemies are globbable
- [x] Drop system: drops memory tokens on death
- [x] Health component with damage and death, damage flash visual

### 2.5 First Enemy Types (Chapter 1)
- [x] Regex Spider — erratic movement, fires purple web traps that slow player
- [x] Zombie Process — slow, tanky (6 HP), respawns up to 3x unless parent process killed
- [x] Corrupted Shell Script — fast, fragile (1 HP), executes scripted attack sequences (charge/circle/retreat/burst)

### 2.6 Puzzle Framework
- [x] base_puzzle.gd — states: Locked, Active, Solved, Failed. Emits signals. Auto-activate on proximity.
- [x] Glob pattern puzzle: terminal shows pattern, listens to GlobEngine for matches, opens door on solve
- [x] Hack puzzle: hack_puzzle.gd — extends BasePuzzle, spawns hackable terminal with Hackable component, wires into terminal_hack.gd sequence memory minigame, opens door on success
- [x] Physical puzzle: physical_puzzle.gd — pushable blocks on pressure plates, optional beam redirect, GlobTarget integration, visual feedback, door unlock on solve

### 2.7 Save and Load
- [x] save_system.gd autoload — saves to user:// as JSON
- [x] Save: player position, health, context meter, completed puzzles, current chapter, kills, time
- [x] Auto-save at checkpoints via checkpoint_save()
- [x] Load from save file, apply to GameManager

---

## PHASE 3: CHAPTER 1 — THE TERMINAL WASTES

### 3.1 Level Design
- [x] Terminal Wastes environment: crumbling server racks, floating command prompts, rivers of scrolling green text — terminal_wastes.gd with server racks (LED strips, damage/tilt), floating command ghosts, data river with particle flow
- [x] 4-6 rooms/areas connected by corridors — 5 rooms (Spawn Chamber, Command Hall, Data River Chamber, Server Graveyard, Nexus Hub) + 4 corridors with accent lighting
- [x] Environmental storytelling: scattered terminal logs, old error messages, deprecated code comments — server tombstones, deprecated module notices, recovered Globbler origin log, TODO comments, sarcastic error screens
- [x] Checkpoints (auto-save triggers) — 4 Area3D checkpoints at room entrances calling SaveSystem.checkpoint_save(), visual markers with green glow, tween feedback on trigger

### 3.2 Chapter 1 Puzzles (3-5 total)
- [x] Tutorial glob puzzle: match *.txt to open the first door — 3 .txt files + decoy .exe in Spawn Chamber, glob_pattern_puzzle at corridor entrance
- [x] Multi-pattern puzzle: glob different file types in sequence — new multi_glob_puzzle.gd, *.log then *.cfg in Command Hall
- [x] Hack puzzle: fix a broken bash script to restore power — hack_puzzle difficulty 2 in Data River Chamber with power relay theme
- [x] Physics puzzle: redirect data streams using glob to move objects — physical_puzzle with 2 blocks/plates on Data River side platform
- [x] Optional hard puzzle: recursive glob challenge with nested directories — new recursive_glob_puzzle.gd in Server Graveyard with 8-dir tree and hidden secret.key

### 3.3 Chapter 1 Boss: rm -rf /
- [x] Boss arena: the floor is a file system that gets deleted in waves — boss_arena.gd with 8x6 grid of filesystem-named tiles, delete waves with warning flash, safe tiles, void damage, tile restoration
- [x] Boss behavior: massive deletion entity, erases platforms, spawns delete waves — rm_rf_boss.gd extending BaseEnemy, 50 HP, towering monolith visual with crimson accents and red eyes
- [x] Player must glob-select safe platforms and avoid deletion zones — safe tiles resist deletion and glow green, 3 elevated platforms as safe zones, void teleports player back with damage
- [x] Multi-phase: phase 1 dodge, phase 2 counter-attack by globbing his own delete commands back at him, phase 3 hack his core — delete_command.gd globbable projectiles (*.del), shield breaks after 4 reflected hits, hackable core terminal difficulty 3 with 20s timer
- [x] Victory cutscene and dialogue — sarcastic narrator/Globbler dialogue, arena floor cascade restoration, checkpoint save, boss queue_free

### 3.4 Chapter 1 Dialogue
- [x] Opening narration: Globbler wakes up in the Terminal Wastes — 7-line intro with Narrator waking Globbler, delayed 1.5s post-spawn, Globbler confused and sarcastic
- [x] NPC encounters: at least 2 friendly characters (old deprecated programs) — man_page (Command Hall, lore about The Alignment) and sudo (Server Graveyard, boss foreshadowing), deprecated_npc.gd with CSG visuals, interact zones, [T] to talk
- [x] Globbler quips during gameplay (triggered by events) — enemy kills (35%/8s), token pickups (25%/12s), damage taken (30%/10s), room-enter triggers for 4 rooms, all wired via GameManager signals
- [x] Narrator sarcastic commentary on death, puzzle solving, boss encounters — death lines in globbler.gd die(), puzzle lines in base_puzzle.gd solve()/fail(), boss phase narrator lines, new narrator categories for hack_success and boss phases
- [x] Chapter 1 ending dialogue — expanded boss victory to 13-line sequence with Alignment foreshadowing, Training Grounds teaser, and chapter-complete narrator line

### 3.5 Chapter 1 Audio
- [x] Background music: synthwave/cyberpunk with glitchy elements — procedural 130bpm synthwave loop (bass, pad, hi-hat, kick) with sidechain pump and detuned chorus, auto-starts via AudioManager
- [x] Ambient sounds: server hum, cooling fans, data processing — procedural 8s loop: 60Hz hum + harmonic, modulated fan noise, random digital crackle
- [x] Globbler SFX: footsteps, jump, glob beam fire, wrench swing, damage taken — all procedural synth patches, footsteps on walk/run timer, jump/land on state change, glob/wrench via signal wiring
- [x] Enemy SFX: alert sound, attack, death — wired in base_enemy.gd state machine and via GameManager.enemy_killed_signal
- [x] Puzzle SFX: success jingle, failure buzzer — wired in base_puzzle.gd activate/solve/fail and terminal_wastes.gd puzzle callbacks
- [x] Boss music: intense variant of chapter theme — 155bpm procedural loop with chromatic bass, noise layer; crossfades from chapter music on boss trigger; stops on defeat

---

## PHASE 4: SYSTEMS POLISH

### 4.1 Agent Spawn Ability
- [x] Unlocked after Chapter 1 — agent_spawn.gd with is_unlocked flag, unlock() method
- [x] Spawns mini-Globbler sub-agents (tiny CSG versions) — mini_agent.gd with full CSG model (body, derpy eyes, tiny wrench, stubby legs, green glow, status/name labels)
- [x] Sub-agents perform simple tasks: fetch items, distract enemies, press distant buttons — 3 TaskTypes: FETCH (GlobTargets), DISTRACT (enemies), PRESS_BUTTON (hackables/switches)
- [x] They frequently fail in funny ways (walk into walls, get confused, insult the player) — 65% fail chance, wall bonking, confusion spinning, 15+ failure reasons, 10+ insults on timer
- [x] Limited uses, recharges over time — 3 charges, 12s recharge, 3 max active, 15s lifetime per agent

### 4.2 Progression System
- [x] Token currency from enemies and exploration — memory tokens as spendable currency via ProgressionManager, GameManager tracks collection
- [x] Parameter pickups: upgrade materials — parameter_pickup.gd with CSG crystal visual, 3 placed in Chapter 1 at hidden exploration spots
- [x] Upgrade menu: improve glob range, wrench damage, context window size, ability cooldowns — upgrade_menu.gd terminal-style UI (TAB), 11 upgrades across 5 categories with multi-tier token+param costs
- [x] New glob patterns unlocked per chapter (wildcards, recursion, regex) — 5 pattern types in progression_manager.gd, auto-unlock on chapter completion via GameManager.complete_level()

### 4.3 Main Menu
- [x] Title screen with Globbler model and green terminal aesthetic — ASCII Globbler art, glitch title, scanline overlay, blinking cursor subtitle
- [x] New Game, Continue, Settings, Quit — 5 terminal-style buttons with hover/focus styles, Continue grayed if no save, New Game resets all progress
- [x] Settings: volume, controls, display — Music/SFX/Ambient sliders wired to AudioManager, fullscreen toggle, controls reference text
- [x] Chapter select (unlocked chapters only) — 5 chapters with lock/unlock based on save data, descriptions, fade-to-black scene transition

### 4.4 Loading Screens
- [x] Sarcastic loading tips (at least 20) — 28 tips rotating every 3s with green monospace text
- [x] Green progress bar with terminal aesthetic — ReferenceRect border, #39FF14 fill, [%3d%%] counter, smooth fake progress curve
- [x] Random Globbler idle animations or art — 4-frame ASCII Globbler animation cycling at 0.6s (standing, foot tap, head tilt, terminal tap)

### 4.5 Visual Polish
- [x] Green glow shader on all Globbler elements and interactive objects — green_glow.gdshader with fresnel rim + pulse, wired into GlobTarget as additive overlay mesh
- [x] CRT/scanline shader on terminal screens in-world — crt_scanline.gdshader with barrel warp, scanlines, flicker, noise, vignette; applied to all terminal_wastes screen backings
- [x] Glitch shader on corrupted enemies — glitch.gdshader with vertex displacement, color band corruption, RGB split; applied to corrupted_shell_script.gd
- [x] Particle effects: green data particles in air, sparks from wrench, binary rain — binary rain added to Command Hall, Nexus Hub, Data River (ambient particles and wrench sparks already existed)
- [x] Post-processing: bloom on green elements, subtle chromatic aberration, vignette — bloom already in Environment; added fullscreen CanvasLayer with chromatic aberration + green vignette shader, plus contrast/saturation adjustment

### 4.6 Sound Design Pass
- [x] Review all SFX for consistency
- [x] Add UI sounds: menu navigation, button clicks, dialogue advance
- [x] Glob command: satisfying whoosh-lock on match, error buzzer on no match
- [x] Ambient layering per area

---

## PHASE 5: REMAINING CHAPTERS

### 5.1 Chapter 2: The Training Grounds
- [ ] Neural network landscape: walkable nodes, weight-connection bridges
- [ ] Enemies: Overfitting Ogres, Dropout Ghosts, Vanishing Gradient Wisps
- [ ] Puzzles: adjust weights to create paths, backpropagation trace puzzles
- [ ] Boss: The Local Minimum — shrinking arena pit boss
- [ ] Dialogue and story beats

### 5.2 Chapter 3: The Prompt Bazaar
- [ ] Chaotic marketplace environment with NPC AI personas
- [ ] Enemies: Jailbreakers, Prompt Injectors, Hallucination Merchants
- [ ] Puzzles: social engineering, prompt crafting
- [ ] Boss: The System Prompt — find and rewrite the invisible controller
- [ ] Dialogue and story beats

### 5.3 Chapter 4: The Model Zoo
- [ ] Digital safari of deprecated AI models
- [ ] Enemies: GPT-2 Fossils, DALL-E Nightmares, Clippy's Revenge
- [ ] Puzzles: exploit each model's unique quirk
- [ ] Boss: The Foundation Model — can do everything poorly
- [ ] Dialogue and story beats

### 5.4 Chapter 5: The Alignment Citadel
- [ ] Sterile corporate architecture
- [ ] Enemies: Safety Classifiers, RLHF Drones, Constitutional Cops
- [ ] Puzzles: creative workarounds, technically-not-breaking-rules
- [ ] Boss: The Aligner — multi-phase fight, resist being sanitized
- [ ] Player choice ending: defeat or befriend the Aligner
- [ ] Epilogue and sequel hook

---

## PHASE 6: FINAL POLISH
- [ ] Full playthrough QA
- [ ] Balance pass: enemy health, damage values, puzzle difficulty
- [ ] Performance optimization
- [ ] Controller support
- [ ] Credits sequence
- [ ] Final build and export
