# GLOBBLER'S JOURNEY — Release Readiness & Audio (V2.1)

## YOU ARE SHIPPING A COMPLETE GAME

V2.0 finished a massive graphics pass (120 tasks). The game has real GLB models, HDRI lighting, PBR materials, shaders, LODs, animations, and VFX. This pass makes it shippable: real audio assets, verified Windows builds, cleanup of known debt, and a chapter-by-chapter playtest to catch regressions.

**For what to do next, see TASKS.md — that is the source of truth.**

---

## RULES

- Do NOT change gameplay logic, enemy AI, puzzle mechanics, or boss phase timing.
- Do NOT introduce new enemies/puzzles/chapters.
- One task = one commit. Stop after each task.
- All CC0 downloads get a row in `assets/LICENSES.md` (name, source, license, URL, used in).
- Keep changes surgical. Touch only the files the task names.

---

## PROJECT STATE (POST-V2.0)

```
assets/
  models/player/globbler.glb          # 1.4x scale, animated
  models/enemies/*.glb                # 15 enemies, custom models
  models/bosses/*.glb + *_lod1.glb    # 5 bosses with LODs
  models/environment/*.glb            # 4 prop packs
  models/npcs/*.glb                   # 6+ NPCs
  blender_source/*.blend              # all source files kept
  hdri/*.hdr                          # 5 HDRIs (one per chapter)
  textures/pbr/<material>/            # PBR texture sets
  environments/chapter_<n>.tres       # WorldEnvironment per chapter
  shaders/*.gdshader                  # 10+ shaders (rim, pulse, CRT, glitch, etc.)
  audio/                              # EMPTY — target of Pass 2
  sounds/                             # EMPTY — deprecated, ignore
  fonts/terminal_mono.ttf
  ui/icons/*.png
  docs/screenshots/ch{1-5}_{a,b,c}.png  # 20 hero screenshots
  docs/GRAPHICS_CHANGELOG.md
  LICENSES.md                         # attribution table — keep updated
```

---

## AUTOLOADS (UNCHANGED FROM V1.2+)

GameManager, RespawnManager, GlobEngine, DialogueManager, SaveSystem, AudioManager, ProgressionManager.

---

## AUDIO MANAGER KEY FACTS

- Current implementation uses `AudioStreamGenerator` to procedurally synth all music + SFX (see comments in `scripts/autoload/audio_manager.gd`).
- Pass 2 adds REAL audio: load `.ogg` files from `assets/audio/music/` and `assets/audio/sfx/`, fall back to procedural synth if a file is missing.
- Keep the procedural fallback path — it's a safety net, not removed.
- Existing public API stays stable: `start_music(name)`, `play_sfx(name)`, `start_boss_music()`, `stop_boss_music()`, `set_music_volume()`, etc.
- Volume settings persist via `save_settings()` / `load_settings()` (settings.cfg).

---

## CC0 AUDIO SOURCES (for Pass 2 tasks)

- **Pixabay Music** — https://pixabay.com/music/ (CC0, royalty-free)
- **Free Music Archive** — https://freemusicarchive.org/ (filter to CC0 / Public Domain)
- **OpenGameArt.org** — https://opengameart.org/ (filter to CC0)
- **Freesound.org** — https://freesound.org/ (filter to CC0, for SFX)
- **Kenney Game Assets** — https://kenney.nl/assets (all CC0)

Prefer CC0. If a CC-BY track is used, attribution MUST go in `assets/LICENSES.md` AND the in-game credits.

---

## EXPORT NOTES

- Presets live in `export_presets.cfg` at project root.
- Build scripts: `export_game.ps1` (PowerShell) and `export_game.sh` (bash).
- Shipping exclude list must skip: `ai-archive/`, `tools/blender-mcp/`, `build_log_*`, `*.blend`, `*.blend1`, `.claude/`.
- Target sizes after V2.0: ~125MB assets. Post-audio target: ~180-200MB.

---

## COMMON PATTERNS FOR THIS PASS

**Load audio with procedural fallback:**
```gdscript
var loaded_stream := load("res://assets/audio/music/" + track_name + ".ogg") as AudioStream
if loaded_stream:
    _music_player.stream = loaded_stream
    _music_player.play()
else:
    # existing procedural synth path
    _start_procedural_music(track_name)
```

**Version constant + display:**
```gdscript
# In GameManager:
const GAME_VERSION := "2.1.0"

# In main_menu.gd _ready():
$VersionLabel.text = "v%s" % GameManager.GAME_VERSION
```

**Dev-build commit hash display:**
```gdscript
if OS.is_debug_build():
    var head_file := FileAccess.open("res://.git/HEAD", FileAccess.READ)
    # parse HEAD ref, append to version label
```

**Playtest cataloging format (for Pass 4):**
Each issue gets: `[severity] location — description`. Severities: BREAKING / VISUAL / MINOR.

---

## THINGS TO LEAVE ALONE

- V2.0 graphics assets and shaders (unless playtest surfaces a specific bug in them)
- Enemy AI state machines, boss phases, puzzle logic
- Save format (additive only — never remove keys)
- V1.2 systems: RespawnManager, GameOver flow, tutorial hints, reduce_motion, dialogue history
- `scripts/player.gd` was removed in V1.2 — do not resurrect it

---

## GODOT MCP SERVER

`run_project`, `stop_project`, `get_debug_output`, `get_project_info` — use for all playtest/validation tasks.

---

## QUALITY BAR

A task is done when:
1. The expected change is on disk AND takes effect in-game (or in the exported build).
2. No new runtime errors (Godot MCP `get_debug_output` confirms).
3. Asset attributions recorded in `assets/LICENSES.md` if applicable.
4. TASKS.md updated with [x] + concrete note.
