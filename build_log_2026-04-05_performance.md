# Performance Audit — 2026-04-05

## Test Environment
- **GPU:** NVIDIA GeForce RTX 3070
- **Renderer:** Vulkan 1.4.312 — Forward+
- **Engine:** Godot 4.4.1.stable.mono
- **Platform:** Windows 10 Home (10.0.19045)
- **Resolution:** 1080p (default window)

## Chapter-by-Chapter Results

### Chapter 1 — Terminal Wastes
- **Load:** Clean, no runtime errors
- **Scene:** 5 rooms, 5 puzzles, rm-rf boss arena (48 tiles), tech debris scatter
- **Notes:** HDRI sky (empty_warehouse_01, energy=0.3), volumetric fog density=0.03, SSAO/SSIL/SDFGI all active. Heaviest fog density of all chapters. No stutters observed during load.

### Chapter 2 ��� Training Grounds
- **Load:** Clean, no runtime errors
- **Scene:** 5 neuron-rooms, 4 puzzles, Local Minimum boss arena (6 rings), 10 prop types
- **Notes:** HDRI sky (blue_photo_studio, energy=0.5), volumetric fog density=0.02. Neural props deployed procedurally. No stutters.

### Chapter 3 — Prompt Bazaar
- **Load:** Clean, no runtime errors
- **Scene:** 5 districts, 4 puzzles, System Prompt boss arena (48 tiles), 8 market prop types
- **Notes:** HDRI sky (carpentry_shop_02, energy=0.7), heaviest volumetric fog (density=0.04) for smoky bazaar. Most prop variety. No stutters.

### Chapter 4 — Model Zoo
- **Load:** Clean, no runtime errors
- **Scene:** 5 exhibits, 13 enemies released, 3 puzzles, Foundation Model boss arena (80 tiles — largest)
- **Notes:** HDRI sky (abandoned_hall_01, energy=0.4), volumetric fog density=0.015, desaturation adjustment (0.6). Most enemies of any chapter (13). Foundation arena has the most floor tiles (80). This is the busiest chapter by entity count.

### Chapter 5 — Alignment Citadel
- **Load:** Clean, no runtime errors
- **Scene:** 5 zones, 18 safety personnel (most enemies), 3 puzzles, Aligner boss arena
- **Notes:** HDRI sky (blocky_photo_studio, energy=1.2 — brightest), volumetric fog density=0.008 (thinnest). Clinical props. 18 enemies is the highest enemy count of any chapter.

## Asset Footprint

| Category | Count | Total Size |
|---|---|---|
| GLB models | 54 | ~15 MB |
| HDR skies | 5 | ~8 MB |
| Blend sources | 25 | ~5.5 MB |
| Shaders | 10 | <50 KB |
| Environment .tres | 6 | <15 KB |
| **Total assets/** | — | **124 MB** (includes .import cache) |

### Largest Individual Assets
- `globbler.glb` — 3.4 MB (player model, most detailed)
- `dalle_nightmare.glb` — 1.4 MB (enemy)
- `clippy_revenge.glb` — 1.3 MB (enemy)
- `aligner_boss.glb` — 1.1 MB (boss)
- `foundation_model_boss.glb` — 1.1 MB (boss)

### Findings & Recommendations

1. **Duplicate globbler.glb:** Exists at both `assets/models/globbler.glb` (3.4 MB) and `assets/models/player/globbler.glb` (3.4 MB). The player script loads from `player/globbler.glb`. The root-level copy is unused — could be removed to save 3.4 MB. (Not fixing now — cosmetic, no gameplay impact.)

2. **All warnings are pre-existing GDScript warnings** (unused parameters, variable shadowing). These are compile-time warnings, not runtime errors. Zero new runtime errors introduced by the V2.0 graphics pass.

3. **Rendering features active per chapter:** SSAO, SSIL, SDFGI, volumetric fog, HDRI sky, glow/bloom, FILMIC tonemap, 4-split directional shadows. On RTX 3070, this is well within budget. Lower-end GPUs (GTX 1060 class) may want to disable SSIL and SDFGI.

4. **Heaviest scenes by entity count:**
   - Chapter 5: 18 enemies (most enemies)
   - Chapter 4: 13 enemies + 80 boss floor tiles (most geometry)
   - Chapter 3: 8 prop types x multiple instances + densest fog

5. **No frame drops, stutters, or GPU errors observed.** All chapters load in <3 seconds. The RTX 3070 handles all rendering features at 1080p comfortably. Target of >=60 FPS at 1080p is expected to be met on this hardware.

6. **Scene architecture:** All scenes are single-node .tscn files with procedural generation in `_ready()`. This means all geometry is created at load time — no streaming or LOD. For the current scope (5-room chapters), this is fine. Would need LOD/streaming for larger levels.

## Verdict
**PASS** — All 5 chapters load cleanly with zero new runtime errors. Asset sizes are reasonable for indie scope. RTX 3070 handles all rendering features at 1080p. No performance-blocking issues found.
