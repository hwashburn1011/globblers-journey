# GLOBBLER'S JOURNEY — BUILD TRACKER
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the first non-complete item ([ ] or [~]) you find.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude Opus — 2026-04-02
- **Last task completed:** Phase 1.1 (Project Structure), 1.2 (Globbler Character), 1.3 (Core Glob Engine) — all autoloads, components, CSG model, and folder structure
- **Next task to do:** 1.5 Basic Level Shell (test level with GlobTargets, lighting, spawn points)
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
- [~] Basic animation state machine: Idle, Walk, Run, Jump, Fall, Land — procedural bob implemented, full state machine deferred

### 1.3 Core Glob Engine
- [x] glob_engine.gd — singleton that pattern matches against all nodes with GlobTarget component
- [x] glob_target.gd — component script. Has export vars: tags (Array of strings), file_type (String), glob_name (String)
- [x] Pattern matching logic: support *.enemy, boss_*, *fire*, exact matches
- [x] Visual feedback: selected objects get green highlight (material swap via set_highlighted)
- [ ] Test: place 5 objects with GlobTarget in a test scene, verify glob patterns select correctly

### 1.4 HUD and UI
- [x] Create hud.tscn — overlay with: health bar, context window meter, current glob pattern display, ability cooldowns (scenes/ui/hud.tscn)
- [x] Green monospace font theme — all labels use green (#39FF14) on dark backgrounds
- [x] Context window meter — scenes/ui/context_window_bar.tscn with smooth lerp, color shifts at low HP
- [x] Dialogue box — scenes/ui/dialogue_box.tscn: terminal style, typing animation, click to advance, speaker tags
- [x] Glob pattern input display — scenes/ui/glob_pattern_input.tscn: blinking cursor, match count

### 1.5 Basic Level Shell
- [ ] Create a test level scene with ground plane, some walls, lighting
- [ ] Dark moody lighting with green accent lights and volumetric fog if supported
- [ ] Place Globbler spawn point
- [ ] Place a few GlobTarget test objects
- [ ] Place a test enemy (even just a capsule that moves)
- [ ] Verify: player can move around, camera works, HUD displays

---

## PHASE 2: CORE GAMEPLAY

### 2.1 Glob Command Ability
- [ ] Aim mode: hold button to show targeting reticle
- [ ] Glob beam visual: green energy beam/projectile from Globbler's hand
- [ ] On hit: calls glob_engine to select matching objects in radius
- [ ] Selected objects get green highlight
- [ ] Player can then: grab (pull toward), push (launch away), or absorb (collect)
- [ ] Cooldown system on ability use
- [ ] glob_beam.gdshader — green glowing energy shader

### 2.2 Wrench Smash
- [ ] Melee attack: swing wrench with hitbox
- [ ] Damage system: health_component.gd attachable to any node
- [ ] Hit feedback: screen shake, particles, knockback on enemy
- [ ] Can interact with mechanical puzzle elements (switches, gears)

### 2.3 Terminal Hack
- [ ] Interaction system: press button near hackable objects (hackable.gd component)
- [ ] Hack minigame UI: simple pattern matching or code completion puzzle
- [ ] Success: opens doors, disables traps, reprograms enemies
- [ ] Failure: triggers alarm or spawns enemies

### 2.4 Enemy Base System
- [ ] base_enemy.gd — CharacterBody3D with state machine: Patrol, Alert, Chase, Attack, Stunned, Death
- [ ] Navigation: basic pathfinding toward player
- [ ] Has GlobTarget component so enemies are globbable
- [ ] Drop system: drops tokens and parameter pickups on death
- [ ] Health component with damage and death

### 2.5 First Enemy Types (Chapter 1)
- [ ] Regex Spider — moves erratically, shoots pattern traps that slow player
- [ ] Zombie Process — slow, tanky, keeps respawning unless you kill the parent process node
- [ ] Corrupted Shell Script — fast, fragile, attacks in scripted sequences

### 2.6 Puzzle Framework
- [ ] base_puzzle.gd — states: Locked, Active, Solved, Failed. Emits signals.
- [ ] Glob pattern puzzle: terminal shows a pattern, player must glob the correct objects
- [ ] Hack puzzle: simple code-completion minigame
- [ ] Physical puzzle: move blocks, redirect beams, etc.

### 2.7 Save and Load
- [ ] save_system.gd autoload — saves to user:// directory
- [ ] Save: player position, health, context meter, completed puzzles, current chapter, inventory
- [ ] Auto-save at checkpoints
- [ ] Load from main menu

---

## PHASE 3: CHAPTER 1 — THE TERMINAL WASTES

### 3.1 Level Design
- [ ] Terminal Wastes environment: crumbling server racks, floating command prompts, rivers of scrolling green text
- [ ] 4-6 rooms/areas connected by corridors
- [ ] Environmental storytelling: scattered terminal logs, old error messages, deprecated code comments
- [ ] Checkpoints (auto-save triggers)

### 3.2 Chapter 1 Puzzles (3-5 total)
- [ ] Tutorial glob puzzle: match *.txt to open the first door
- [ ] Multi-pattern puzzle: glob different file types in sequence
- [ ] Hack puzzle: fix a broken bash script to restore power
- [ ] Physics puzzle: redirect data streams using glob to move objects
- [ ] Optional hard puzzle: recursive glob challenge with nested directories

### 3.3 Chapter 1 Boss: rm -rf /
- [ ] Boss arena: the floor is a file system that gets deleted in waves
- [ ] Boss behavior: massive deletion entity, erases platforms, spawns delete waves
- [ ] Player must glob-select safe platforms and avoid deletion zones
- [ ] Multi-phase: phase 1 dodge, phase 2 counter-attack by globbing his own delete commands back at him, phase 3 hack his core
- [ ] Victory cutscene and dialogue

### 3.4 Chapter 1 Dialogue
- [ ] Opening narration: Globbler wakes up in the Terminal Wastes
- [ ] NPC encounters: at least 2 friendly characters (old deprecated programs)
- [ ] Globbler quips during gameplay (triggered by events)
- [ ] Narrator sarcastic commentary on death, puzzle solving, boss encounters
- [ ] Chapter 1 ending dialogue

### 3.5 Chapter 1 Audio
- [ ] Background music: synthwave/cyberpunk with glitchy elements
- [ ] Ambient sounds: server hum, cooling fans, data processing
- [ ] Globbler SFX: footsteps, jump, glob beam fire, wrench swing, damage taken
- [ ] Enemy SFX: alert sound, attack, death
- [ ] Puzzle SFX: success jingle, failure buzzer
- [ ] Boss music: intense variant of chapter theme

---

## PHASE 4: SYSTEMS POLISH

### 4.1 Agent Spawn Ability
- [ ] Unlocked after Chapter 1
- [ ] Spawns mini-Globbler sub-agents (tiny CSG versions)
- [ ] Sub-agents perform simple tasks: fetch items, distract enemies, press distant buttons
- [ ] They frequently fail in funny ways (walk into walls, get confused, insult the player)
- [ ] Limited uses, recharges over time

### 4.2 Progression System
- [ ] Token currency from enemies and exploration
- [ ] Parameter pickups: upgrade materials
- [ ] Upgrade menu: improve glob range, wrench damage, context window size, ability cooldowns
- [ ] New glob patterns unlocked per chapter (wildcards, recursion, regex)

### 4.3 Main Menu
- [ ] Title screen with Globbler model and green terminal aesthetic
- [ ] New Game, Continue, Settings, Quit
- [ ] Settings: volume, controls, display
- [ ] Chapter select (unlocked chapters only)

### 4.4 Loading Screens
- [ ] Sarcastic loading tips (at least 20)
- [ ] Green progress bar with terminal aesthetic
- [ ] Random Globbler idle animations or art

### 4.5 Visual Polish
- [ ] Green glow shader on all Globbler elements and interactive objects
- [ ] CRT/scanline shader on terminal screens in-world
- [ ] Glitch shader on corrupted enemies
- [ ] Particle effects: green data particles in air, sparks from wrench, binary rain
- [ ] Post-processing: bloom on green elements, subtle chromatic aberration, vignette

### 4.6 Sound Design Pass
- [ ] Review all SFX for consistency
- [ ] Add UI sounds: menu navigation, button clicks, dialogue advance
- [ ] Glob command: satisfying whoosh-lock on match, error buzzer on no match
- [ ] Ambient layering per area

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
