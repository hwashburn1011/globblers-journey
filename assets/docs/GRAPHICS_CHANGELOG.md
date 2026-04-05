# GLOBBLER'S JOURNEY — V2.0 Graphics & Art Pass Changelog

**Date:** 2026-04-05
**Scope:** Complete visual overhaul from CSG placeholders to stylized indie-ship quality.
**Target quality:** ~Death's Door / Tunic / Hi-Fi Rush tier (stylized low-poly + shaders + lighting).

---

## Summary

V2.0 replaces every CSG placeholder in the game with custom Blender-built 3D models, PBR materials, HDRI lighting, volumetric fog, and 14 custom shaders. All 5 chapters, 15 enemy types, 5 bosses, 14 puzzles, and the full UI have been visually upgraded. Zero gameplay logic was changed.

### Asset Counts

| Category         | Count | Notes                                      |
|------------------|-------|--------------------------------------------|
| GLB models       | 61    | 1 player, 38 environment, 15 enemies, 5 bosses, 2 misc |
| Shaders (.gdshader) | 14 | character_rim, eye_pulse, crt_scanline, damage_flash, dissolve, glob_beam, wrench_trail, cooldown_radial, dialogue_scanline, glitch, green_glow, crt_screen, glob_target_highlight, hackable_beacon |
| HDRIs            | 5     | 1 per chapter, Poly Haven CC0              |
| Blender sources  | 31    | Full .blend files for all custom models    |
| WorldEnvironments | 6    | 1 base template + 5 chapter-specific       |
| Screenshots      | 20    | Hero gallery in assets/docs/screenshots/   |

---

## Pass-by-Pass Breakdown

### Pass 1 — Lighting & World Environment
- Downloaded 5 Poly Haven HDRIs (1K): empty_warehouse_01, blue_photo_studio, carpentry_shop_02, abandoned_hall_01, blocky_photo_studio
- Created base WorldEnvironment template: FILMIC tonemap, SSAO, SSIL, SDFGI, volumetric fog, glow
- 5 chapter-specific .tres resources with tuned fog color, sky energy, and atmosphere per palette
- DirectionalLight3D tuning: 4-split shadows, per-chapter color temperature (4500K–8500K)

### Pass 2 — Globbler Hero Character
- Custom Blender-built chibi robot: dark metal (#141614) + neon green (#39FF14) emission
- Stubby proportions (~0.9m): rounded torso, hood/helmet, triangular angry eyes, chest terminal, cables, boots, chunky wrench
- Tuned in-game: scale 1.4x, collision capsule (r=0.35, h=1.3), third-person camera (distance=6.0, pitch=-0.3)
- Source: `assets/blender_source/globbler.blend`

### Pass 3 — Character Shaders
- **character_rim.gdshader** — fresnel rim light (neon green edge glow)
- **eye_pulse.gdshader** — emissive eye pulse animation
- **crt_scanline.gdshader** — CRT scanline effect for chest screen
- **damage_flash.gdshader** — red hit feedback flash
- **dissolve.gdshader** — pixel dissolve death effect
- All shaders respect `reduce_motion` setting

### Pass 4 — Prop Packs
- 4 Blender-built prop packs (~20 GLB props):
  - Electronic pack: CRT monitors, power supplies, hard drives, floppy disks
  - Cyberpunk/architecture pack: wall terminals, industrial panels, server racks
  - Bazaar pack: market stalls, lanterns, crates
  - Clinical pack: clean kiosks, policy terminals, vote pedestals

### Pass 5 — Chapter Prop Passes
- All 5 chapters populated with themed props via MultiMesh scatters and direct placement
- Chapter-specific prop selection matching color palettes

### Pass 6 — Enemy Visuals
- All 15 enemy types upgraded from CSG to custom Blender GLB models
- Per-chapter themed materials and silhouettes

### Pass 7 — Boss Visuals
- 5 bosses upgraded to detailed GLB models:
  - Ch1: rm_rf (Terminal Wastes)
  - Ch2: System Prompt (Training Grounds)
  - Ch3: Local Minimum (Prompt Bazaar)
  - Ch4: Foundation Model (Model Zoo)
  - Ch5: The Aligner (Alignment Citadel)

### Pass 8 — Audio/SFX
- Background music + sound effects integrated via AudioManager
- Per-chapter ambient tracks, combat stingers, UI sounds

### Pass 9 — UI/Menu Restyle
- Main menu, pause menu, game-over, settings, HUD — all restyled
- Terminal-green-on-black theme with scanline shaders
- Monospace font (terminal_mono.ttf) across all UI
- Box-drawing frame characters for panel borders

### Pass 10 — Settings & QoL
- Fullscreen toggle, resolution picker (720p–4K)
- Mouse sensitivity slider (0.1x–3.0x), invert-Y toggle
- Chapter select with rendered thumbnails
- End-of-chapter stats summary screen

### Pass 11 — QA & Polish
- Visual QA across all 5 chapters
- Fixed shader compilation errors (dialogue_scanline return statement)
- Fixed type mismatches (MeshInstance3D vs Node3D for GLB instances)
- Performance audit: RTX 3070 @ 1080p — all chapters pass, ~124MB total assets

### Pass 12 — Puzzle Visual Upgrades
- All 14 puzzle scenes upgraded from CSG to GLB props
- Ch1: electronic terminals + CRT scanline screens
- Ch2: neural-node spheres + synaptic tube connectors + emissive indicators
- Ch3: bazaar stall terminals + crystal token meshes + lantern flanks
- Ch4: museum display cases, pedestals, kiosks (3 new Blender models)
- Ch5: clinical policy terminals, holographic tablets, vote pedestals (3 new Blender models)

### Pass 13 — Interaction & Feedback UI
- Boss health bar (full-width, phase dots, smooth lerp + ghost bar)
- Enemy HP pips (3-bar billboard, auto-hide after 2s)
- Interaction prompts ("[T] HACK", "[F] SMASH" — pulsing green)
- Wrench weapon trail (ImmediateMesh ribbon + additive shader)
- Damage direction indicator (red chevron arc)
- Ability cooldown radial shader overlay
- Tutorial hint restyle (scanline shader + box-drawing frame)
- Dialogue history viewer restyle (terminal scrollback aesthetic)
- Chapter summary screen art (ASCII flourish + icon stat rows)
- Splash boot screen (typewriter BIOS sequence)
- Glob target highlight shader (pulsing fresnel outline)
- Hackable terminal beacon pulse (beam column + ground ring)

### Pass 14 — Showcase & Documentation
- 20 hero screenshots captured across all chapters + UI
- README.md with feature list, screenshots, build instructions
- This changelog

---

## Blender Source Files

All custom models have editable `.blend` sources in `assets/blender_source/`:

| File | Contents |
|------|----------|
| globbler.blend | Player character (chibi robot) |
| electronic_props.blend | CRT monitors, power supplies, drives |
| architecture_props.blend | Wall terminals, industrial panels |
| bazaar_props.blend | Market stalls, lanterns, crates |
| clinical_props.blend | Clean kiosks, pedestals |
| enemy_*.blend | 15 enemy type models |
| boss_*.blend | 5 boss models |
| museum_*.blend | Display cases, pedestals, kiosks |
| citadel_*.blend | Policy terminals, tablets, pedestals |

---

## Performance

- **Target hardware:** RTX 3070 / Vulkan Forward+ @ 1080p
- **Total asset size:** ~124MB
- **Rendering features active:** FILMIC tonemap, SSAO, SSIL, SDFGI, volumetric fog, 4-split directional shadows, glow
- **Known issue:** Duplicate globbler.glb in assets/models/ root (3.4MB wasted — cosmetic)

---

## Attribution

All third-party assets are CC0 or royalty-free. Full attribution table: [`assets/LICENSES.md`](../LICENSES.md).
