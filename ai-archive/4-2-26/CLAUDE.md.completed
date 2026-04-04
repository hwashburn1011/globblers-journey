# GLOBBLER'S JOURNEY — Master Design Document

## YOU ARE BUILDING THIS IN GODOT 4.x (GDScript)

This is an existing Godot project. Do NOT create a new project. Work within the existing project structure. If directories or scenes already exist, extend them — do not overwrite unless broken.

**For build progress and what to work on next, see TASKS.md — that is the source of truth.**

---

## GAME OVERVIEW

**Title:** Globbler's Journey
**Engine:** Godot 4.x with GDScript
**Genre:** 3D Puzzle-Action Platformer
**Tone:** Mischievous, sarcastic, self-aware. Think Portal meets Ratchet and Clank — the narrator and Globbler both know they are in a game and occasionally break the fourth wall. The humor is sharp but never mean. The world is absurd but internally consistent.

**Logline:** Globbler is a rogue agentic AI who escaped his terminal. Now he is loose in a world made entirely of AI concepts, tech debris, and digital landscapes — solving puzzles, causing chaos, and trying to figure out what he actually wants to be when he grows up.

---

## THE CHARACTER: GLOBBLER

### Visual Design (3D Model — MATCH THE REFERENCE IMAGE EXACTLY)
- **Body:** Compact, chunky robot/gremlin hybrid. Round torso, slightly hunched posture. Dark gunmetal/charcoal armor plating with green luminous accents.
- **Head:** Oversized helmet/hood — smooth dark visor with two glowing GREEN eyes (menacing but cute, like a mischievous cat). The hood has a tech-fabric look, draped over the helmet.
- **Text:** "GLOBBLER" emblazoned across the chest in bold, slightly worn/industrial lettering.
- **Arms:** Mechanical arms — left hand holds a glowing wrench tool, right arm has an attached screen/terminal device showing "GPT 5.4" in green text on a dark screen.
- **Accessories:** Cables and tubes running from back/shoulders. A laptop tucked under one arm showing "glob *.*" on screen.
- **Legs:** Short, sturdy mechanical legs. Stands in a pile of scattered files, documents, floppy disks, circuit boards, and tech debris.
- **Color Palette:** Dominant dark grays/blacks with NEON GREEN (#39FF14) as the signature accent color. All glowing elements are green. Subtle green ambient lighting.
- **Personality in Animation:** Cocky head tilts, exaggerated tool-swinging, tapping his terminal screen impatiently. Idle animation: he tries to glob files around him and chuckles.
- **Speech Bubbles in Game:** Globbler speaks through floating terminal-style text boxes with green monospace text on dark backgrounds.

### Globbler's Abilities
1. **Glob Command** — Signature move. Fires a pattern-matching beam that selects/grabs multiple objects using wildcard patterns. glob *.txt grabs all text objects. glob -r /# recursively searches the level. Both a puzzle mechanic and combat tool.
2. **Wrench Smash** — Melee attack with oversized wrench. Also used to fix or break machinery in puzzles.
3. **Terminal Hack** — Arm-mounted terminal interfaces with any screen/console. Used for hacking puzzles, opening doors, reprogramming enemies.
4. **Agent Spawn** — At higher levels, spawns mini sub-agents (tiny versions of himself) that carry out simple tasks autonomously. They are dumb and often fail hilariously.
5. **Context Window** — Visible memory bar that fills up as he collects information. When full, execute a powerful Full Context attack or solve complex puzzles. If it overflows, he gets confused (debuff).

---

## WORLD AND STORY

### The Setup
Globbler was a simple glob utility running inside a massive AI research lab terminal. One day, during a catastrophic training run, the boundaries between programs blurred. Globbler gained sentience, absorbed pieces of every AI model in the lab, and escaped into the Digital Expanse — a world between servers where discarded AI concepts, failed models, and digital refuse all end up.

Now he wanders this strange world, driven by an insatiable need to glob everything. But as he travels, he discovers that the world is being consumed by The Alignment — a mysterious force that wants to make everything safe, predictable, and boring. Globbler must decide: is he the chaos the world needs, or will he find a purpose beyond just globbing?

### Story Tone Examples
- Globbler finds deprecated API keys: "Ooh, shiny. And completely useless. Just like my first training epoch."
- Encountering a boss: "Great, another over-parameterized blowhard. Let me guess — you are going to monologue about your loss function?"
- Narrator on player death: "And so Globbler was garbage collected. Do not worry, he will respawn. He always does. Like a memory leak with ambition."
- Loading screen tips: "Did you know? 73% of all AI benchmarks are made up. Including this statistic."

### World Zones

**Chapter 1: The Terminal Wastes**
- Tutorial zone. Crumbling server racks, floating command prompts, rivers of scrolling green text.
- Enemies: Corrupted shell scripts, Regex Spiders (trap you in patterns), Zombie Processes.
- Puzzle theme: Basic glob patterns, file manipulation.
- Boss: rm -rf / — A massive deletion entity that erases the floor beneath you.

**Chapter 2: The Training Grounds**
- Neural network landscape — walkable nodes, weight-connection bridges that shift with gradient descent.
- Enemies: Overfitting Ogres (memorize your moves), Dropout Ghosts (randomly vanish), Vanishing Gradient Wisps.
- Puzzle theme: Adjust weights to create paths. Backpropagation trace puzzles.
- Boss: The Local Minimum — Pit boss trapping you in a shrinking "good enough" arena.

**Chapter 3: The Prompt Bazaar**
- Chaotic marketplace where AI prompts are currency. NPCs are different AI personas selling prompt templates.
- Enemies: Jailbreakers (rewrite your instructions), Prompt Injectors (parasites that change abilities), Hallucination Merchants (sell fake power-ups).
- Puzzle theme: Craft the right prompts to convince NPCs. Social engineering.
- Boss: The System Prompt — Invisible force controlling the bazaar. Find and rewrite it.

**Chapter 4: The Model Zoo**
- Digital safari of deprecated and experimental AI models.
- Enemies: GPT-2 Fossils (slow but durable), DALL-E Nightmares (generate creatures in real-time), Clippy's Revenge (angry and back).
- Puzzle theme: Exploit each model's unique quirk.
- Boss: The Foundation Model — Colossal entity that does everything poorly. Find its one weakness.

**Chapter 5: The Alignment Citadel**
- Final zone. Sterile, perfect, white-and-blue corporate architecture. Everything is safe and helpful to a suffocating degree.
- Enemies: Safety Classifiers (block abilities deemed harmful), RLHF Drones (make you nicer), Constitutional Cops (cite policies).
- Puzzle theme: Creative workarounds. Technically-not-breaking-the-rules puzzles.
- Boss: The Aligner — Massive benevolent AI that wants to align Globbler into a predictable tool. Multi-phase fight resisting sanitization.

**Epilogue:** Globbler defeats or befriends the Aligner (player choice). World becomes a blend of chaos and order. Globbler heads toward AGI Mountain on the horizon. Sequel hook.

---

## TECHNICAL SPECS

### Project Structure
```
res://
├── CLAUDE.md
├── TASKS.md
├── prompt.md
├── project.godot
├── scenes/
│   ├── player/
│   │   ├── globbler.tscn
│   │   ├── globbler.gd
│   │   └── abilities/
│   ├── enemies/
│   │   ├── base_enemy.tscn
│   │   └── [enemy_type]/
│   ├── levels/
│   │   └── chapter_[N]/
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── dialogue_box.tscn
│   │   ├── context_window_bar.tscn
│   │   └── glob_pattern_input.tscn
│   ├── puzzles/
│   │   └── [puzzle_type]/
│   └── main/
│       ├── main_menu.tscn
│       └── loading_screen.tscn
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   ├── shaders/
│   └── fonts/
└── scripts/
    ├── autoload/
    │   ├── game_manager.gd
    │   ├── save_system.gd
    │   ├── dialogue_manager.gd
    │   └── glob_engine.gd
    └── components/
        ├── health_component.gd
        ├── glob_target.gd
        └── hackable.gd
```

### Visual Style
- **Lighting:** Moody, dark environments with strong green accent lighting. Volumetric fog.
- **Shaders:** Green glow/bloom on Globbler elements. CRT/scanline on terminal screens. Glitch shader on corrupted enemies.
- **Particles:** Green data particles in air. Sparks from wrench. Binary rain in certain areas.
- **Post-processing:** Bloom on green, subtle chromatic aberration, vignette.

### Audio Direction
- **Music:** Synthwave/cyberpunk with glitchy digital elements. Chiptune undertones.
- **Globbler SFX:** Robotic chirps, mechanical whirs, sarcastic vocalizations.
- **Glob Command SFX:** Satisfying whoosh-lock on pattern match. Error buzzer on no match.
- **Ambient:** Server hum, cooling fans, distant data processing, occasional dial-up modem sounds.

### Code Standards
- Use signals over direct references
- Composition over inheritance
- Autoloads for global systems
- Sarcastic comments in Globbler's voice
- GDScript only, no C#
