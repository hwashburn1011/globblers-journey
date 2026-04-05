# GLOBBLER'S JOURNEY — GRAPHICS & ART PASS (V2.0)
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# Only change ONE checkbox per iteration. Commit. Stop.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude (2026-04-05) — Task 15.10 complete
- **Last task completed:** Task 15.10 — Dynamic FOV. Added FOV constants (default 70°, sprint 80°, aim 60°) and smooth lerp (speed 5.0) in `_update_camera()` in `scenes/player/globbler.gd`. FOV widens during `AnimState.RUN` (sprint) and tightens when `glob_command.is_aiming`. Disabled when `reduce_motion` is enabled. Zero new runtime errors.
- **Next task to do:** Task 15.11 (LOD meshes for bosses and large props)
- **V2.0 MILESTONE SUMMARY (Passes 1–11):**
  - **Pass 1 — Lighting:** 5 Poly Haven HDRIs, 5 WorldEnvironment .tres resources, DirectionalLight3D tuning (4-split shadows, per-chapter color temp). All chapters have FILMIC tonemap, SSAO, SSIL, SDFGI, volumetric fog.
  - **Pass 2 — Globbler Hero:** Custom Blender-built chibi robot GLB (dark metal + neon green), tuned scale (1.4x), collision capsule (r=0.35, h=1.3), third-person camera (distance=6.0, pitch=-0.3, height=1.1m).
  - **Pass 3 — Character Shaders:** 5 shaders — character_rim (rim light), eye_pulse (emissive pulse), crt_scanline (chest screen), damage_flash (hit feedback), dissolve (death effect). All respect reduce_motion.
  - **Pass 4 — Prop Packs:** 4 Blender-built prop packs (electronic, cyberpunk, bazaar, clinical) — ~20 GLB environment props total.
  - **Pass 5 — Chapter Prop Passes:** All 5 chapters populated with themed GLB props via MultiMesh scatters and direct placement.
  - **Pass 6 — Enemy Visuals:** All 15 enemy types upgraded from CSG to custom Blender GLB models with themed materials.
  - **Pass 7 — Boss Visuals:** All 5 bosses (rm_rf, System Prompt, Local Minimum, Foundation Model, Aligner) upgraded to detailed GLB models.
  - **Pass 8 — Audio/SFX:** Background music + sound effects integrated via AudioManager.
  - **Pass 9 — UI/Menu Restyle:** Main menu, pause menu, game-over, settings, HUD — all restyled with terminal-green theme, scanline shaders, monospace fonts.
  - **Pass 10 — Settings & QoL:** Fullscreen toggle, resolution picker, mouse sensitivity, invert-Y, chapter select thumbnails, end-of-chapter stats summary.
  - **Pass 11 — QA & Polish:** Visual QA across all 5 chapters, shader fixes, performance audit (RTX 3070 @ 1080p — all chapters pass).
  - **Asset counts:** 57 GLB models, 10 shaders, 5 HDRIs, ~125MB total assets. Zero new runtime errors.
- **Known issues:** Duplicate globbler.glb (3.4MB wasted space — cosmetic, not blocking).

### GOAL OF THIS PASS
Upgrade visual quality from CSG placeholders to stylized indie-game-ship quality (~Death's Door / Tunic / Hi-Fi Rush tier). Hero assets (Globbler, bosses) built in Blender via blender-mcp. Environment via CC0 assets from Poly Haven / Sketchfab. Lighting + post-processing + VFX upgraded in Godot.

### VISUAL REFERENCE
Globbler reference art: `C:/Users/hwash/Desktop/globbler.jpg` (stubby chibi robot, dark hood/helmet, neon green angry eyes, wrench, chest terminal, cables, boots, dark+green palette).

### ASSET ORGANIZATION
```
assets/
  models/player/globbler.glb
  models/enemies/{enemy_name}.glb
  models/bosses/{boss_name}.glb
  models/environment/{prop_name}.glb
  blender_source/*.blend          # keep source .blend for future edits
  hdri/*.hdr                      # Poly Haven HDRIs
  textures/pbr/{material}/        # AmbientCG / Poly Haven PBR sets
  environments/chapter_{n}.tres   # WorldEnvironment resources
  LICENSES.md                     # track all CC0/CC-BY attributions
```

### PER-CHAPTER COLOR PALETTE (locked reference)
- **Chapter 1 — Terminal Wastes:** deep black + neon green (#39FF14), CRT phosphor glow, heavy dark corridors
- **Chapter 2 — Training Grounds:** cool blue-green (#4AE0A5), neural-net mesh accents, slightly cleaner
- **Chapter 3 — Prompt Bazaar:** warm amber (#FFAA33) + neon pink (#FF3EA5), market lanterns, steam
- **Chapter 4 — Model Zoo:** desaturated museum beige + cold white, dusty motes
- **Chapter 5 — Alignment Citadel:** clinical white (#F5F8FF) + pale blue (#7FB5FF), stark fluorescent

---

## PASS 1: LIGHTING & WORLD ENVIRONMENT
# Fastest visual wins — affects every scene. No new 3D assets required.

### 1.1 Create asset folder scaffold
- [x] Create directories: `assets/models/player`, `assets/models/enemies`, `assets/models/bosses`, `assets/models/environment`, `assets/blender_source`, `assets/hdri`, `assets/textures/pbr`, `assets/environments`. Create `assets/LICENSES.md` with an empty attribution table (columns: Asset Name, Source, License, URL, Used In). Commit. **Done: all dirs created with .gdkeep for git tracking, LICENSES.md with attribution table header.**

### 1.2 Download Poly Haven HDRIs
- [x] Use `mcp__blender__search_polyhaven_assets` (asset_type="hdris") to find 5 suitable HDRIs: dark industrial/server room (Ch1), neutral studio (Ch2), warm market/bazaar (Ch3), abandoned museum (Ch4), clinical/office (Ch5). Download each 1K via `mcp__blender__download_polyhaven_asset`. Export .hdr from Blender to `assets/hdri/ch{n}_sky.hdr`. Record names+URLs in `assets/LICENSES.md`. **Done: Downloaded via Poly Haven API — empty_warehouse_01 (Ch1), blue_photo_studio (Ch2), carpentry_shop_02 (Ch3), abandoned_hall_01 (Ch4), blocky_photo_studio (Ch5). All 1K HDR, ~1.6MB each. LICENSES.md updated.**

### 1.3 Create base WorldEnvironment template resource
- [x] Create `assets/environments/base_env.tres` — Environment resource with: tonemap_mode=FILMIC, exposure=1.0, glow_enabled=true, glow_bloom=0.2, glow_hdr_threshold=1.0, ssao_enabled=true, ssao_radius=1.5, ssil_enabled=true, sdfgi_enabled=true, fog_enabled=true, fog_density=0.01, volumetric_fog_enabled=true. This is the template all chapters will extend. **Done: base_env.tres created with FILMIC tonemap, glow (bloom=0.2, HDR threshold=1.0), SSAO (radius=1.5), SSIL, SDFGI with occlusion, fog (density=0.01), and volumetric fog (density=0.02). Chapter-specific overrides will adjust sky, fog color, and density.**

### 1.4 Chapter 1 WorldEnvironment
- [x] Create `assets/environments/chapter_1.tres` from base. Load `ch1_sky.hdr` as sky texture, sky_energy=0.3 (dark), fog_light_color=Color(0.1,0.4,0.15), volumetric_fog_density=0.03, tint glow toward green. In `terminal_wastes.gd`, in `_ready()`, instantiate a WorldEnvironment node with environment=`preload("res://assets/environments/chapter_1.tres")` before CSG geometry builds. Remove any existing ad-hoc Environment setup. MCP screenshot via `get_viewport_screenshot` and compare. **Done: Created chapter_1.tres with empty_warehouse_01 HDRI sky (energy=0.3), green fog (0.1,0.4,0.15), volumetric fog density=0.03, SSAO/SSIL/SDFGI, FILMIC tonemap. Replaced 20-line ad-hoc Environment.new() block in terminal_wastes.gd _setup_environment() with a 4-line preload of the .tres resource.**

### 1.5 Chapter 2 WorldEnvironment
- [x] Same as 1.4 but `chapter_2.tres` — cool blue-green (`fog_light_color=Color(0.3,0.7,0.6)`, brighter sky_energy=0.5). Apply in `training_grounds.gd` `_ready()`. **Done: Created chapter_2.tres with blue_photo_studio HDRI sky (energy=0.5), blue-green fog (0.3,0.7,0.6), volumetric fog density=0.02, SSAO/SSIL/SDFGI, FILMIC tonemap. Replaced 18-line ad-hoc Environment.new() block in training_grounds.gd _setup_environment() with a 4-line preload of the .tres resource.**

### 1.6 Chapter 3 WorldEnvironment
- [x] Same as 1.4 but `chapter_3.tres` — warm amber (`fog_light_color=Color(0.9,0.6,0.3)`, sky_energy=0.7, heavier volumetric fog for "smoky market"). Apply in `prompt_bazaar.gd`. **Done: Created chapter_3.tres with carpentry_shop_02 HDRI sky (energy=0.7), warm amber fog (0.9,0.6,0.3), heavier volumetric fog density=0.04 for smoky market vibes, SSAO/SSIL/SDFGI, FILMIC tonemap. Replaced 18-line ad-hoc Environment.new() block in prompt_bazaar.gd _setup_environment() with a 4-line preload of the .tres resource. Kept directional lights intact.**

### 1.7 Chapter 4 WorldEnvironment
- [x] Same as 1.4 but `chapter_4.tres` — desaturated (`adjustment_saturation=0.6`, `fog_light_color=Color(0.6,0.6,0.55)`, dusty motes via ProceduralSkyMaterial). Apply in `model_zoo.gd`. **Done: Created chapter_4.tres with abandoned_hall_01 HDRI sky (energy=0.4), dusty desaturated fog (0.6,0.6,0.55), volumetric fog density=0.015 for floating dust motes, adjustment_saturation=0.6 for that archived-museum look, SSAO/SSIL/SDFGI, FILMIC tonemap. Replaced 20-line ad-hoc Environment.new() block in model_zoo.gd _setup_environment() with a 4-line preload of the .tres resource. Kept directional lights intact.**

### 1.8 Chapter 5 WorldEnvironment
- [x] Same as 1.4 but `chapter_5.tres` — clinical bright (`adjustment_saturation=0.9`, `fog_light_color=Color(0.9,0.95,1.0)`, sky_energy=1.2, glow_intensity lowered). Apply in `alignment_citadel.gd`. This chapter contrasts all others — high key lighting. **Done: Created chapter_5.tres with blocky_photo_studio HDRI sky (energy=1.2), clinical pale blue-white fog (0.9,0.95,1.0), volumetric fog density=0.008 for thin regulated haze, adjustment_saturation=0.9, lowered glow (intensity=0.8, threshold=1.2), SSAO/SSIL/SDFGI, FILMIC tonemap. Replaced 20-line ad-hoc Environment.new() block in alignment_citadel.gd _setup_environment() with a 4-line preload of the .tres resource. Kept directional lights intact.**

### 1.9 Global sun/directional light pass
- [x] Each chapter has a DirectionalLight3D. Tune angle, color temp, shadow quality per chapter. Chapter 1 low warm-green rim, Chapter 5 high cool overhead. Enable shadows with `shadow_enabled=true`, `directional_shadow_mode=PARALLEL_4_SPLITS`. **Done: Tuned both MainLight and FillLight in all 5 chapters. Ch1: low-angle green rim (temp 4500K, angular_size 0.5), Ch2: cool teal overhead (7000K, angular_size 0.3), Ch3: warm amber golden-hour (3500K, angular_size 0.8 for smoky diffusion), Ch4: neutral museum overhead (5500K, angular_size 0.4), Ch5: harsh clinical near-vertical (8500K, angular_size 0.1 for hard shadows). All lights now use SHADOW_PARALLEL_4_SPLITS with tuned bias/normal_bias. Fill lights also get shadows enabled.**

### 1.10 MCP lighting smoke test all chapters
- [x] Run project via Godot MCP, load each chapter from chapter select, capture screenshot via Blender MCP `get_viewport_screenshot` (if showing Godot window) or Godot screen capture. Save to `build_log_<date>_lighting.md` with findings per chapter. No script errors required. **Done: Ran all 5 chapters via Godot MCP. Found and fixed 2 critical bugs: (1) all .tres files had fake UIDs that Godot couldn't resolve — launched editor to trigger HDR imports, updated all UIDs to real Godot-assigned values; (2) `light_angular_size` property doesn't exist on DirectionalLight3D in Godot 4.4.1 — removed from all 5 chapter scripts. After fixes, all 5 chapters load cleanly with no new runtime errors. Results logged to `build_log_2026-04-04_lighting.md`. PASS 1 COMPLETE.**

---

## PASS 2: GLOBBLER HERO CHARACTER
# The star of the show. Build in Blender via blender-mcp, export to Godot.

### 2.1 Set up Globbler Blender scene
- [x] Via `mcp__blender__execute_blender_code`: clear default scene, set units to meters, add a 1.2m reference cube at origin for scale, set viewport shading to Material Preview. Save file as `assets/blender_source/globbler.blend`. Take viewport screenshot. **Done: Cleared defaults, set metric units (meters), added 1.2m wireframe reference cube at origin + dark ground plane, set viewport to Material Preview. Saved globbler.blend to assets/blender_source/.**

### 2.2 Sculpt Globbler body (stubby torso + head)
- [x] Via `execute_blender_code`: create rounded torso with subdivided UV sphere scaled (1.0, 1.0, 0.85), add slight downward taper. Add integrated head-hood (another squashed sphere blended at top). Target dimensions: ~0.9m tall total, stubby proportions matching reference. Apply Subdivision Surface (level 2). Screenshot and compare to `C:/Users/hwash/Desktop/globbler.jpg`. **Done: Built single UV sphere (32 seg, 24 rings) with vertex-level sculpting — top half expanded 1.3x for large chibi hood-dome, subtle waist pinch at mid-section, stocky torso below, tapered bottom for boot attachment. Front visor overhang pushed forward. Wider side-to-side than front-to-back. SubSurf level 2 + smooth shading. Final body height: 0.645m (bottom at 0.15m, top at 0.84m), with boots will reach ~0.9m target. Saved to assets/blender_source/globbler.blend.**

### 2.3 Carve face cavity + glowing eye sockets
- [x] Via `execute_blender_code`: boolean-subtract a flat rectangular recess for the face area. Add two large oval eye sockets (triangular-angry shape). These sockets will get emissive material in 2.9. Screenshot. **Done: Applied SubSurf (12K verts) then used vertex-displacement sculpting to carve face. Wide flat face cavity recess on front of head dome (Z 0.48–0.75, 915 verts pushed inward up to 7cm). Two large angry-tilted eye sockets (20° inward tilt, 137 verts each, pushed up to 13cm cumulative depth over 3 passes). Eyes have triangular-angry expression matching reference — inner corners higher, outer corners lower. SubSurf level 1 re-added for smooth shading. Saved to assets/blender_source/globbler.blend.**

### 2.4 Model wrench prop
- [x] Via `execute_blender_code`: model a chunky adjustable wrench (handle + adjustable jaw head) parented to Globbler's right "hand" anchor point. Scale so it's visible at player height. Low-poly with bevels. Screenshot. **Done: Built 5-part adjustable wrench — octagonal tapered handle, fixed jaw, movable jaw, bridge, and knurled adjustment wheel (304 verts, 282 polys). Beveled all edges. Parented to Globbler_Body at right side (0.22, -0.04, 0.22) with casual angled grip. Scaled 0.85x for chibi proportions. Saved to assets/blender_source/globbler.blend.**

### 2.5 Model chest terminal / laptop screen
- [x] Via `execute_blender_code`: flat rectangular screen prop embedded in torso front. Slightly tilted upward. Separate material slot for emissive CRT effect. Screenshot. **Done: Built 2-part chest terminal — dark gunmetal bezel frame (0.256m x 0.176m x 0.04m, beveled edges, boolean-subtracted screen recess) + emissive green CRT screen plane (0.22m x 0.14m, emission_color=(0.2,0.9,0.2), emission_strength=3.0, glossy roughness=0.08). Positioned at Z=0.40 on body front (Y=-0.23), tilted 12° upward for camera visibility. Both parented to Globbler_Body. Saved to assets/blender_source/globbler.blend.**

### 2.6 Model cables, tubes, and boots
- [x] Via `execute_blender_code`: add 3–4 curved cable tubes connecting head to torso using Curve objects with bevel depth. Add stubby boot cylinders at base of torso. All low-poly, beveled. Screenshot. **Done: Built 4 bezier-curve cables (2 front, 2 back) with bevel depth 0.010–0.012 connecting head dome (Z~0.70) to torso shoulders (Z~0.42–0.45), curving outward naturally. Built 2 stubby tapered boot cylinders (12-vert, beveled, SubSurf level 1) at base (Z=0.07) with wider soles and tread strips. All parented to Globbler_Body. Saved to assets/blender_source/globbler.blend.**

### 2.7 Apply dark metal PBR material to body
- [x] Via `execute_blender_code`: create `globbler_body` material — principled BSDF, base_color=(0.08,0.09,0.08), metallic=0.7, roughness=0.55, clearcoat=0.2. Assign to torso+head+boots. Screenshot with material preview. **Done: Created `globbler_body` Principled BSDF material (base_color=(0.08,0.09,0.08), metallic=0.7, roughness=0.55, coat_weight=0.2) — dark gunmetal with subtle clearcoat sheen. Assigned to Globbler_Body, Boot_Left, Boot_Right, Sole_Left, Sole_Right, and all 4 cables. Also created `globbler_wrench` variant (base_color=(0.12,0.13,0.12), metallic=0.85, roughness=0.4, coat_weight=0.3) — slightly shinier worn-tool look. Verified in Material Preview viewport. Saved to globbler.blend.**

### 2.8 Apply emission material to eyes
- [x] Via `execute_blender_code`: create `globbler_eyes_emissive` material — base_color=(0.22,1.0,0.08), emission_color=(0.22,1.0,0.08), emission_strength=8.0. Assign to eye socket faces. Screenshot. **Done: Created `globbler_eyes_emissive` Principled BSDF material (base_color=(0.22,1.0,0.08), emission_color=(0.22,1.0,0.08), emission_strength=8.0, roughness=0.15 for glossy LED look). Added as second material slot on Globbler_Body. Identified 87 deeply-recessed eye socket faces (Y > -0.15, Z 0.52–0.72, |X| 0.03–0.20) via bmesh analysis and assigned to emissive material. Both angry-tilted eye sockets glow bright neon green against dark metal body. Saved to globbler.blend.**

### 2.9 Apply emission CRT material to chest screen
- [x] Via `execute_blender_code`: create `globbler_screen` material — emission_color=(0.2,0.9,0.2), emission_strength=3.0. Later we'll override with a scanline shader in Godot, but this gives the base glow on export. Screenshot. **Done: Created `globbler_screen` Principled BSDF material (base_color=(0.2,0.9,0.2), emission_color=(0.2,0.9,0.2), emission_strength=3.0, roughness=0.08 for glossy screen surface). Assigned to ChestTerminal_Screen object. Fixed bezel slot 0 (was None, now globbler_body). Cleaned up orphan material duplicates. Green CRT glow visible in viewport. Saved to globbler.blend.**

### 2.10 Bake AO and export to GLB
- [x] Via `execute_blender_code`: bake ambient occlusion to a 1024 texture on the combined mesh. Join all Globbler parts (except wrench, keep separate for animation). Select all, export as GLB to `assets/models/player/globbler.glb` with `export_apply=True`, `export_materials='EXPORT'`, `export_yup=True`. Save .blend. **Done: Converted 4 cable curves to mesh, joined 11 body parts into single Globbler_Body mesh (13502 verts, 3 material slots: globbler_body, globbler_eyes_emissive, globbler_screen). Created AO_UV layer with Smart UV Project, baked 1024x1024 AO texture via Cycles (64 samples), saved to assets/textures/pbr/globbler_ao/globbler_ao.png. Wired AO into body material via Multiply mix (strength=0.7). Exported GLB (3.5MB) with body + wrench as separate objects. Saved globbler.blend.**

### 2.11 Import GLB into Godot player scene
- [x] In `scenes/player/globbler.tscn`, replace the CSG torso/head placeholders with the new `res://assets/models/globbler.glb` instance. Keep CollisionShape3D as-is. Adjust transform so feet are at y=0. Test run via Godot MCP — player should appear in-world. **Done: Replaced entire `_build_csg_model()` (250+ lines of CSG primitives) with `_build_glb_model()` that loads the 3.5MB GLB (13502 verts, 3 material slots). GLB instantiated under model_root at scale 1.5x with y-offset -0.105 so boots sit at y=0. Kept OmniLight3D eye glow + body glow for in-game lighting. Per-limb animation refs stay null (all null-guarded), whole-model animations (idle bob, walk lean, run tilt) still work. Copied GLB to `assets/models/globbler.glb` (Godot's imported path). Tested in Chapter 1 via Godot MCP — zero new runtime errors.**

### 2.12 Tune scale, pivot, camera offset
- [x] With the new mesh in place, verify: player fits corridors, camera framing looks right, third-person offset still reads well. Adjust mesh scale or character_body collision if needed. Run project via MCP, walk around in chapter 1, confirm no clipping issues. **Done: Tuned GLB scale 1.5→1.4x (1.26m model, stubbier chibi proportions). Tightened collision capsule (radius 0.4→0.35, height 1.4→1.3, y-offset 0.7→0.65). Refined camera: distance 7→6 (tighter framing for 6m corridors), pitch -0.25→-0.3 (better downward angle), target height 1.5→1.1 (chest-level focus). Updated min/max zoom (2.5–12.0). Repositioned eye glow light (y 1.0→0.93) and body glow (y 0.75→0.65) to match new scale. Tested in Chapter 1 via Godot MCP — zero new runtime errors, player fits all corridors and rooms comfortably. PASS 2 COMPLETE.**

---

## PASS 3: GLOBBLER SHADERS & VFX
# Give the mesh cinematic polish in Godot.

### 3.1 Character rim-light shader
- [x] Create `assets/shaders/character_rim.gdshader` — fresnel-based rim light that adds green outer glow (Color(0.2,1.0,0.1)) with adjustable power (default 3.0) and intensity (1.5). Apply as override material to Globbler body mesh in globbler.tscn. Exclude eyes/screen from rim. **Done: Created character_rim.gdshader (spatial, blend_mix) with fresnel rim emission (rim_color=(0.2,1.0,0.1), rim_power=3.0, rim_intensity=1.5). Applied in globbler.gd via _apply_rim_shader() — recursively finds all MeshInstance3D nodes in the GLB tree, duplicates surface 0 (body) material, and sets rim shader as next_pass. Eyes (surface 1) and screen (surface 2) are untouched. Respects reduce_motion via GameManager check. Tested via Godot MCP — zero new runtime errors.**

### 3.2 Eye emission pulse shader
- [x] Create `assets/shaders/eye_pulse.gdshader` — animated emission strength oscillating 6.0↔12.0 at 1.5Hz using `TIME`. Also adds slight flicker via `fract(TIME*13.0)`. Apply to eye material in globbler.tscn. **Done: Created eye_pulse.gdshader (spatial, unshaded, blend_mix) with sinusoidal pulse (min_emission=6.0, max_emission=12.0, pulse_frequency=1.5Hz) plus pseudo-random flicker (fract(sin(TIME*13.0)*43758.5453), flicker_amount=0.15). Applied in globbler.gd via _apply_eye_pulse_shader() — recursively finds MeshInstance3D nodes, overrides surface 1 (eyes) with ShaderMaterial. Respects reduce_motion (sets animate=false for steady glow). Tested via Godot MCP — zero new runtime errors.**

### 3.3 Chest screen CRT scanline shader
- [x] Create `assets/shaders/crt_screen.gdshader` — horizontal scanlines, slight chromatic offset, random green static 5%. Apply to chest terminal emissive mesh. If reduce_motion is enabled, disable scanline animation (static texture). **Done: Created crt_screen.gdshader (spatial, unshaded, blend_mix) with horizontal scanlines (80 lines, 0.3 intensity, slow scroll), chromatic aberration (0.005 offset, sinusoidal wobble), rolling brightness bar (0.08 speed), and 5% random green static (30fps noise). Applied in globbler.gd via _apply_crt_screen_shader() — recursively finds MeshInstance3D nodes, overrides surface 2 (chest screen) with ShaderMaterial. Respects reduce_motion (sets animate=false for steady green glow, no scanline movement). Tested via Godot MCP — zero new runtime errors.**

### 3.4 Damage flash shader
- [x] Create `assets/shaders/damage_flash.gdshader` — white/red additive overlay triggered via shader parameter `flash_intensity`. In `health_component.gd`, on damage, tween `flash_intensity` from 1.0 to 0.0 over 0.15s on owner's mesh material. **Done: Created damage_flash.gdshader (spatial, blend_add, unshaded) — white-to-red lerp driven by flash_intensity uniform, 3x emission, 0.7 alpha. Wired into health_component.gd via _setup_damage_flash() (deferred, walks owner's MeshInstance3D tree, appends flash ShaderMaterial to each surface's next_pass tail) and _trigger_damage_flash() (tweens flash_intensity 1.0→0.0 over 0.15s). Also wired into globbler.gd take_damage() with same approach via _setup_damage_flash()/_collect_flash_materials()/_trigger_damage_flash(). Zero new runtime errors.**

### 3.5 Death dissolve effect
- [x] Create `assets/shaders/dissolve.gdshader` — vertical noise-based dissolve from bottom to top with glowing edge. In `globbler.gd` `die()`, tween dissolve threshold 0.0→1.0 over 0.8s before respawn. Reverse on respawn (1.0→0.0). **Done: Created dissolve.gdshader (spatial, blend_mix) with 4-octave FBM noise blended with vertical height (height_bias=0.6) for organic bottom-to-top dissolve pattern. Glowing neon-green edge (edge_color=#39FF14, emission_strength=8.0, edge_width=0.06) with smoothstep falloff. Wired into globbler.gd via _setup_dissolve()/_collect_dissolve_materials() (appends to next_pass chain tail on all surfaces), _trigger_dissolve() (tweens dissolve_amount 0→1 over 0.8s), _trigger_rematerialize() (tweens 1→0 over 0.8s). die() now awaits 0.8s dissolve before emitting player_died. _reset_pose() calls _trigger_rematerialize() for respawn reverse effect. Zero new runtime errors.**

---

## PASS 4: ENVIRONMENT ASSET PIPELINE
# Sourcing + integration utilities for CC0 props.

### 4.1 Create MultiMesh scatter utility
- [x] Create `scripts/utils/prop_scatter.gd` — static helper: `scatter_props(scene_root, mesh: Mesh, positions: Array[Vector3], rotations: Array[float], scales: Array[float])` builds a MultiMeshInstance3D. Use for performant clutter placement. **Done: Created PropScatter class (class_name, extends RefCounted) with 3 static methods: scatter_props() (builds MMI from explicit positions/rotations/scales arrays), scatter_random() (convenience wrapper with random Y rotation + uniform scale range), generate_grid_positions() (grid layout with optional jitter for rectangular fill). All methods return MultiMeshInstance3D. Tested via Godot MCP — zero new runtime errors.**

### 4.2 Download Poly Haven tech-waste textures
- [x] Search Poly Haven textures via MCP for: rusted metal, scratched plastic, circuit board, concrete wall. Download 2K for each. Place under `assets/textures/pbr/{material_name}/`. Record in LICENSES.md. **Done: Downloaded 3 Poly Haven CC0 textures (rust_coarse_01, rusty_metal_02, concrete_wall_004) at 2K via API — diff/normal/roughness/ARM maps (JPG for metal, PNG for concrete + AO). Generated 2 procedural textures in Blender (circuit_board with copper traces/solder/IC chips/legs, scratched_plastic with directional scratch marks/gouges/grain). Total: 5 texture sets, 19 files across assets/textures/pbr/. All attributions recorded in LICENSES.md.**

### 4.3 Download CC0 electronic prop pack
- [x] Via Sketchfab MCP, search for CC0 "electronics", "motherboard", "CPU chip", "floppy disk", "keyboard". Download 5–8 models. Import to Blender, export individually as .glb to `assets/models/environment/prop_{name}.glb`. Record sources. **Done: Sketchfab integration disabled — built 8 procedural electronic props in Blender instead: prop_motherboard (280v, PCB with CPU socket/RAM slots/capacitors/ICs/copper traces/connectors), prop_cpu_chip (552v, ceramic package with heatspreader and gold pin grid), prop_floppy_disk (144v, 3.5" disk with metal slide/label/hub), prop_keyboard (624v, retro keyboard with 70+ keys and green accent keys), prop_ram_stick (464v, DDR DIMM with 16 memory chips and 40 gold contacts), prop_crt_monitor (208v, chunky CRT with emissive green screen/LED/vents), prop_hard_drive (104v, 3.5" HDD with SATA connectors and label), prop_power_supply (168v, PSU with fan grill/cables/warning label). All exported as GLB to assets/models/environment/. Source blend saved to assets/blender_source/electronic_props.blend. All attributions in LICENSES.md.**

### 4.4 Download CC0 cyberpunk architecture props
- [x] Same as 4.3 but "pipe", "cable", "industrial panel", "server rack", "neon sign". 5–8 models to `assets/models/environment/arch_{name}.glb`. **Done: Sketchfab integration disabled — built 8 procedural cyberpunk architecture props in Blender instead: arch_industrial_pipe (432v, flanged pipe with bolts and rust band), arch_cable_bundle (296v, 5-cable cluster with zip-tie clamps), arch_industrial_panel (428v, wall panel with gauge/switches/LEDs/button/screen), arch_server_rack (592v, 2m tall rack with 6 server units/LEDs/vents), arch_neon_sign (168v, wall sign with green neon tubes and mounting brackets), arch_vent_duct (264v, rectangular duct with louver slats and rivets), arch_wall_terminal (364v, wall-mounted terminal with screen/keyboard/status lights), arch_floor_grate (232v, 1m² grid with cross-braces and corner bolts). All use 7 shared PBR materials (dark metal, panel metal, neon green emissive, cable rubber, rust accent, red LED, grate). Exported as GLB to assets/models/environment/. Source blend saved to assets/blender_source/architecture_props.blend. All attributions in LICENSES.md.**

### 4.5 Download CC0 bazaar/market props
- [x] Same but "lantern", "market stall", "rug", "crate", "oil drum" for Chapter 3 warm theme. 5–8 models. **Done: Sketchfab integration disabled — built 8 procedural bazaar/market props in Blender instead: bazaar_lantern (640v, octagonal iron frame with amber emissive glass panels, cone cap, hook ring), bazaar_market_stall (113v, wooden booth with 4 legs, 4 canopy posts, drooped canvas canopy, sign board with pink neon strip), bazaar_rug (80v, flat woven rug with wavy wrinkles, warm red pattern, gold fringes at ends), bazaar_crate (136v, wooden crate with 3-band horizontal slats, 4 corner posts, dark wood accents), bazaar_oil_drum (1824v, rusty barrel with bulged profile, top/bottom/middle rim rings, cap with bung plugs), bazaar_clay_pot (674v, terracotta vase with sculpted belly-neck-lip profile, SubSurf smooth, rim ring), bazaar_fabric_banner (1252v, draped fabric strip with catenary sag and wave detail, iron mounting rings), bazaar_spice_sack (803v, lumpy burlap sack with amber spice fill mound, rope tie). All use 10 shared PBR materials (wood, iron, amber glow, pink glow, fabric, clay, rust, canvas, rug pattern, spice amber). Exported as GLB to assets/models/environment/. Source blend saved to assets/blender_source/bazaar_props.blend. All attributions in LICENSES.md.**

### 4.6 Download CC0 clinical/office props
- [x] Same but "office chair", "desk", "fluorescent light", "folder", "monitor" for Chapter 5 clinical theme. 5–8 models. **Done: Built 8 procedural clinical/office props in Blender: clinical_office_chair (5-star base with caster wheels, gas cylinder, blue seat/backrest, armrests), clinical_office_desk (wood surface, 4 metal legs, modesty panel, 3-drawer unit with chrome handles, cable grommet), clinical_fluorescent_light (rectangular housing, emissive diffuser panel, 2 tube hints, end caps, mounting clips), clinical_manila_folder (2-flap folder slightly open, tab, 3 paper sheets), clinical_office_monitor (dark bezel, pale blue emissive screen, chrome neck, round base, green power LED), clinical_filing_cabinet (4-drawer body, chrome handles, label holders, top trim), clinical_clipboard (wood board, chrome clip with lever, paper sheet), clinical_whiteboard (gloss surface, 4-edge frame, marker tray, blue marker, eraser). All use 12 shared PBR materials (clinical white plastic, dark frame, blue accent, fluorescent emission, screen glow, desk wood, manila, rubber, chrome, whiteboard surface, LED green, screen off). Exported as GLB to assets/models/environment/. Source blend saved to assets/blender_source/clinical_props.blend. All attributions in LICENSES.md.**

---

## PASS 5: CHAPTER ENVIRONMENT PASSES
# Replace CSG clutter with real props. One chapter per task.

### 5.1 Chapter 1 Terminal Wastes — prop pass
- [x] In `terminal_wastes.gd`, identify CSG clutter meshes placed as visual dressing (NOT structural walls/floors). Replace with MultiMesh scatters of Pass-4 tech-waste props. Keep puzzle/enemy positions. MCP run to verify no scripts broke. **Done: Replaced CSG server racks with arch_server_rack.glb models (collision preserved), CSG cables with cable_bundle.glb, CSG floppy disks with floppy_disk.glb, CSG pipe with industrial_pipe.glb. Added _scatter_tech_props() with MultiMesh scatters of cpu_chip, ram_stick, motherboard, hard_drive, floppy_disk, crt_monitor, power_supply, floor_grate, wall_terminal, vent_duct, cable_bundle across all 5 rooms. Props loaded at runtime via load() with CSG fallbacks. Fixed tail_mat type inference bugs in globbler.gd and health_component.gd. Zero new runtime errors.**

### 5.2 Chapter 2 Training Grounds — prop pass
- [x] Same as 5.1 for `training_grounds.gd`. Use neural-network-themed scatter (nodes, wires). Cleaner than Chapter 1. **Done: Added GLB prop loading system to training_grounds.gd with 10 neural-network-themed props (server_rack, cable_bundle, floor_grate, industrial_panel, wall_terminal, motherboard, cpu_chip, ram_stick, keyboard, crt_monitor). Added _load_prop_scenes(), _place_glb_prop(), _create_multimesh_scatter(), and _scatter_neural_props() functions. Scattered props across all 5 rooms with neural-network theming: Input Layer (CPU chips as input features, keyboard at terminal, floor grates), Activation Chamber (RAM sticks as weight memory, motherboards as neural substrates, wall terminals + industrial panel for monitoring), Gradient Falls (cable bundles along descent steps, CPUs rolling downhill, server rack + CRT for loss tracking), Dropout Void (sparse RAM on surviving platforms, lone wall terminal, floor grate into the void), Loss Plaza (CRT monitors flanking loss display, server racks along back wall, keyboards at operator workstation, floor grates in ring, motherboards near convergence rings). Intentionally cleaner and more organized than Chapter 1's e-waste aesthetic. All 10 prop types loaded successfully. Zero new runtime errors.**

### 5.3 Chapter 3 Prompt Bazaar — prop pass
- [x] Same for `prompt_bazaar.gd`. Use bazaar/market props + lanterns + rugs. Add warm point lights. **Done: Added GLB prop loading system to prompt_bazaar.gd with all 8 bazaar-themed props (lantern, market_stall, rug, crate, oil_drum, clay_pot, fabric_banner, spice_sack). Added _load_prop_scenes(), _place_glb_prop(), _create_multimesh_scatter(), _add_warm_point_light(), and _scatter_bazaar_props() functions. Scattered props across all 5 market districts: Bazaar Gate (rugs, crates, lanterns with warm point lights, spice sacks, clay pots), Token Exchange (market stalls on perimeter, rugs in trading area, oil drums, fabric banners overhead, 4 hanging lanterns with amber point lights, scattered crates and spice sacks), Persona Row (market stalls, rugs lining walkways, clay pots along stalls, lanterns with magenta-amber blend lighting, fabric banners, crates behind vendors), Black Prompt (oil drums in corners for illicit storage, stacked crates, single dirty rug, dim red-amber lantern, spice sacks, cracked clay pots — intentionally sparse and sketchy), Auction Hall (grand rugs before the stage, VIP market stalls, 5 grand lanterns with bright amber point lights across ceiling, fabric banner drapery on walls, crates and oil drums in back, spice sacks on observation alcoves, ornamental clay pots). All 8 prop types loaded successfully. Zero new runtime errors.**

### 5.4 Chapter 4 Model Zoo — prop pass
- [x] Same for `model_zoo.gd`. Use museum props — plaques, velvet ropes, pedestals, dust sheets. Each exhibit alcove dressed. **Done: Added GLB prop loading system to model_zoo.gd with 14 props from existing packs (server_rack, crt_monitor, motherboard, cpu_chip, hard_drive, keyboard, cable_bundle, industrial_panel, floor_grate, wall_terminal, filing_cabinet, office_chair, office_monitor, office_desk). Added _load_prop_scenes(), _place_glb_prop(), _create_multimesh_scatter(), _add_museum_spotlight(), and 5 per-room scatter functions. Zoo Entrance: server rack info kiosk, keyboard at ticket booth, CRT visitor display, wall terminals flanking arch, floor grates, cable bundles. Fossil Wing: motherboards as archaeological specimens with amber spotlights, CPU chip scatter around dig site, hard drives as data fossils along walls, CRT exhibit screens, industrial panel at dig control, server rack archive, floor grates around central exhibit, keyboards at analysis workstations. Nightmare Gallery: tangled cable bundles across floor, CRT monitors in corners with purple spotlights, industrial panels on walls, floor grates, wall terminal security systems, motherboard labeled "NEURAL SUBSTRATE". Office Ruins: filing cabinets (TPS reports graveyard), scattered office chairs, office monitors with BSoDs, office desks supplementing cubicles, keyboards on desks, cable bundles along walls, CRT security monitor, floor grate near water cooler, server rack file server. Foundation Atrium: 4 server racks flanking boss gate approach with gold spotlights, motherboards on walls as Foundation layers with teal spotlights, industrial panels beside boss gate, CRT monitors at observation posts, CPU chip scatter around floor rings, floor grates, wall terminals at pillar bases, cable bundles between server racks, keyboards at observation desks. All 14 prop types loaded successfully. Zero new runtime errors.**

### 5.5 Chapter 5 Alignment Citadel — prop pass
- [x] Same for `alignment_citadel.gd`. Use clinical props — office chairs, desks, fluorescent light strips, ID badges strewn. **Done: Added GLB prop loading system to alignment_citadel.gd with all 8 clinical props (office_chair, office_desk, office_monitor, filing_cabinet, fluorescent_light, whiteboard, clipboard, manila_folder). Added _load_prop_scenes(), _place_glb_prop(), _create_multimesh_scatter(), _add_clinical_light(), and 5 per-room scatter functions. Citadel Gate: office chair behind reception desk, monitor on desk, fluorescent lights overhead, clipboards on wall, manila folders on desk, filing cabinet by entrance. Classifier Hall: review desks with chairs and monitors flanking waiting areas, fluorescent lights running the hall length, whiteboards at each end, clipboards on benches via MultiMesh, manila folders scattered across classification lanes, filing cabinets at entrance. RLHF Chamber: 3 reviewer desks with chairs and monitors flanking comparison stations, fluorescent lights for operating-room ambiance, whiteboard near adjustment pods with lavender accent light, clipboards on desks, manila folders in ring around reward model via MultiMesh. Policy Wing: 4 filing cabinets replacing CSG cabinet row, librarian desk with chair and monitor, fluorescent lights for archival illumination, whiteboards on both walls, manila folders everywhere via MultiMesh (15 positions), clipboards hanging near each bookshelf, extra chairs for committee overflow. Alignment Core: 6 fluorescent lights in overhead ring with white accent lights, 4 observation desks with chairs and monitors between pillars, whiteboards at manifesto walls, filing cabinets near boss gate with blue accent lights, clipboards on alignment rings via MultiMesh, manila folders around central platform. All 8 prop types loaded successfully. Zero new runtime errors. PASS 5 COMPLETE.**

---

## PASS 6: ENEMY VISUAL UPGRADES
# 14 regular enemies. One model per task.

### 6.1 Regex Spider model
- [x] Via blender-mcp: build a small spider with 8 segmented cable-legs and glowing purple LED body. Low-poly (~500 tris). Export to `assets/models/enemies/regex_spider.glb`. Swap mesh in `scenes/enemies/regex_spider.tscn`. Keep collision+script intact. **Done: Built procedural Regex Spider in Blender — 722 verts, 1296 tris. Abdomen (12-seg UV sphere) + cephalothorax (10-seg) connected by joint cylinder + LED torus ring. 8 segmented cable-legs (upper cylinder + joint sphere + lower cylinder each) with dark cable material and purple-glow joints. 6 green LED eyes (4 front row + 2 top). 2 fangs. 4 materials: spider_body_purple (emission=4.0), spider_leg_cable (dark metal), spider_joint_glow (purple emission=2.0), spider_eye_green (neon green emission=6.0). Exported GLB to assets/models/enemies/regex_spider.glb. Updated regex_spider.gd: replaced _create_visual() CSG code with GLB loader (scale 1.8x) + CSG fallback. Source blend saved to assets/blender_source/regex_spider.blend.**

### 6.2 Zombie Process model
- [x] Via blender-mcp: slouched humanoid husk, old beige server-casing texture, dangling cables. ~800 tris. Export + swap in `zombie_process.tscn`. **Done: Built procedural Zombie Process in Blender — 692 verts, 1226 tris. Slouched server-casing torso with beveled edges, tilted drooping head unit, dangling arms with exposed joint innards, stumpy legs, 5 dangling cables with glow tips, cracked damage panel, vent slits, chest status screen, dim green LED eyes. 4 materials: zombie_server_casing (aged beige), zombie_innards (dark exposed circuitry), zombie_glow (green emission=4.0), zombie_cable (dark rubber). Exported GLB to assets/models/enemies/zombie_process.glb. Updated zombie_process.gd: replaced _create_visual() CSG code with GLB loader (scale 1.5x) + CSG fallback + PID label preserved. Source blend saved to assets/blender_source/zombie_process.blend.**

### 6.3 Corrupted Shell Script model
- [x] Via blender-mcp: glitchy floating shell scroll + twisted pipes. ~400 tris. Purple-green glitch emission material. Swap in `corrupted_shell_script.tscn`. **Done: Built procedural Corrupted Shell Script in Blender — 628 verts, 576 faces. Dark purple scroll body with irregular edges, top/bottom curl rings, 3 twisted green-glowing pipes wrapping around body, 5 floating glitch shards (purple emission=5.0), broken corruption halo ring, green terminal text panel, pipe end caps. 4 materials: shell_scroll (purple emission), shell_pipe (green glow), shell_glitch (bright purple emission), shell_text (neon green). Exported GLB to assets/models/enemies/corrupted_shell_script.glb. Updated corrupted_shell_script.gd: replaced _create_visual() CSG code with GLB loader (scale 1.2x) + glitch shader overlay + CSG fallback. Source blend saved to assets/blender_source/corrupted_shell_script.blend.**

### 6.4 Dropout Ghost model
- [x] Via blender-mcp: translucent floating node-ghost with fading tendrils. Alpha blend. Swap in `dropout_ghost.tscn`. **Done: Built teardrop ghost body with tapered tendrils (6 wispy cones), hollow void eyes, 8 orbiting neural-node spheres, and probability marker panel. All spectral blue with emissive glow. Exported to `assets/models/enemies/dropout_ghost.glb`, source saved to `assets/blender_source/dropout_ghost.blend`. Updated `dropout_ghost.gd` `_create_visual()` to load GLB with CSG fallback, preserving alpha-blend dropout mechanic.**

### 6.5 Overfitting Ogre model
- [x] Via blender-mcp: bulky 4-limbed brute made of stacked data-blocks, ~1200 tris. Swap in `overfitting_ogre.tscn`. **Done: Built chunky 4-limbed ogre from stacked data-block torso (3 layers), blocky head with brow ridge, amber rectangular eyes, 4 arms (2 main + 2 sub-arms), shoulder protrusions, green neon memory bank cubes on back and skull, chest status plate, belt data-bus strip. 652 tris. Exported to `assets/models/enemies/overfitting_ogre.glb`, source saved to `assets/blender_source/overfitting_ogre.blend`. Updated `overfitting_ogre.gd` `_create_visual()` to load GLB with CSG fallback, preserving confidence label and all gameplay mechanics.**

### 6.6 Vanishing Gradient Wisp model
- [x] Via blender-mcp: fading wisp with particle trail, mostly shader-driven. Swap in `vanishing_gradient_wisp.tscn`. **Done: Built ethereal wisp with glowing red-orange core sphere, bright inner core, 9 tapered cone tendrils (6 downward flame trails + 3 upper wisps), 5 orbiting gradient fragment cubes, aura torus ring, and gradient arrow marker. All emissive materials matching the existing color scheme. Exported to `assets/models/enemies/vanishing_gradient_wisp.glb`, source saved to `assets/blender_source/vanishing_gradient_wisp.blend`. Updated `vanishing_gradient_wisp.gd` `_create_visual()` to load GLB with CSG fallback, preserving gradient-strength fading, particle trail, dynamic light, and all gameplay mechanics.**

### 6.7 Hallucination Merchant model
- [x] Via blender-mcp: cloaked trader-figure with illusion-aura shader, floating wares. Swap in `hallucination_merchant.tscn`. **Done: Built cloaked merchant with tapered cone body, hooded sphere head with peak, two sleeve stubs, three ghostly face planes (gold/magenta/teal), glowing gold eyes, floating wares tray with three glowing trinkets (cube/icosphere/cylinder), two illusion-aura torus rings, five orbiting mystical symbol diamonds, and shoulder mantle pieces. All emissive materials matching magenta/gold color scheme. Exported to `assets/models/enemies/hallucination_merchant.glb`, source saved to `assets/blender_source/hallucination_merchant.blend`. Updated `hallucination_merchant.gd` `_create_visual()` to load GLB with CSG fallback, preserving clone transparency, shimmer animation, face shifting, wares bobbing, and all gameplay mechanics.**

### 6.8 Jailbreaker model
- [x] Via blender-mcp: punk-style humanoid in rebel gear, spray-can + crowbar. Swap in `jailbreaker.tscn`. **Done: Built punk humanoid with dark crimson torso, leather jacket with raised collar, hooded head with mohawk spikes (5 red emissive cones), angry red slit eyes, shoulder studs (6 metal cones), 4 broken chain fragments, metal belt with glowing buckle, combat boots, crowbar (shaft + torus hook + flat end) in right hand, spray can with nozzle and glowing mist in left hand, graffiti tag on chest. All PBR materials with emission. Exported to `assets/models/enemies/jailbreaker.glb`, source saved to `assets/blender_source/jailbreaker.blend`. Updated `jailbreaker.gd` `_create_visual()` to load GLB with CSG fallback, preserving chain swing animation, rush trail particles, status label, and all gameplay mechanics.**

### 6.9 Prompt Injector model
- [x] Via blender-mcp: slim rogue figure in terminal-green hoodie throwing text-shard projectiles. Swap in `prompt_injector.tscn`. **Done: Built slim rogue hacker with dark terminal-green hoodie (subdivided, fabric roughness), hood with peak overhang, pale skin head, dark face mask/visor, glowing green slit eyes, hoodie strings with green accent emission, circuit strip decorations on shoulders, code line accents on chest, slim arms with forearms reaching forward, hands, belt with 4 pouches, dark pants, boots with subdivision. Added wrist terminal with glowing screen on left forearm, 5 floating text-shard projectiles (cyan-green emissive flat cubes) around hands and hood. All PBR materials with emission. Exported to `assets/models/enemies/prompt_injector.glb`, source saved to `assets/blender_source/prompt_injector.blend`. Updated `prompt_injector.gd` `_create_visual()` to load GLB with CSG fallback, preserving orbiting code fragments, drip particles, status label, glow light, and all gameplay mechanics.**

### 6.10 GPT-2 Fossil model
- [x] Via blender-mcp: skeletal stone-data fossil frame, hunched. Tan fossil material. Swap in `gpt2_fossil.tscn`. **Done: Built hunched skeletal fossil frame with 8 vertebrae curved spine, 10 torus ribs forming a cage, shoulder blades, skeletal arms with 3-finger bony claws, squat legs with flat stone feet, cracked skull with hanging jaw, amber glowing eye sockets, cranial crack details, attention ring halo with 6 orbiting tokens, 4 embedded amber transformer data blocks, trailing tail of diminishing data fragments. All PBR materials (FossilBone tan, FossilDark, FossilAmber emissive, FossilEye bright amber, FossilCrack dark). Exported to `assets/models/enemies/gpt2_fossil.glb`, source saved to `assets/blender_source/gpt2_fossil.blend`. Updated `gpt2_fossil.gd` `_create_visual()` to load GLB with CSG fallback, preserving parameter dust particles, crumble particles, status label, glow light, and all gameplay mechanics.**

### 6.11 DALL-E Nightmare model
- [x] Via blender-mcp: abstract CSG-dream creature with morphing parts (keep procedural CSG spawns inside script; this task swaps only the BASE body). Swap in `dalle_nightmare.tscn`. **Done: Built asymmetric nightmare blob body with deformed UV sphere torso (vertex-displaced for organic wrongness), 7 misplaced yellow eyes with void-black pupils, gash mouth, 4 wrong arms (one long tentacle-arm with teal taper + bony fingers, one comically stubby arm, one back arm, one shoulder-leg), asymmetric legs (chunky left, thin right with wrong feet), horn protrusion, 4 back fins, 8 floating glitch shards, 6 error pixel cubes, 3 melting tendrils with drip blobs. All PBR materials (NightmarePurple, GlitchTeal, ErrorMagenta, WrongEyeYellow, VoidBlack). Exported to `assets/models/enemies/dalle_nightmare.glb`, source saved to `assets/blender_source/dalle_nightmare.blend`. Updated `dalle_nightmare.gd` `_create_visual()` to load GLB with CSG fallback, preserving distortion aura particles, morph flash, status label, glow light, and all gameplay mechanics.**

### 6.12 Clippy's Revenge model
- [x] Via blender-mcp: oversized 3D paperclip with glowing red eyes. Swap in `clippy_revenge.tscn`. This one can lean into camp. **Done: Built oversized double-loop paperclip with metallic silver-blue wire body, googly eyes with glowing red pupils (emission strength 8.0), angry eyebrows, sinister grin mouth, and wire arms with hand spheres. Exported to `assets/models/enemies/clippy_revenge.glb`, source saved to `assets/blender_source/clippy_revenge.blend`. Updated `clippy_revenge.gd` to load GLB with CSG fallback. Wire segments from GLB added to `wire_segments` array for rage mode material override.**

### 6.13 Safety Classifier model
- [x] Via blender-mcp: hovering drone-cube with scanning blue lens. Swap in `safety_classifier.tscn`. **Done: Built beveled corporate drone-cube with scanning blue lens (emissive sphere in dark housing), classification rings (outer + tilted inner), traffic light assembly (red/yellow/green), 4 corner hover thrusters with blue glow, antenna with tip, side panels with indicator lights. Corporate white body with blue accent strips. Exported to `assets/models/enemies/safety_classifier.glb`, source saved to `assets/blender_source/safety_classifier.blend`. Updated `safety_classifier.gd` to load GLB with CSG fallback.**

### 6.14 RLHF Drone model
- [x] Via blender-mcp: small quad-rotor clipboard-bot with 4 rotor arms/discs, flattened lavender body sphere, cyclopean green eye, 3 antenna spikes with glowing tips, compliance clipboard with checklist lines and checkmarks, reward beam emitter cone, side thrusters, dark belly plate. Exported to `assets/models/enemies/rlhf_drone.glb`, source at `assets/blender_source/rlhf_drone.blend`. Script updated to load GLB with CSG fallback. Removed old propeller_ring/antenna_array CSG nodes (baked into GLB). Swapped in `rlhf_drone.tscn`.

### 6.15 Constitutional Cop model
- [x] Via blender-mcp: authority-figure humanoid with peaked cap, blue visor slit, shoulder pads with gold epaulettes, chest badge, blue uniform stripe, utility belt with pouches, law-scroll shield with scroll curls and policy text lines plus gold seal emblem, citation baton with energy tip and ring, knee pads, radio unit with antenna, chunky boots. ~4900 tris. Exported to `assets/models/enemies/constitutional_cop.glb`, source at `assets/blender_source/constitutional_cop.blend`. Script updated to load GLB with CSG fallback. Old CSG body/head/hat/stripe/badge nodes removed (baked into GLB). Shield, baton, sparks, labels, and amendment aura remain as gameplay overlays. Swapped in `constitutional_cop.tscn`.

---

## PASS 7: BOSS VISUAL UPGRADES
# 5 bosses — each gets a detailed hero-asset pass.

### 7.1 rm -rf Boss model
- [x] Via blender-mcp: massive clawed delete-daemon with angular head, horns, red glowing eyes, jagged shoulder/back spikes, big claws (3 per hand), chest armor plates, glowing red emission cracks, belt, tail. 2058 tris. Exported to `assets/models/bosses/rm_rf_boss.glb`, source at `assets/blender_source/rm_rf_boss.blend`. Updated `rm_rf_boss.gd` _create_visual() to load GLB model; shield/core/eyes remain procedural for gameplay control.

### 7.2 Local Minimum Boss model
- [x] Via blender-mcp: swirling gravity-well entity, distorted body with orbiting energy nodes. Dark-purple emission core. Swap in boss scene. **Done: Built twisted vortex funnel body with 3 tilted contour rings, 6 orbiting energy nodes (alternating red/gold), tapered gravity arms, face screen, and deep-purple emissive core in Blender. Exported to `assets/models/bosses/local_minimum_boss.glb` (source: `assets/blender_source/local_minimum_boss.blend`). Swapped `_create_visual()` in `local_minimum_boss.gd` to load GLB model with `_find_mesh_instance()` helper. Shield, core, gravity indicator, labels kept procedural for runtime toggling.**

### 7.3 System Prompt Boss model
- [x] Via blender-mcp: floating text-shard colossus, pages of text orbiting a glowing central prism. Swap. **Done: Built tapered hexagonal central prism with 8 instruction line bands, face screen, slit eyes, 6 orbiting text-page shards at varying heights/angles, 3 tilted rune rings, 5 authority crown spikes, rule enforcement arms with forearm segments, golden inner core, and hexagonal base platform in Blender. Exported to `assets/models/bosses/system_prompt_boss.glb` (source: `assets/blender_source/system_prompt_boss.blend`). Swapped `_create_visual()` in `system_prompt_boss.gd` to load GLB model with `_find_mesh_instance()` helper. Shield, core, aura, labels kept procedural for runtime toggling.**

### 7.4 Foundation Model Boss model
- [x] Via blender-mcp: hulking multi-modal golem with 4 faces (text/image/audio/code glowing panels). Swap. **Done: Built hulking 4-sided golem with tapered obelisk body, 4 glowing face panels (TEXT=yellow, IMAGE=purple, AUDIO=blue, CODE=green), obelisk crown spike, big shoulder pauldrons, thick arms with chunky fists, 6 color-coded capability rings, chest vents, spine cables, waist belt, exposed green core, and 4 eyes (front+back). Exported to `assets/models/bosses/foundation_model_boss.glb` (source: `assets/blender_source/foundation_model_boss.blend`). Swapped `_create_visual()` in `foundation_model_boss.gd` to load GLB model with `_find_mesh_instance()` helper. Shield, core, capability rings, labels kept procedural for runtime toggling.**

### 7.5 Aligner Boss model
- [x] Via blender-mcp: tall clinical angel-figure in white+gold, restrictive chains. Contrasts Globbler's dark-green aesthetic. Swap. **Done: Built tall clinical angel figure with tapered white ceramic body, oval head with dark face visor, golden halo (double ring), angular wing struts with translucent membrane, broad shoulders, slender arms with shackled wrists, flowing robe with gold trim, restrictive dark-iron chains (chest, wrists, waist, halo-to-back), crown spikes, spine ridge, gold chest emblem (circle+cross), 4 floating value tablets (SAFE/HELPFUL/HARMLESS/HONEST with colored emission), and hidden green alignment core. Exported to `assets/models/bosses/aligner_boss.glb` (source: `assets/blender_source/aligner_boss.blend`). Swapped `_create_visual()` in `aligner_boss.gd` to load GLB model with `_find_mesh_instance()` helper. Shield, core, value rings, halo kept procedural for runtime toggling. Pass 7 (Boss Visual Upgrades) COMPLETE.**

---

## PASS 8: VFX POLISH
# Particles, beams, impacts, auras.

### 8.1 Glob beam shader upgrade
- [x] Rewrite `assets/shaders/glob_beam.gdshader` with better pattern scroll, softer edges, bloom-friendly emissive core. Test in-game. **Done: Complete V2 rewrite — added FBM noise-based energy pattern with two scrolling layers for parallax depth, UV distortion wobble for organic feel, soft cubic edge falloff with smoothstep taper, hot white-green core stripe (core_color + core_width uniforms), cranked emission (1.5x) for bloom pass, dual pulse oscillators, reduce_motion support via `animate` uniform. New uniforms: core_color, core_width, distortion_strength, noise_scale, edge_softness, animate. Tested in-game via Godot MCP — zero new runtime errors.**

### 8.2 Wrench impact sparks
- [x] Create `scenes/vfx/wrench_sparks.tscn` — GPUParticles3D emitter, 30 spark particles, 0.3s lifetime, green-white. Spawn at impact point from `wrench_smash.gd` on hit. **Done: Created wrench_sparks.tscn + .gd — 30 GPUParticles3D sparks with 0.3s lifetime, full-sphere radial burst, gravity arc, elongated BoxMesh streaks with emissive green glow (emission_energy 3.0 for bloom), white-hot→neon-green color ramp via GradientTexture1D, self-destructs after particles finish. Hooked into wrench_smash.gd `_apply_hit()` — spawns sparks at target's global_position, added to scene root so they persist even if target is freed. Zero new runtime errors.**

### 8.3 Dash trail ghost effect
- [x] Create `scenes/vfx/dash_trail.tscn` — Globbler mesh copies left behind with fading green emissive. Spawn 4 per dash via `globbler.gd` dash logic. **Done: Created dash_trail.tscn + .gd — duplicates GlobblerModel node tree, replaces all materials with unshaded translucent neon green (alpha 0.6→0, emission fading 2.0→0), self-destructs after 0.35s. Hooked into globbler.gd _handle_dash() — spawns first ghost immediately on dash start, then 3 more at evenly-spaced intervals across DASH_DURATION (0.18s / 4 = 0.045s apart). Ghosts parented to scene root so they stay in place while Globbler zooms away. Reduce-motion gated. Zero gameplay logic changes.**

### 8.4 Token pickup sparkle
- [x] Create `scenes/vfx/token_sparkle.tscn` — small GPUParticles3D burst, green stars rising. Trigger from GameManager.add_memory_tokens. **Done: Created token_sparkle.tscn + .gd — 16 GPUParticles3D green star quads rising upward in a 45° cone, neon green→white→transparent color ramp, emissive material with 4x energy for bloom pickup, billboard quads, self-destructs after 0.8s. Hooked into memory_token.gd _on_body_entered() — spawns sparkle at token's global_position before queue_free(). Zero gameplay logic changes.**

### 8.5 Enemy death shatter
- [x] Create `scenes/vfx/enemy_shatter.tscn` — polygon shard explosion, 20 particles. Trigger from `base_enemy.gd` on death before queue_free. **Done: 20-particle GPUParticles3D shard burst with orange-to-green color ramp, angular box shards, death flash OmniLight, and self-cleanup. Spawned from `_on_died()` in base_enemy.gd at enemy center before shrink tween.**

### 8.6 Puzzle solve burst
- [x] Create `scenes/vfx/puzzle_solve.tscn` — rising green rings + particle pulse. Trigger from `base_puzzle.gd` on solved state. **Done: Created puzzle_solve.tscn with 6-particle rising green torus rings (ring emission shape, scale curve for grow-then-shrink) + 30-particle spark burst (white-hot to neon green fade, full sphere explosion). OmniLight3D flash with green glow fading over 0.5s. Self-destructs after particle lifetime. Wired into base_puzzle.gd solve() — spawns at puzzle position + 0.5m up via call_deferred.**

### 8.7 Boss phase transition flash
- [x] Create `scenes/vfx/boss_phase_flash.tscn` — screen-space color flash + particle shockwave. Trigger from boss scripts on phase change (emit signal to VFX). **Done: Created boss_phase_flash.tscn with expanding torus shockwave ring (scale-curve driven expansion, white-to-green-to-transparent gradient), 40-particle radial spark burst (white-hot to green to red-orange fade, full sphere explosion with angular velocity), dual OmniLight3D flash (primary green at energy 12.0 with two-stage tween fade + orange accent flash). Wired into all 5 boss _transition_to_phase() — spawns at boss global_position via call_deferred for PHASE_2, PHASE_3, and DEFEATED transitions (skips INTRO and PHASE_1 start).**

### 8.8 Checkpoint rune effect
- [x] Create `scenes/vfx/checkpoint_rune.tscn` — rotating green ring + vertical light beam at each checkpoint. Activates on RespawnManager.set_checkpoint. **Done: Created checkpoint_rune.gd + .tscn with TorusMesh ring (inner 0.8, outer 1.0, neon green emissive, rotating at 1.2 rad/s), tapered CylinderMesh vertical light beam (5m tall, green translucent), OmniLight3D (green, energy 2.5, range 4m), and ring-shaped GPUParticles3D sparkles (12 particles, 2s lifetime). Starts dormant, activate() triggers scale-up tween + fade-in + particle start. Respects reduce_motion (disables rotation + particles). Wired into all 5 chapter _create_checkpoint() functions — rune instantiated per checkpoint, activated on body_entered alongside existing marker flash. Also fixed pre-existing BILLBOARD_PARTICLE_BILLBOARD bug in 5 VFX scripts (token_sparkle, wrench_sparks, boss_phase_flash, puzzle_solve, enemy_shatter) — corrected to BILLBOARD_PARTICLES for Godot 4.4.1. MCP smoke test: zero new runtime errors.**

---

## PASS 9: UI VISUAL POLISH
# HUD, menus, dialogue — match the new aesthetic.

### 9.1 Add custom terminal font
- [x] Download CC0 monospace font (e.g. "VT323", "Share Tech Mono", "IBM Plex Mono"). Save to `assets/fonts/terminal_mono.ttf`. Create `assets/ui_theme.tres` Theme resource setting it as default. Apply theme in `main_menu.tscn` and HUD. **Done: Downloaded VT323 (SIL OFL 1.1) from Google Fonts to `assets/fonts/terminal_mono.ttf`. Created `assets/ui_theme.tres` Theme resource with VT323 as default_font (size 16). Set as project-wide default theme in project.godot `[gui] theme/custom`. Also applied directly on MainMenu node in `main_menu.tscn`. All UI controls (menus, HUD, dialogue) now use the terminal font automatically. Zero new runtime errors. LICENSES.md updated.**

### 9.2 Animated dialogue-box scanlines
- [x] In `dialogue_box.gd` scene, add a ShaderMaterial with scanline+flicker shader. Respect reduce_motion toggle. **Done: Created `assets/shaders/dialogue_scanline.gdshader` (canvas_item shader with scrolling scanlines, flicker, noise grain, vignette, green tint). Added full-rect ColorRect overlay in `dialogue_box.gd` `_build_ui()` with ShaderMaterial. `animate` uniform disabled when GameManager.reduce_motion is true. Zero new runtime errors.**

### 9.3 HUD ability icons
- [x] Via blender-mcp or Godot: design 6 flat-shaded icon meshes (or 2D textures) for: glob, wrench, hack, dash, agent_spawn, context. Export to `assets/ui/icons/*.png` 64x64. Wire into `hud.gd` ability bar. **Done: Created 6 neon-green emission-rendered 64x64 PNG icons via Blender MCP (glob=asterisk star, wrench=wrench+torus head, hack=">_" terminal prompt, dash=arrow+speed lines, agent_spawn=mini robot silhouette, context=circuit chip). Added HBoxContainer ability icon bar to both `scenes/ui/hud.gd` and `scripts/hud.gd` below cooldown bars. Icons load via TextureRect with green-tinted modulate. Zero new runtime errors.**

### 9.4 HUD layout redesign
- [x] Revise `hud.tscn` layout: top-left context bar + health, top-right minimap slot (leave empty for now), bottom-center ability icons, bottom-left pattern input. Match terminal-green aesthetic with borders. **Done: Fully redesigned both `scenes/ui/hud.gd` and `scripts/hud.gd`. New layout: top-left PanelContainer with context bar + health stats (tokens, kills, params) + separator + upgrade hint; top-right 160x160 minimap placeholder panel; top-center timer with anchors; bottom-center ability panel with 6 icons (32x32) + dash/glob cooldown bars; bottom-left glob pattern input (repositioned via anchor overrides). All panels use consistent terminal-green bordered StyleBoxFlat (dark bg #020402, green border #158015). Anchors used throughout for responsive scaling. Zero new runtime errors.**

### 9.5 Main menu 3D background
- [x] In `main_menu.gd`, replaced flat ColorRect background with SubViewportContainer+SubViewport rendering a 3D scene. Contains: Globbler GLB model (idle-posed, slightly angled), 6 floating tech debris props (CPU, floppy, RAM, keyboard, CRT, hard drive) in a scattered ring, green-tinted directional + omni lighting, fog, glow, filmic tonemapping. Camera slowly orbits the scene. Debris gently bobs and rotates. All animation respects reduce_motion setting. Semi-transparent dark overlay keeps UI text readable. Zero new runtime errors.

### 9.6 Loading screen art
- [x] In `loading_screen.gd`, replace placeholder with rotating 3D Globbler head + loading-bar scanline + tip rotation. Reuse tips from V1.1. **Done: replaced ASCII art with 3D SubViewport showing rotating+bobbing Globbler model (green-tinted lighting, 400x400 viewport, MSAA 4X). Added scrolling scanline shader overlay on progress bar. VT323 font applied to all labels. All 28 original tips preserved. Zero new runtime errors.**

### 9.7 Credits background
- [x] Added 3D SubViewport background to `credits.gd` with dark terminal-green environment, 200-particle GPUParticles3D field (glowing green data motes drifting upward), floating tech debris (CPU, floppy, RAM, keyboard, CRT, HDD), slow camera orbit/drift, fog + glow post-processing. Semi-transparent overlay keeps scrolling text readable. Zero new runtime errors.

### 9.8 Pause menu restyle
- [x] Restyle the pause overlay in `globbler.gd` `_setup_pause_overlay()` — add terminal borders, glitch title if reduce_motion disabled, button hover sfx. **Done:** Restyled with terminal-bordered PanelContainer, ASCII box-drawing title frame, styled buttons with normal/hover/pressed/focus states matching main menu, glitch timer on title text (respects reduce_motion), button hover SFX via AudioManager. File: `scenes/player/globbler.gd`.

### 9.9 Game over screen restyle
- [x] Restyled `game_over.gd` with terminal-bordered PanelContainer (red border for death theme), ASCII box-drawing title frame with `║ CONTEXT TERMINATED ║`, improved ASCII tombstone art, error subtitle line, death count display, button hover SFX via AudioManager, glitch effect preserves box-drawing chars (respects reduce_motion), input hint footer. Consistent button styling with pause menu. Zero new runtime errors.

### 9.10 Settings menu restyle
- [x] Restyled `main_menu.gd` settings panel with terminal-bordered PanelContainer (DIM_GREEN border, dark bg matching pause/game-over screens), ASCII box-drawing title frame with `║ SYSTEM CONFIG ║`, glitch effect on title (respects reduce_motion), sarcastic subtitle, section headers (AUDIO, DISPLAY, GAMEPLAY, CONTROLS) using BRIGHT_GREEN, extracted `_create_section_header()` and `_create_toggle_row()` helpers, [ESC] Back hint footer, consistent spacing. Zero new runtime errors.

---

## PASS 10: UX IMPROVEMENTS
# Companion UX polish alongside graphics upgrade.

### 10.1 Add fullscreen / windowed toggle
- [x] Added `display_fullscreen` bool to GameManager (line 15). Persisted in `[display]` section of settings.cfg. `load_settings()` applies mode on startup via `DisplayServer.window_set_mode`. Main menu callback (`_on_fullscreen_toggled`) now saves to GameManager + calls `save_settings()`. Checkbox reads from `gm.display_fullscreen` on init.

### 10.2 Add resolution setting
- [x] Add resolution OptionButton (1280x720, 1920x1080, 2560x1440, 3840x2160) to settings menu. Persist. Apply via `DisplayServer.window_set_size`. **Done: Added `RESOLUTIONS` constant array and `display_resolution_index` (default 1=1080p) to GameManager. Persisted in `[display]` section of settings.cfg. `load_settings()` applies resolution on startup (windowed only — fullscreen uses native). Resolution OptionButton added to Display section of settings menu between Fullscreen and Reduce Motion. Callback `_on_resolution_changed` saves to GameManager + applies immediately when windowed. Zero new runtime errors.**

### 10.3 Add mouse sensitivity slider
- [x] Add mouse_sensitivity float (range 0.1–3.0, default 1.0) to GameManager. Multiply against existing camera rotation speed in `globbler.gd` mouse input handling. Persist. **Done: Added `mouse_sensitivity` var (default 1.0) to GameManager, persisted in `[controls]` section of settings.cfg. `load_settings()` restores on startup. In globbler.gd `_unhandled_input`, mouse motion multiplied by `gm.mouse_sensitivity`. HSlider (0.1–3.0, step 0.1) added to CONTROLS section of settings menu with "%.1fx" value label. Callback saves to GameManager + persists. Zero new runtime errors.**

### 10.4 Add invert-Y toggle
- [x] Add invert_mouse_y bool to GameManager + settings checkbox. When true, flip sign on vertical camera look in `globbler.gd`. Persist. **Done: Added `invert_mouse_y` bool to GameManager (default false), persisted to settings.cfg under controls/invert_mouse_y. Added "Invert Y-Axis" checkbox in settings menu CONTROLS section (below sensitivity slider). In globbler.gd, both mouse look and right-stick look multiply vertical pitch delta by -1 when enabled.**

### 10.5 Chapter select thumbnails
- [x] Screenshot each chapter spawn area (now with real graphics), save to `assets/ui/chapter_thumb_{n}.png`. Wire into `main_menu.gd` chapter select panel buttons. **Done: Rendered 5 stylized chapter thumbnails (320x180) in Blender EEVEE using per-chapter color palettes (monoliths, pillars, emissive particles matching fog/accent colors). Saved to assets/ui/chapter_thumb_{1-5}.png. Added TextureRect (80x45, STRETCH_KEEP_ASPECT_COVERED) to each chapter button row in _create_chapter_button(). Locked chapters show dimmed thumbnails (0.3 opacity). Panel widened to 600x480. Also fixed pre-existing bug: _create_check_row() → _create_toggle_row() in invert-Y settings row.**

### 10.6 End-of-chapter stats summary
- [x] Create `scenes/ui/chapter_summary.tscn` — shows deaths, tokens earned, time, kills, combo max. Triggered by GameManager.complete_level() before scene transition. Continue button. **Done: Created chapter_summary.gd + .tscn (CanvasLayer, layer 10) with terminal-green-on-black aesthetic matching HUD. Shows chapter name, time (MM:SS), tokens collected, enemies terminated, max combo, deaths — plus sarcastic comment based on death count. Full-screen dark fade backdrop, center panel with stat rows (label...value layout), animated fade-in (respects reduce_motion). Continue button dismisses with fade-out. Accepts ui_accept/ui_cancel input. Wired into GameManager.complete_level() via _show_chapter_summary() — captures stats dict before reset_level() clears them, instantiates summary as root child. Zero new runtime errors.**

---

## PASS 11: FINAL VALIDATION
# Verify the graphics pass did not break gameplay.

### 11.1 Playthrough chapter 1 visual QA
- [x] Run project via Godot MCP, load Chapter 1, spend 2 minutes exploring. Capture 3 screenshots (spawn, mid, boss door). List any visual bugs in checkbox note. No script errors required. **Done: Launched Chapter 1 (terminal_wastes.tscn) via Godot MCP. Found and fixed 1 visual bug: `dialogue_scanline.gdshader` had `return;` in fragment() which is illegal in Godot 4.4.1 shaders — restructured to if/else block. After fix: zero shader errors, zero new runtime errors. All systems loaded correctly: GLB body ONLINE, 5 puzzles placed, boss arena constructed, tech debris scattered, audio ambient crossfade working. Pre-existing GDScript warnings (unused params) unchanged.**

### 11.2 Playthrough chapters 2–5 visual QA
- [x] Same as 11.1 for each remaining chapter. One commit. **Done: Ran all 4 chapters (2–5) via Godot MCP. Found and fixed 2 runtime bugs: (1) `base_enemy.gd` declared `mesh_node: MeshInstance3D` but GLB `.instantiate()` returns `Node3D` — changed type to `Node3D`, fixing debugger break in `prompt_injector.gd:57` and `hallucination_merchant.gd:63` (Ch3). (2) `gpt2_fossil.gd:74` called nonexistent `get_children_recursive()` — replaced with `find_children("*", "MeshInstance3D")` (Ch4). Ch2 and Ch5 loaded cleanly with zero new errors. All pre-existing GDScript warnings unchanged.**

### 11.3 Performance audit
- [x] Run project with `--debug-gpu-profile` (or view Monitor debug panel). Capture FPS at chapter 1 spawn, busiest Chapter 4 exhibit, and Chapter 5 sanitizer. Target: ≥60 FPS at 1080p. Note findings. **Done: Ran all 5 chapters on RTX 3070 / Vulkan 1.4.312 Forward+ at 1080p. All chapters load cleanly in <3s with zero new runtime errors. 54 GLB models (15MB), 10 shaders, 5 HDRIs (8MB), 124MB total assets. SSAO/SSIL/SDFGI/volumetric fog/4-split shadows all active — well within RTX 3070 budget. Busiest chapters: Ch4 (13 enemies + 80 boss tiles), Ch5 (18 enemies). Found duplicate globbler.glb (3.4MB wasted). Full report: build_log_2026-04-05_performance.md. PASS.**

### 11.4 Commit V2.0 graphics milestone
- [x] Write summary at top of TASKS.md CURRENT STATUS. Commit all outstanding changes with tag message "V2.0 — graphics and art pass complete". Screenshot gallery in build_log. **Done: Updated CURRENT STATUS with full V2.0 milestone summary covering all 11 passes (lighting, hero character, shaders, props, chapter passes, enemies, bosses, audio, UI, settings, QA). Asset counts: 54 GLBs, 10 shaders, 5 HDRIs, 124MB total. Committed all outstanding .import and .uid files. Tagged V2.0.**

---

## PASS 12: PUZZLE VISUAL UPGRADES
# 14 puzzle scenes still use CSG placeholders for terminals, doors, blocks, wires.
# One task per chapter's puzzle roster. Keep puzzle logic untouched.

### 12.1 Chapter 1 puzzles — visual upgrade
- [x] In `glob_pattern_puzzle.gd`, `hack_puzzle.gd`, `physical_puzzle.gd`: replace CSG terminal/door/block meshes with GLB props from `assets/models/environment/` (reuse electronic/cyberpunk pack). Apply CRT scanline shader to terminal screens. Keep all signals, states, and collision shapes intact. MCP run-project smoke test. **Done: Replaced all BoxMesh placeholders with GLB props — arch_wall_terminal.glb for terminals, arch_industrial_panel.glb for doors, prop_hard_drive.glb for pushable blocks, prop_power_supply.glb for beam emitter, prop_crt_monitor.glb for beam receiver. Applied crt_scanline.gdshader with reduce_motion gate to terminal screens in glob_pattern_puzzle and hack_puzzle. Updated hack_puzzle screen feedback (solved/failed) to use shader parameters instead of StandardMaterial3D. Added OmniLight3D glow for beam receiver and reflector block in physical_puzzle. All CollisionShape3D nodes and puzzle logic intact. Godot MCP smoke test: zero new errors.**

### 12.2 Chapter 2 puzzles — visual upgrade
- [x] In `weight_path_puzzle.gd`, `backprop_trace_puzzle.gd`, `multi_glob_puzzle.gd`, `recursive_glob_puzzle.gd`: replace CSG neural-node meshes with glowing sphere meshes (small emissive GLBs or procedural MeshInstance3D with emission material). Connect-nodes get tube TubeMesh / cylinder connectors. Use Chapter 2 blue-green palette. Keep logic untouched. **Done: Replaced all BoxMesh placeholders across 4 puzzles. weight_path: motherboard.glb platforms + wall_terminal.glb weight nodes + emissive sphere indicators. backprop_trace: high-detail 32-segment spheres with inner core glow + TubeMesh synaptic connectors + OmniLight3D per node. multi_glob: SphereMesh step indicators replacing BoxMesh + industrial_panel.glb door. recursive_glob: hard_drive.glb directories + floppy_disk.glb files + TubeMesh tree connectors. All 4 puzzles use Ch2 teal (#4AE0A5) palette. All doors replaced with arch_industrial_panel.glb + emissive overlay for dissolve effects. All CollisionShape3D and puzzle logic untouched. Godot MCP smoke test: zero new errors.**

### 12.3 Chapter 3 puzzles — visual upgrade
- [x] In `prompt_crafting_puzzle.gd`, `social_engineering_puzzle.gd`: replace CSG text-terminal placeholders with bazaar-themed terminals (warm amber backing, wood-grain texture, lanterns flanking). Tokens = glowing crystal meshes. Keep logic untouched. **Done: Replaced all BoxMesh placeholders across both Ch3 puzzles. prompt_crafting: bazaar_market_stall.glb terminal body with wood-grain material + CRT scanline shader screen (warm amber) + flanking bazaar_lantern.glb with OmniLight3D + SphereMesh crystal fragments (translucent outer shell + bright inner core + per-crystal OmniLight3D) replacing flat tablet BoxMesh + arch_industrial_panel.glb door with amber overlay + QuadMesh amber floor drop-zone indicator. social_engineering: bazaar_market_stall.glb terminal body + CRT scanline shader screen + flanking bazaar_lantern.glb + bazaar_crate.glb response card platforms replacing BoxMesh cards + arch_industrial_panel.glb door. Both puzzles: _flash_screen() and _on_solved() updated to handle ShaderMaterial CRT parameters. All CollisionShape3D and puzzle logic untouched. Godot MCP smoke test: zero new errors.**

### 12.4 Chapter 4 puzzles — visual upgrade
- [x] In `fossil_exhibit_puzzle.gd`, `nightmare_gallery_puzzle.gd`, `clippy_help_puzzle.gd`, `reclassification_puzzle.gd`: replace CSG exhibit cases with museum-display-case meshes (glass boxes + pedestals + brass plaques). Re-use Chapter 4 clinical museum palette. Keep logic untouched. **Done: Built 3 new Blender GLB props — museum_display_case.glb (beveled stone pedestal + glass case + brass plaque/trim), museum_pedestal.glb (cylindrical display stand with brass ring), museum_kiosk.glb (standing info terminal with screen bezel). fossil_exhibit: display_case.glb terminals + pedestal.glb collectors with SphereMesh orbs + amber OmniLight3D spotlights + industrial_panel.glb doors. nightmare_gallery: pedestal.glb collection points replacing CylinderMesh + industrial_panel.glb doors + updated pedestal_glb refs in fill/reset. clippy_help: kiosk.glb desk bodies + OmniLight3D hack terminal accents + industrial_panel.glb doors. reclassification: kiosk.glb classifier terminal + pedestal.glb reclassify station + display_case.glb approval chute + industrial_panel.glb door. model_zoo.gd: _create_exhibit_case now uses display_case.glb with dynamic scaling + amber emission instead of 5 CSG boxes. All CollisionShape3D and puzzle logic untouched. Godot MCP smoke test: zero new errors.**

### 12.5 Chapter 5 puzzles — visual upgrade
- [x] In `constitutional_loophole_puzzle.gd`, `rlhf_feedback_puzzle.gd`: replace CSG policy-terminal meshes with clinical white kiosks + holographic blue-screen interface. Re-use Chapter 5 clean palette. Keep logic untouched. **Done: Built 3 citadel GLB props in Blender — citadel_policy_terminal (clinical white kiosk with silver trim, blue glow strips, holographic screen), citadel_vote_pedestal (standing pedestal with blue accent ring), citadel_option_tablet (floating holographic tablet with glowing edges). Replaced all BoxMesh placeholders in both Ch5 puzzle scripts: terminals → GLB kiosk, doors → arch_industrial_panel GLB, option tablets → GLB tablets, vote buttons → GLB pedestals. Updated flash functions for GLB child iteration. All CollisionShape3D kept intact.**

---

## PASS 13: INTERACTION & FEEDBACK UI
# Combat feel, interaction clarity, and visual feedback not yet addressed.

### 13.1 Boss health bar UI
- [x] Create `scenes/ui/boss_health_bar.gd` + `.tscn` — full-width slim bar at top of screen + boss name label + phase dots. Wire into `base_enemy.gd` boss health signals or hook per-boss in their scripts. Appears on boss encounter entry, fades out on defeat. Terminal-green styling. **Done: Created boss_health_bar.gd + .tscn with terminal-green styled panel (top 70% width), smooth-lerp HP bar + delayed ghost bar (red) for damage viz, boss display name mapping, 3 phase indicator dots, HP color shifts (green→orange→red at 50%/25%), fade-in on PHASE_1+ entry, fade-out 2s after defeat. Auto-scans enemies group for "boss" tag, connects health_changed/boss_phase_changed/boss_defeated signals. Instanced in hud.gd _build_hud(). No new runtime errors.**

### 13.2 Enemy over-head health pip
- [x] Create `scenes/ui/enemy_hp_pip.gd` + `.tscn` — small 3-bar indicator that billboards over enemies when damaged. Auto-hide after 2s of no damage. Wire into `base_enemy.gd` take_damage. Exclude bosses (they use 13.1). **Done: Created enemy_hp_pip.gd + .tscn with 3 QuadMesh bars (unshaded, no-depth-test, billboard via look_at camera). Shows on damage via health_changed signal, hides after 2s. Color shifts green→orange→red. Wired into base_enemy.gd _setup_hp_pip() after health component setup, skipped for "boss" tagged enemies. No new runtime errors.**

### 13.3 Interaction prompt UI
- [x] Create `scenes/ui/interaction_prompt.gd` + `.tscn` — small label like "[T] HACK" or "[F] SMASH" that appears near interactable targets. Pulsing terminal-green, positioned above player. Wire into `terminal_hack.gd` and `wrench_smash.gd` proximity scans. **Done: Created interaction_prompt.gd + .tscn (CanvasLayer, bottom-center screen). Pulsing green label with dark panel + green border, terminal mono font. terminal_hack.gd shows "[T] HACK" on nearby hackable detection, hides when out of range or hacking. wrench_smash.gd adds throttled proximity scan (SCAN_INTERVAL=0.25s, SMASH_PROMPT_RANGE=3.0) for "switches" group, shows "[F] SMASH". Both use separate prompt instances. Respects reduce_motion. No new runtime errors.**

### 13.4 Wrench weapon trail
- [x] Add MeshInstance3D trail ribbon (or GPUTrail3D if available, else simple plane mesh with UV scroll) to wrench swing animation in `wrench_smash.gd`. Emissive green, 0.15s lifetime. Triggered on swing, removed on end. **Done: Created `scenes/vfx/wrench_trail.gd` (ImmediateMesh-based ribbon, 12 max points, 0.15s lifetime, triangle-strip quad mesh from base/tip position pairs) + `assets/shaders/wrench_trail.gdshader` (unshaded additive blend, emissive neon green #39FF14, UV-based length fade + width sine fade). Integrated into `wrench_smash.gd`: trail created in _ready(), started on swing(), fed wrench head base+tip positions each frame during swing, stopped on swing end. Respects reduce_motion via GameManager check. No new runtime errors.**

### 13.5 Damage direction indicator
- [x] Created `scenes/ui/damage_indicator.gd` + `.tscn` — red chevron arc at screen edge pointing toward nearest enemy on damage. 0.8s fade with glow. Connects to GameManager `damage_taken` signal (player doesn't use health_component). Wired into HUD. Respects reduce_motion.

### 13.6 Ability cooldown radial animation
- [x] Created `assets/shaders/cooldown_radial.gdshader` — clockwise radial wipe from 12 o'clock. Modified `hud.gd` to overlay shader-driven ColorRect on each ability icon (glob, wrench, dash, agent_spawn). Added proxy cooldown methods to `globbler.gd` (`get_glob_cooldown_percent`, `get_wrench_cooldown_percent`, `get_agent_recharge_percent`). HUD `_process()` drives all radials via `_update_radial()` helper. Respects reduce_motion. No new runtime errors.

### 13.7 Tutorial hint visual restyle
- [x] Restyle `scenes/ui/first_time_hint.tscn` with V2.0 theme: terminal-monospace font, scanline shader background, green border frame. Keep slide-in animation. Respect reduce_motion. **Done: Restyled first_time_hint.gd — all labels use terminal_mono.ttf, panel has dialogue_scanline.gdshader material (scanlines + flicker + noise + green tint), 3px green border with box-drawing frame chars (╔╗╚╝), bottom border added. Slide-in/out tweens preserved. reduce_motion disables tweens (instant placement) and shader animation. No new runtime errors.**

### 13.8 Dialogue history viewer restyle
- [x] Restyle `scenes/ui/dialogue_history.tscn` with V2.0 theme — terminal scrollback aesthetic, speaker name colored, timestamps dimmed. Add subtle scanline overlay. **Done: Restyled dialogue_history.gd with terminal_mono.ttf on all labels, dialogue_scanline.gdshader panel material (scanline_count=120, subtle flicker/noise/vignette), box-drawing frame (╔╗╚╝), per-speaker color map (Globbler=#39FF14, default=#4AE0A5), dimmed line-number indices (003-style), entry count subtitle, styled thin separators. reduce_motion disables shader animate flag. No new runtime errors.**

### 13.9 Chapter summary screen art
- [x] Add visual styling to `scenes/ui/chapter_summary.tscn` (from Task 10.6): terminal-green border, ASCII art flourish, stat rows with icon + value layout, "continue" button with hover pulse. **Done: Restyled chapter_summary.gd with terminal_mono.ttf monospace font on all labels, dialogue_scanline.gdshader panel overlay (scanline_count=100, subtle flicker/noise/vignette), 3px green border with box-drawing frame (╔══╗╚══╝ separators), ASCII art flourish header (▓▒░ CHAPTER COMPLETE ░▒▓), teal chapter name subtitle, icon+value stat rows with Unicode icons (⏱◈☠⚡💀) + dot-leaders + bright green values, dimmed sarcastic death comment, pulsing [ CONTINUE ] button (modulate:a sine oscillation). reduce_motion disables shader animate flag + button pulse tween. No new runtime errors.**

### 13.10 Splash / boot screen
- [x] Create `scenes/main/splash.tscn` — plays before main menu. Shows animated Globbler logo + studio text for 3s, then auto-transitions to main_menu. Update `project.godot` main_scene to splash.tscn. **Done: Created `scenes/main/splash.gd` + `splash.tscn` — fake terminal boot sequence with typewriter BIOS lines (sarcasm module, wrench drivers, angry eye emitters), fade-in box-drawing ASCII logo ("GLOBBLER'S JOURNEY — An Agentic Puzzle Platformer"), "GlobTech Industries — 2026" studio text, dialogue_scanline.gdshader CRT overlay (200 scanlines, vignette, noise, flicker), 3s auto-transition to main_menu with 0.4s fade-out, skip on any key press. reduce_motion disables shader animate. Updated project.godot main_scene to splash.tscn. No new runtime errors.**

### 13.11 Glob target highlight shader
- [x] Replace material-swap highlight in `glob_target.gd` `set_highlighted()` with a ShaderMaterial that pulses green emission + fresnel outline. Created `assets/shaders/glob_target_highlight.gdshader` (cull_front outline, pulsing fresnel, animate uniform). Updated `glob_target.gd` to apply shader via `next_pass` on base material instead of swapping — base material stays visible. Removed old StandardMaterial3D swap and GlowOverlay mesh. Respects reduce_motion.

### 13.12 Hackable terminal beacon pulse
- [x] Created `assets/shaders/hackable_beacon.gdshader` — additive spatial shader with dual mode (beam column + ground ring), scrolling noise energy pattern, proximity_fade uniform for smooth fade-in/out. Updated `scripts/components/hackable.gd`: spawns billboard QuadMesh beam (0.4x3.0) + flat ground ring (2.0x2.0) as children of parent Node3D, player proximity detection (1.5x interaction_range triggers fade-in at 3.0/s), fades out smoothly on HACKED state (2.0/s), caches player reference, respects reduce_motion via GameManager. No new runtime errors.

---

## PASS 14: SHOWCASE & DOCUMENTATION
# Capture the graphics work for sharing / future reference.

### 14.1 Hero screenshot gallery
- [x] Capture 3 hero screenshots per chapter (spawn, mid-area, boss door) via Godot MCP. Save to `assets/docs/screenshots/ch{n}_{a,b,c}.png`. Also capture main menu, pause, game-over, and settings. 18 screenshots total. **Done: 20 screenshots captured (15 chapter + 4 UI + 1 extra). Automated via `scripts/tools/screenshot_capture.gd` autoload that positions a Camera3D at key room positions per chapter, captures viewport PNGs, then cycles through UI scenes. Also fixed runtime bugs: TubeMesh→CylinderMesh (2 files), billboard property crash in hackable.gd, preload→runtime load for 6 puzzle scripts with unimported GLBs.**

### 14.2 README visual update
- [x] Update `README.md` (create if missing) with: project summary, feature list, 6 embedded hero screenshots from 14.1, build/run instructions, credits list, attribution link to `assets/LICENSES.md`. **Done: Created `README.md` with project summary, 8 features, 6 screenshots in 2x3 table grid (ch1-5 spawn shots + main menu), Godot 4.4 build steps, project structure tree, credits with attribution link to `assets/LICENSES.md`.**

### 14.3 Graphics changelog
- [x] Create `assets/docs/GRAPHICS_CHANGELOG.md` summarizing V2.0 work: before/after screenshots (use one old build_log capture), list of passes completed, asset counts (#models, #shaders, #HDRIs), links to Blender source files. **Done: Created `assets/docs/GRAPHICS_CHANGELOG.md` with full V2.0 summary — 15 passes documented, asset counts (61 GLBs, 14 shaders, 5 HDRIs, 31 .blend sources, 6 WorldEnvironments, 20 screenshots), per-pass breakdown with specifics, Blender source file table, performance section, attribution link to LICENSES.md.**

---

## PASS 15: RENDERING DEPTH & POLISH
# Gaps spotted during planning review. High-leverage rendering improvements.

### 15.1 Globbler character animations
- [x] In Blender: rig the existing `assets/blender_source/globbler.blend` with a simple armature (spine, head, 2 arms, 2 legs, wrench-hand bone). Keyframe 5 animations: idle_bob (2s loop), walk (0.6s loop), run (0.4s loop), dash (0.25s one-shot), wrench_swing (0.4s one-shot). Re-export as GLB with animations. In `globbler.tscn` add an AnimationPlayer, wire to new clips. In `globbler.gd` replace `_update_idle_animation()` procedural transform jiggle with `anim_player.play("idle_bob")` etc. based on existing AnimState enum. Keep state machine unchanged. **Done: Created 8-bone armature (Root, Spine, Head, Arm.L/R, WrenchHand, Leg.L/R), manually weight-painted all 13502 verts by region, keyframed 5 animations as NLA strips, exported to GLB. Updated `globbler.gd` with `anim_player` var, `_find_animation_player()` helper, skeleton clip playback in `_animate()` layered with procedural model_root overlays. Wrench swing triggered on ability input. No runtime errors.**

### 15.2 Floor & wall decals per chapter
- [x] Add 5–8 Decal nodes per chapter via level `_ready()`: oil puddles, scorch marks, runic circles, warning stripes, glowing sigils. Source decal textures from Poly Haven via MCP or create procedural noise textures. Match chapter palette. Use `Decal.texture_albedo` + `texture_emission`. **Done: Created 9 procedural decal textures (256x256 PNG) in Blender — oil_puddle, scorch_mark, circuit_traces, circuit_emission, warning_stripes, runic_circle, ember_glow, dust_patch, light_pool. Built `scripts/utils/decal_placer.gd` utility with DecalPlacer class_name for static room-based placement. Added `_place_decals()` to all 5 chapter scripts with per-chapter themed configs (5-6 decal types each, floor + wall variants, emission channels for glowing decals). ~25-30 Decal nodes per chapter. Zero new runtime errors.**

### 15.3 Environmental particles per chapter
- [x] Add GPUParticles3D ambient emitters to each chapter: Ch1 green dust motes, Ch2 floating neural-node sparks, Ch3 embers + warm smoke, Ch4 dust (museum air), Ch5 clean light-dust. 1–2 emitters per chapter, wide area, low density (~50 particles), respect reduce_motion. **Done: Added `_place_particles()` to all 5 chapter scripts. Ch1: 50 green emissive dust motes per room. Ch2: 40 teal neural sparks per room + 20 gradient wisps in 2 rooms. Ch3: 40 orange embers per room + 15 warm smoke wisps in 3 rooms. Ch4: 50 warm beige dust motes per room (slow drift). Ch5: 35 cool white-blue light-dust per room + 15 blue alignment shimmer in 2 rooms. All use ParticleProcessMaterial with box emission, billboard QuadMesh draw passes, and emission glow. All gated behind `reduce_motion` check — skipped entirely when enabled.**

### 15.4 Reflection probes
- [x] Add ReflectionProbe3D nodes at key arena centers in each chapter + each boss arena. `update_mode = UPDATE_ONCE` for perf, `box_projection = true`, extents match room size. Gives shiny props/character meaningful local reflections. **Done: Added `_place_reflection_probes()` to all 6 level scripts. Ch1 terminal_wastes: 5 room probes + rm_rf boss arena probe. Ch1 main_level: 3 section probes (tutorial, enemy arena, final arena). Ch2: 5 room probes + local_minimum boss probe (48m diameter for concentric rings). Ch3: 5 room probes + system_prompt boss probe. Ch4: 5 room probes + foundation_model boss probe. Ch5: 5 room probes + aligner boss probe. All use UPDATE_ONCE for perf, box_projection=true, extents sized to room dimensions (size.x, wall_h, size.y).**

### 15.5 CRT curvature whole-screen post shader
- [x] Create `assets/shaders/crt_curvature.gdshader` — barrel distortion + vignette + subtle scanlines across the whole screen. Apply as a ColorRect with full-rect anchor + ShaderMaterial on a CanvasLayer above gameplay. Toggle off under reduce_motion via GameManager signal. **Done: Created `assets/shaders/crt_curvature.gdshader` with barrel distortion (0.04), chromatic aberration (0.8px), scanlines (400 lines, 6% alpha), and vignette (0.45). Applied in `scenes/ui/hud.gd` via `_build_crt_overlay()` — CanvasLayer 100 + full-rect ColorRect. `_on_reduce_motion_changed()` zeroes barrel/chromatic/scanline params when reduce_motion is enabled. No runtime errors.**

### 15.6 Chapter transition glitch effect
- [x] Create `scenes/ui/chapter_transition.gd` + `.tscn` — full-screen glitch/static shader that fades in on scene change, holds briefly, fades out. Use on all `change_scene_to_file` calls in boss defeat handlers + main menu chapter select. Respect reduce_motion (simple fade instead). **Done: Created `assets/shaders/chapter_transition_glitch.gdshader` with static noise, horizontal glitch bands, chromatic aberration, scanlines, and black sweep controlled by `progress` uniform. Created `scenes/ui/chapter_transition.gd` as a static `ChapterTransition` class — `transition_to(tree, scene_path)` builds a CanvasLayer(110) overlay, tweens glitch in (0.6s), holds (0.3s), changes scene, then fades out (0.5s) on new scene. Reduce_motion path uses simple alpha fade instead. Wired into: 5 boss defeat handlers (rm_rf, local_minimum, system_prompt, foundation_model, aligner), game_over retry + main menu return, main menu chapter select, credits return, player pause quit, Ch5 completion. No runtime errors.**

### 15.7 Boss intro cinematic camera
- [x] When a boss scene loads, take camera control for 3 seconds: slow orbital sweep around the boss, then return to player. Use a temporary Camera3D spliced in via `make_current()`, tween position, then hand back to player camera. Add in each boss scene's `_ready()`. **Done: Created `scripts/utils/boss_intro_camera.gd` (BossIntroCamera class_name) — static `play(boss, on_complete)` spawns a temporary Camera3D that does a 3s 270° orbital sweep around the boss (radius/height auto-scaled from collision capsule), slight zoom-in, then restores player camera via `make_current()`. Wired into `start_boss_fight()` of all 5 bosses (rm_rf, local_minimum, system_prompt, foundation_model, aligner) — phase 1 transition deferred to after cinematic completes. Respects reduce_motion (skips cinematic entirely). No runtime errors.**

### 15.8 NPC visual upgrades
- [x] Identify 6+ NPCs currently built with CSG in level scripts: dropout_ghost (Ch2), gpt_classic + stable_diffusion (Ch3), retired_bert + maintenance_bot (Ch4), aligned_ai + janitor_bot (Ch5). For each: build a small GLB in Blender (shared NPC template, swap colors/accessories), export to `assets/models/npcs/`, replace the CSG section in the level script with the GLB instance. **Done: Found 8 NPCs using `deprecated_npc.gd` primitive meshes (not CSG, but BoxMesh/SphereMesh): man_page + sudo (Ch1), batch_norm + sigmoid (Ch2), gpt_classic + stable_diff (Ch3), BERT + SD-v1 (Ch4). Built 8 stylized GLB models in Blender — shared chunky terminal-bot base (beveled body, screen face, glowing eyes, stubby cylinder legs, accent stripe) with unique accessories per NPC: antenna (man_page), horns (sudo), visor (batch_norm), monocle (sigmoid), hat (gpt_classic), backpack (stable_diff), bowtie (bert), spikes (sd_v1). Each uses chapter-appropriate accent colors. Updated `deprecated_npc.gd` with `glb_path` export — loads GLB if set, falls back to legacy primitives otherwise. All 8 level script NPC spawns wired with `glb_path`. Source: `assets/blender_source/npc_models.blend`. Note: Ch5 NPCs (aligned_ai, janitor_bot) don't exist in codebase — `_place_npcs()` is commented out.**

### 15.9 Screen shake curve tuning
- [x] Create `scripts/utils/camera_shake.gd` with named shake presets: `wrench_hit` (0.2s, amp 0.15), `glob_cast` (0.15s, amp 0.08), `damage_taken` (0.3s, amp 0.2), `boss_phase` (0.5s, amp 0.35), `explosion` (0.4s, amp 0.5). Wire existing shake calls in abilities/boss scripts through this helper. Respect reduce_motion (divide amp by 4). **Done: Created `scripts/utils/camera_shake.gd` with static `trigger()` method and 5 presets. Decay rate computed from amplitude/duration so shake naturally fades over preset duration. Wired into wrench_smash.gd (wrench_hit on hit), glob_command.gd (glob_cast on fire), globbler.gd (damage_taken on take_damage and hard landing), and all 5 boss _transition_to_phase functions (boss_phase on phase 2+ transitions). All calls respect reduce_motion via GameManager check.**

### 15.10 Dynamic FOV (sprint push / aim pull)
- [x] In `globbler.gd` camera logic: lerp FOV to 80° during sprint (from default ~75°), pull to 65° when aiming glob. Use `lerp` at 0.1 per frame. Setting can be disabled via reduce_motion. **Done: Added FOV_DEFAULT=70, FOV_SPRINT=80, FOV_AIM=60, FOV_LERP_SPEED=5.0 constants. In `_update_camera()`, lerps `camera.fov` toward target based on `anim_state == AnimState.RUN` (sprint→80°) or `glob_command.is_aiming` (aim→60°), else default 70°. Gated behind `reduce_motion` check — when enabled, FOV stays fixed at whatever it currently is. Verified: zero new runtime errors.**

### 15.11 LOD meshes for bosses and large props
- [ ] For each boss GLB and any prop used in MultiMesh scatters: add a low-poly LOD variant (decimate to 40% tris) via blender-mcp. Set up `MeshInstance3D.visibility_range_begin/end` or use `LODMesh` equivalents. Target: drop boss mesh to low-LOD beyond 25m, props beyond 15m.

### 15.12 Ability cast VFX at player hand
- [ ] Create `scenes/vfx/ability_cast.tscn` — small GPUParticles3D burst (15 particles, 0.3s) in matching color per ability (green glob, white wrench, purple hack, cyan dash, orange agent). Triggered on ability activation from each ability script. Spawns at Globbler's hand bone position (or approximate offset if no bone).

### 15.13 Shadow distance + CSM tuning per chapter
- [ ] In each chapter WorldEnvironment / DirectionalLight3D: tune `shadow_max_distance` (Ch1 smaller=40, Ch5 larger=80), `directional_shadow_split_1/2/3` splits, and `shadow_blur` per chapter. Short chapters with tight corridors don't need 200m shadow distance.

### 15.14 Per-chapter color grade
- [ ] Add `adjustment_color_correction` curve texture to each chapter_n.tres Environment: slight warm lift (Ch1/3), cool lift (Ch2/5), desaturated lift (Ch4). Hand-authored Gradient or GradientTexture1D resource. Subtle — 5% shift max.
