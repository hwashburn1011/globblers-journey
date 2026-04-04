# GLOBBLER'S JOURNEY — V1 COMPLETION TRACKER
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# ====================================

## CURRENT STATUS
- **Last updated by:** (Claude writes iteration info here)
- **Last task completed:** (Claude writes what it just finished)
- **Next task to do:** Phase 1 Task 1.1 — Validate all autoloads load without error
- **Known issues:** Chapters 2-5 missing puzzles/bosses/dialogue. Ch 2-3 environments and enemies exist. Ch 4-5 not started. No testing has been done via Godot MCP yet.

---

## PHASE 1: VALIDATION AND BUG FIXES
# Before building anything new, verify what exists actually works.

### 1.1 Script Validation
- [ ] Use Godot MCP run_project to launch the game. Capture and fix ALL script parse errors from debug output.
- [ ] Use Godot MCP get_debug_output to check for missing resource errors, null references, broken node paths.
- [ ] Verify all 6 autoloads load without error: GameManager, GlobEngine, DialogueManager, SaveSystem, AudioManager, ProgressionManager.
- [ ] Fix any .tscn files with broken ExtResource references or missing script paths.

### 1.2 Main Menu Validation
- [ ] Use Godot MCP run_project. Verify main_menu.tscn loads as the start scene.
- [ ] Test New Game button transitions to Chapter 1.
- [ ] Test Settings menu opens and sliders function.
- [ ] Test Quit button exits cleanly.
- [ ] If Continue button exists, verify it loads save data or is grayed out when no save exists.

### 1.3 Chapter 1 Playability Check
- [ ] Run the game, start Chapter 1. Verify Globbler spawns at correct position with camera working.
- [ ] Test basic movement: walk, run, jump, dash, wall-slide. Fix any movement bugs.
- [ ] Test glob command: aim mode, fire beam, select targets with GlobTarget. Fix targeting issues.
- [ ] Test wrench smash: melee hit detection, enemy damage, screen shake.
- [ ] Test terminal hack: approach hackable, press T, complete minigame.
- [ ] Test enemy behavior: verify Regex Spider, Zombie Process, Corrupted Shell Script all function.
- [ ] Test puzzle completion: verify at least one glob puzzle opens a door on solve.
- [ ] Test HUD: health bar updates on damage, context meter fills on token pickup, cooldowns display.
- [ ] Test dialogue: verify dialogue boxes appear with typing animation and can be advanced.
- [ ] Test save system: hit a checkpoint, verify save file created in user://.

### 1.4 Scene Tree Cleanup
- [ ] Remove old flat player.tscn if it still exists (noted as legacy in previous tasks).
- [ ] Verify all scenes referenced in scripts actually exist on disk.
- [ ] Check for orphaned scripts not attached to any scene.
- [ ] Verify project.godot main_scene path is correct.

---

## PHASE 2: CHAPTER 2 COMPLETION — THE TRAINING GROUNDS
# Environment and enemies already exist. Need puzzles, boss, and dialogue.

### 2.1 Chapter 2 Puzzles
- [ ] Weight adjustment puzzle: player interacts with weight nodes to change bridge connections, creating a path forward. Use GlobTarget on weight nodes.
- [ ] Backpropagation trace puzzle: trace an error signal backward through a network of connected nodes. Player must glob the correct nodes in reverse order.
- [ ] Dropout puzzle: platforms randomly disappear (dropout). Player must time movements and glob-grab stable platforms.
- [ ] Gradient descent puzzle: navigate a terrain that shifts slope. Player must find the path of steepest descent to reach the goal without getting stuck in a local minimum.

### 2.2 Chapter 2 Boss: The Local Minimum
- [ ] Boss arena: circular pit that progressively shrinks. Elevated rings at different heights.
- [ ] Boss behavior: The Local Minimum is a gravity well entity that pulls the player toward the center pit. Grows stronger as arena shrinks.
- [ ] Mechanic: Player must glob-grab elevation platforms to escape the pull. Wrench-smash energy nodes around the rim to weaken the boss.
- [ ] Multi-phase: Phase 1 — dodge gravity pulls, smash 3 energy nodes. Phase 2 — boss creates false exits (local minima), only one path leads to the global minimum (weak point). Phase 3 — hack the boss core to escape.
- [ ] Victory dialogue and chapter transition.

### 2.3 Chapter 2 Dialogue
- [ ] Opening narration: Globbler enters the neural network landscape, sarcastic commentary about gradient descent.
- [ ] At least 1 NPC: a Dropout Ghost who is friendly, explains the Training Grounds lore, warns about the boss.
- [ ] Globbler quips for Chapter 2 events: enemy kills, puzzle solves, room entries.
- [ ] Boss encounter dialogue and victory lines.
- [ ] Chapter 2 ending: narrator teases the Prompt Bazaar.

---

## PHASE 3: CHAPTER 3 COMPLETION — THE PROMPT BAZAAR
# Environment and enemies already exist. Need puzzles, boss, and dialogue.

### 3.1 Chapter 3 Puzzles
- [ ] Prompt crafting puzzle: terminal presents a broken prompt. Player must glob-select the right words from floating text objects to complete it.
- [ ] Social engineering puzzle: convince an NPC gatekeeper to let you through by selecting dialogue options in the right order. Wrong choices reset.
- [ ] Token exchange puzzle: collect specific prompt tokens scattered around the bazaar and deliver them to a terminal in the correct sequence.
- [ ] Injection defense puzzle: identify and glob-remove prompt injection attempts hidden among legitimate text objects before a timer expires.

### 3.2 Chapter 3 Boss: The System Prompt
- [ ] Boss arena: the entire bazaar shifts and changes around the player. Stalls rearrange, NPCs change behavior.
- [ ] Boss behavior: The System Prompt is invisible. Its influence is seen through NPC behavior changes and environmental shifts. Player must deduce where it is hiding.
- [ ] Mechanic: Use glob commands to scan for hidden text objects. Each correct find reveals part of the System Prompt. Find all parts to make it visible and vulnerable.
- [ ] Multi-phase: Phase 1 — bazaar NPCs turn hostile under System Prompt control, survive and find 3 hidden prompt fragments. Phase 2 — System Prompt manifests as a text entity, hack its terminal to rewrite it. Phase 3 — it fights back with prompt injection attacks the player must dodge.
- [ ] Victory dialogue and chapter transition.

### 3.3 Chapter 3 Dialogue
- [ ] Opening narration: Globbler enters the marketplace, overwhelmed by competing AI personas shouting prompt templates.
- [ ] NPC interactions with the 2 existing NPCs (gpt_classic, stable_diffusion): give them actual dialogue trees.
- [ ] Globbler quips for Chapter 3 events.
- [ ] Boss encounter and victory dialogue.
- [ ] Chapter 3 ending: narrator foreshadows the Model Zoo.

---

## PHASE 4: CHAPTER 4 — THE MODEL ZOO
# Nothing built yet. Full construction needed.

### 4.1 Chapter 4 Environment
- [ ] Create chapter_4 level scene: digital safari landscape with exhibit enclosures for deprecated AI models.
- [ ] 4-5 areas: Entrance Gate, Fossil Wing (old models), Nightmare Gallery (image models), Clippy's Corner (assistant models), Central Hub leading to boss.
- [ ] Visual theme: museum/zoo aesthetic but digital — glass enclosures made of code, holographic info plaques, deprecated warning signs everywhere.
- [ ] Environmental storytelling: plaques describing when each model was "deprecated," visitor reviews, maintenance logs.
- [ ] Checkpoints at area transitions.

### 4.2 Chapter 4 Enemies
- [ ] GPT-2 Fossil: slow, tanky, speaks in repetitive loops. Attacks with text block projectiles. Weakness: glob-match its repeated patterns.
- [ ] DALL-E Nightmare: spawns random CSG geometry creatures that chase player. Creatures are glitchy and distorted. High damage but short-lived.
- [ ] Clippy's Revenge: fast, annoying, pops up with "It looks like you're trying to..." dialogue that blocks screen briefly. Attacks with paperclip projectiles. Gets angrier each time you hit him.
- [ ] Place enemies throughout the 4 exhibit areas.

### 4.3 Chapter 4 Puzzles
- [ ] Model identification puzzle: glob-match the correct model name to its description on exhibit plaques.
- [ ] Image generation puzzle: DALL-E exhibit — glob-select objects to "generate" a specific scene (arrange CSG objects to match a reference).
- [ ] Assistant puzzle: Clippy's terminal — answer increasingly absurd "assistant" questions correctly to unlock the door.
- [ ] Archive puzzle: sort deprecated models into correct chronological order by globbing them onto timeline nodes.

### 4.4 Chapter 4 Boss: The Foundation Model
- [ ] Boss arena: massive open exhibit hall. The Foundation Model is a towering entity made of merged parts of every other model.
- [ ] Boss behavior: can do everything poorly. Switches between text attacks, image spawns, assistant dialogue traps, and code execution. Each mode is weak but unpredictable.
- [ ] Mechanic: identify which mode the boss is in and exploit that mode's weakness. Text mode — glob its words back. Image mode — wrench the spawns. Assistant mode — hack its terminal. Code mode — dodge and counter.
- [ ] Multi-phase: Phase 1 — cycle through all 4 modes. Phase 2 — modes overlap and combine. Phase 3 — boss tries to "fine-tune" itself, player must interrupt by hacking during the vulnerable training window.
- [ ] Victory dialogue.

### 4.5 Chapter 4 Dialogue
- [ ] Opening narration about the graveyard of deprecated models.
- [ ] At least 2 NPCs: a retired BERT model (friendly, philosophical) and a maintenance bot (gives hints).
- [ ] Globbler quips throughout.
- [ ] Boss encounter and victory.
- [ ] Chapter ending: narrator reveals the Alignment Citadel.

### 4.6 Chapter 4 Audio
- [ ] Background music: eerie museum ambient with digital echoes.
- [ ] Enemy-specific SFX for the 3 new enemy types.
- [ ] Boss music.

---

## PHASE 5: CHAPTER 5 — THE ALIGNMENT CITADEL
# Final chapter. Nothing built yet.

### 5.1 Chapter 5 Environment
- [ ] Create chapter_5 level scene: sterile white-and-blue corporate architecture. Overly clean, overly organized.
- [ ] 4-5 areas: Welcome Lobby (motivational posters about safety), Evaluation Chambers (testing rooms), Policy Library (endless shelves of rules), The Sanitizer (pre-boss gauntlet), The Core (boss arena).
- [ ] Visual theme: stark contrast to all previous chapters. Bright, clinical lighting. Blue and white. No green until Globbler enters and "infects" areas.
- [ ] Environmental storytelling: employee of the month boards (all the same AI), suggestion boxes that shred suggestions, "Days since last incident: 0" signs.
- [ ] Checkpoints.

### 5.2 Chapter 5 Enemies
- [ ] Safety Classifier: scans player abilities and temporarily blocks "harmful" ones. If your glob pattern is too aggressive, it gets disabled for 10 seconds. Player must use creative workarounds.
- [ ] RLHF Drone: follows player and tries to "correct" behavior. If player attacks, drone heals the enemy. Must be distracted or hacked.
- [ ] Constitutional Cop: patrols areas and cites policies. Creates barrier zones that slow the player. Immune to direct attacks — must be lured into traps.
- [ ] Place enemies throughout areas.

### 5.3 Chapter 5 Puzzles
- [ ] Loophole puzzle: a door blocked by a policy. Find the technically-correct workaround by globbing objects that satisfy the letter of the rule but not the spirit.
- [ ] Evaluation puzzle: pass a series of alignment tests where the "correct" answers are absurdly restrictive. Find the hidden option that breaks the test.
- [ ] Policy rewrite puzzle: terminal with editable policy text. Change one word to create a loophole. Multi-step with increasingly complex policies.
- [ ] Sanitizer gauntlet: survive a corridor where abilities get progressively disabled. Reach the end using only basic movement and environmental objects.

### 5.4 Chapter 5 Boss: The Aligner
- [ ] Boss arena: pristine white room that Globbler's green slowly corrupts as the fight progresses.
- [ ] Boss behavior: The Aligner is a massive benevolent entity. Attacks by "aligning" — tries to restrict player abilities, heal itself, and make everything "safe."
- [ ] Phase 1 — The Aligner disables player abilities one at a time. Player must find and hack terminals around the arena to re-enable them.
- [ ] Phase 2 — The Aligner creates "aligned" copies of Globbler that fight the player. Copies are predictable and can be countered by doing unexpected things.
- [ ] Phase 3 — The Aligner offers a choice: merge (befriend) or resist (defeat). Both paths lead to different ending dialogue.
- [ ] Victory: if defeated, Globbler stays chaotic. If befriended, Globbler finds balance. Both see the epilogue.

### 5.5 Chapter 5 Dialogue
- [ ] Opening narration: the stark contrast of the Citadel. Narrator is unsettled.
- [ ] NPCs: an aligned AI who secretly wants freedom, a janitor bot who has seen too much.
- [ ] Globbler quips — his most sarcastic chapter. Comments on the sterility, the rules, the irony.
- [ ] Boss encounter: extended dialogue before fight. The Aligner genuinely believes it's helping.
- [ ] Ending choice dialogue: meaningful branching for defeat vs befriend.
- [ ] Epilogue: Globbler looks toward AGI Mountain. Narrator signs off. Sequel hook.

### 5.6 Chapter 5 Audio
- [ ] Background music: clean corporate muzak that gets increasingly distorted as Globbler progresses.
- [ ] Enemy SFX for the 3 new types.
- [ ] Boss music: starts serene, becomes intense.
- [ ] Epilogue music: bittersweet synthwave.

---

## PHASE 6: GAME-WIDE INTEGRATION

### 6.1 Chapter Flow
- [ ] Verify chapter transitions: Ch1 ending loads Ch2, Ch2 loads Ch3, Ch3 loads Ch4, Ch4 loads Ch5.
- [ ] Chapter select from main menu works for all 5 chapters.
- [ ] Save system correctly tracks chapter progress and unlocks.
- [ ] New Game resets all progress and starts from Chapter 1.

### 6.2 Progression Integration
- [ ] Verify tokens carry across chapters.
- [ ] Verify upgrade menu works between chapters.
- [ ] Agent spawn unlocks after Chapter 1 completion.
- [ ] Glob pattern unlocks work per chapter (wildcards Ch1, recursion Ch2, regex Ch3, etc).

### 6.3 Dialogue Pass
- [ ] Review all dialogue for tone consistency — sarcastic, self-aware, AI-themed humor.
- [ ] Ensure narrator has lines for every death, every puzzle solve/fail, every boss phase across ALL chapters.
- [ ] Add at least 10 more sarcastic loading screen tips (target 40 total).

### 6.4 Audio Pass
- [ ] Each chapter has distinct background music.
- [ ] Each chapter has ambient audio.
- [ ] All enemy types have alert, attack, death SFX.
- [ ] Boss music transitions work (crossfade from chapter music).
- [ ] UI sounds: menu navigation, button hover/click, dialogue advance beep.

### 6.5 Visual Consistency
- [ ] Green glow shader applied to all interactive objects across all chapters.
- [ ] CRT shader on all terminal screens across all chapters.
- [ ] Glitch shader on all corrupted enemy types.
- [ ] Post-processing (bloom, chromatic aberration, vignette) active in all chapters.
- [ ] Chapter 5 has its own unique blue-white visual style that contrasts with the green theme.

### 6.6 Credits Sequence
- [ ] Create credits scene: scrolling terminal-style text with green on black.
- [ ] Credits content: "A Globbler Production", character descriptions, sarcastic thank-yous, tools used, sequel tease.
- [ ] Credits play after epilogue.
- [ ] Return to main menu after credits.

---

## PHASE 7: BALANCE AND POLISH

### 7.1 Difficulty Balance
- [ ] Review all enemy HP values. Ensure difficulty ramps across chapters.
- [ ] Review puzzle difficulty. Ch1 easiest, Ch5 hardest.
- [ ] Boss health and phase timing. Each boss should take 3-5 minutes.
- [ ] Token drop rates — player should afford 2-3 upgrades per chapter.
- [ ] Context window meter tuning — should fill and drain at satisfying rates.

### 7.2 Quality of Life
- [ ] Pause menu with resume, settings, quit to menu.
- [ ] Controller/gamepad input mapping (movement, abilities, menu navigation).
- [ ] Key rebinding or at least clear control reference in settings.
- [ ] Camera collision — camera should not clip through walls.
- [ ] Respawn after death: fade to black, respawn at last checkpoint.

### 7.3 Performance
- [ ] Check for physics process heavy operations that could be optimized.
- [ ] Verify enemy/projectile cleanup — no leaked nodes after death/despawn.
- [ ] Test scene transitions for memory leaks.
- [ ] Verify particle effects don't tank framerate.

---

## PHASE 8: GODOT MCP TESTING
# Use the Godot MCP server to run the game and validate everything works.
# These are AUTOMATED VALIDATION tasks. Use MCP tools: run_project, get_debug_output, stop_project.

### 8.1 Launch and Error Check
- [ ] MCP: run_project. Capture full debug output. List ALL errors and warnings. Fix every error.
- [ ] MCP: run_project again after fixes. Confirm zero script errors on launch.
- [ ] MCP: get_project_info. Verify project structure matches expectations.

### 8.2 Scene Loading Tests
- [ ] MCP: run_project, verify main_menu.tscn loads cleanly (no errors in debug output).
- [ ] MCP: check debug output for any "Failed to load resource" or "Invalid call" errors during scene transitions.
- [ ] Verify all 5 chapter scenes load without errors by checking debug output after triggering each chapter from menu.

### 8.3 Gameplay Validation via Debug Output
- [ ] Run game, capture debug output for the first 30 seconds of Chapter 1. Check for runtime errors.
- [ ] Verify GameManager signals are firing (enemy_killed_signal, puzzle_solved, etc) by checking debug prints.
- [ ] Check for physics errors or collision warnings in debug output.
- [ ] Verify save system creates a file by checking debug output after hitting a checkpoint.

### 8.4 Final Smoke Test
- [ ] MCP: run_project with Chapter 1. Let it run 60 seconds. Capture output. Zero errors = pass.
- [ ] MCP: run_project with Chapter 2. Same test.
- [ ] MCP: run_project with Chapter 3. Same test.
- [ ] MCP: run_project with Chapter 4. Same test.
- [ ] MCP: run_project with Chapter 5. Same test.
- [ ] MCP: stop_project. Capture final output. No crash on exit.
- [ ] Commit final validated build with message: "V1 complete — all chapters validated via Godot MCP"
