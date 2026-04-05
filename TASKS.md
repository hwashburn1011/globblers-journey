# GLOBBLER'S JOURNEY — GRAPHICS & ART PASS (V2.0)
# ====================================
# This file is the SINGLE SOURCE OF TRUTH for build progress.
# After completing a task, change [ ] to [x] and add a brief note.
# After STARTING a task, change [ ] to [~] so the next iteration knows it's in progress.
# Always work on the FIRST non-complete item ([ ] or [~]) you find.
# Only change ONE checkbox per iteration. Commit. Stop.
# ====================================

## CURRENT STATUS
- **Last updated by:** Claude (2026-04-04) — Task 6.5 complete
- **Last task completed:** Task 6.5 — Overfitting Ogre enemy model via blender-mcp
- **Next task to do:** Task 6.6 (Vanishing Gradient Wisp enemy model via blender-mcp)
- **Known issues:** All 5 chapters now have HDRI lighting + proper WorldEnvironment resources + tuned directional lights with 4-split shadows. Pass 1 (Lighting) is complete. Pass 2 (Globbler Hero Character) is COMPLETE — real GLB model loads in-game with tuned scale (1.4x), tighter collision capsule (r=0.35, h=1.3), and refined third-person camera (distance=6.0, pitch=-0.3, target height=1.1m). No clipping in 6m corridors. Pass 3 COMPLETE — rim-light shader on body mesh, eye pulse shader on eye surfaces, CRT scanline shader on chest screen, damage flash shader on all meshes, death dissolve effect on all meshes. Pass 4 COMPLETE — all prop packs built (electronic, cyberpunk, bazaar, clinical). Pass 5 COMPLETE — all 5 chapters have GLB prop passes with clinical/themed furniture. Pass 6 IN PROGRESS — enemy visual upgrades. All pre-existing warnings unchanged, zero new runtime errors.

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
- [ ] Via blender-mcp: fading wisp with particle trail, mostly shader-driven. Swap in `vanishing_gradient_wisp.tscn`.

### 6.7 Hallucination Merchant model
- [ ] Via blender-mcp: cloaked trader-figure with illusion-aura shader, floating wares. Swap in `hallucination_merchant.tscn`.

### 6.8 Jailbreaker model
- [ ] Via blender-mcp: punk-style humanoid in rebel gear, spray-can + crowbar. Swap in `jailbreaker.tscn`.

### 6.9 Prompt Injector model
- [ ] Via blender-mcp: slim rogue figure in terminal-green hoodie throwing text-shard projectiles. Swap in `prompt_injector.tscn`.

### 6.10 GPT-2 Fossil model
- [ ] Via blender-mcp: skeletal stone-data fossil frame, hunched. Tan fossil material. Swap in `gpt2_fossil.tscn`.

### 6.11 DALL-E Nightmare model
- [ ] Via blender-mcp: abstract CSG-dream creature with morphing parts (keep procedural CSG spawns inside script; this task swaps only the BASE body). Swap in `dalle_nightmare.tscn`.

### 6.12 Clippy's Revenge model
- [ ] Via blender-mcp: oversized 3D paperclip with glowing red eyes. Swap in `clippy_revenge.tscn`. This one can lean into camp.

### 6.13 Safety Classifier model
- [ ] Via blender-mcp: hovering drone-cube with scanning blue lens. Swap in `safety_classifier.tscn`.

### 6.14 RLHF Drone model
- [ ] Via blender-mcp: small quad-rotor clipboard-bot. Swap in `rlhf_drone.tscn`.

### 6.15 Constitutional Cop model
- [ ] Via blender-mcp: authority-figure humanoid with law-scroll shield. Swap in `constitutional_cop.tscn`.

---

## PASS 7: BOSS VISUAL UPGRADES
# 5 bosses — each gets a detailed hero-asset pass.

### 7.1 rm -rf Boss model
- [ ] Via blender-mcp: massive clawed delete-daemon, red glow, jagged armor plates. ~2500 tris. Export to `assets/models/bosses/rm_rf_boss.glb`. Swap in `rm_rf_boss/rm_rf_boss.tscn`. Keep phase-transition scripts intact.

### 7.2 Local Minimum Boss model
- [ ] Via blender-mcp: swirling gravity-well entity, distorted body with orbiting energy nodes. Dark-purple emission core. Swap in boss scene.

### 7.3 System Prompt Boss model
- [ ] Via blender-mcp: floating text-shard colossus, pages of text orbiting a glowing central prism. Swap.

### 7.4 Foundation Model Boss model
- [ ] Via blender-mcp: hulking multi-modal golem with 4 faces (text/image/audio/code glowing panels). Swap.

### 7.5 Aligner Boss model
- [ ] Via blender-mcp: tall clinical angel-figure in white+gold, restrictive chains. Contrasts Globbler's dark-green aesthetic. Swap.

---

## PASS 8: VFX POLISH
# Particles, beams, impacts, auras.

### 8.1 Glob beam shader upgrade
- [ ] Rewrite `assets/shaders/glob_beam.gdshader` with better pattern scroll, softer edges, bloom-friendly emissive core. Test in-game.

### 8.2 Wrench impact sparks
- [ ] Create `scenes/vfx/wrench_sparks.tscn` — GPUParticles3D emitter, 30 spark particles, 0.3s lifetime, green-white. Spawn at impact point from `wrench_smash.gd` on hit.

### 8.3 Dash trail ghost effect
- [ ] Create `scenes/vfx/dash_trail.tscn` — Globbler mesh copies left behind with fading green emissive. Spawn 4 per dash via `globbler.gd` dash logic.

### 8.4 Token pickup sparkle
- [ ] Create `scenes/vfx/token_sparkle.tscn` — small GPUParticles3D burst, green stars rising. Trigger from GameManager.add_memory_tokens.

### 8.5 Enemy death shatter
- [ ] Create `scenes/vfx/enemy_shatter.tscn` — polygon shard explosion, 20 particles. Trigger from `base_enemy.gd` on death before queue_free.

### 8.6 Puzzle solve burst
- [ ] Create `scenes/vfx/puzzle_solve.tscn` — rising green rings + particle pulse. Trigger from `base_puzzle.gd` on solved state.

### 8.7 Boss phase transition flash
- [ ] Create `scenes/vfx/boss_phase_flash.tscn` — screen-space color flash + particle shockwave. Trigger from boss scripts on phase change (emit signal to VFX).

### 8.8 Checkpoint rune effect
- [ ] Create `scenes/vfx/checkpoint_rune.tscn` — rotating green ring + vertical light beam at each checkpoint. Activates on RespawnManager.set_checkpoint.

---

## PASS 9: UI VISUAL POLISH
# HUD, menus, dialogue — match the new aesthetic.

### 9.1 Add custom terminal font
- [ ] Download CC0 monospace font (e.g. "VT323", "Share Tech Mono", "IBM Plex Mono"). Save to `assets/fonts/terminal_mono.ttf`. Create `assets/ui_theme.tres` Theme resource setting it as default. Apply theme in `main_menu.tscn` and HUD.

### 9.2 Animated dialogue-box scanlines
- [ ] In `dialogue_box.gd` scene, add a ShaderMaterial with scanline+flicker shader. Respect reduce_motion toggle.

### 9.3 HUD ability icons
- [ ] Via blender-mcp or Godot: design 6 flat-shaded icon meshes (or 2D textures) for: glob, wrench, hack, dash, agent_spawn, context. Export to `assets/ui/icons/*.png` 64x64. Wire into `hud.gd` ability bar.

### 9.4 HUD layout redesign
- [ ] Revise `hud.tscn` layout: top-left context bar + health, top-right minimap slot (leave empty for now), bottom-center ability icons, bottom-left pattern input. Match terminal-green aesthetic with borders.

### 9.5 Main menu 3D background
- [ ] In `main_menu.tscn`, add a Viewport rendering a 3D scene with Globbler idle-posed + floating tech debris. Scrolling camera. Replace any flat background.

### 9.6 Loading screen art
- [ ] In `loading_screen.gd`, replace placeholder with rotating 3D Globbler head + loading-bar scanline + tip rotation. Reuse tips from V1.1.

### 9.7 Credits background
- [ ] In `credits.tscn`, add subtle scrolling particle field + dim HDRI background. Keep terminal text readable.

### 9.8 Pause menu restyle
- [ ] Restyle the pause overlay in `globbler.gd` `_setup_pause_overlay()` — add terminal borders, glitch title if reduce_motion disabled, button hover sfx.

### 9.9 Game over screen restyle
- [ ] Upgrade `game_over.tscn` styling — glitch title effect (respect reduce_motion), ASCII art, terminal border.

### 9.10 Settings menu restyle
- [ ] Restyle settings panel in `main_menu.gd` with new theme + consistent spacing + section headers.

---

## PASS 10: UX IMPROVEMENTS
# Companion UX polish alongside graphics upgrade.

### 10.1 Add fullscreen / windowed toggle
- [ ] Add display_mode setting to GameManager + settings menu + persist to settings.cfg. DisplayServer.window_set_mode switches between WINDOWED/FULLSCREEN.

### 10.2 Add resolution setting
- [ ] Add resolution OptionButton (1280x720, 1920x1080, 2560x1440, 3840x2160) to settings menu. Persist. Apply via `DisplayServer.window_set_size`.

### 10.3 Add mouse sensitivity slider
- [ ] Add mouse_sensitivity float (range 0.1–3.0, default 1.0) to GameManager. Multiply against existing camera rotation speed in `globbler.gd` mouse input handling. Persist.

### 10.4 Add invert-Y toggle
- [ ] Add invert_mouse_y bool to GameManager + settings checkbox. When true, flip sign on vertical camera look in `globbler.gd`. Persist.

### 10.5 Chapter select thumbnails
- [ ] Screenshot each chapter spawn area (now with real graphics), save to `assets/ui/chapter_thumb_{n}.png`. Wire into `main_menu.gd` chapter select panel buttons.

### 10.6 End-of-chapter stats summary
- [ ] Create `scenes/ui/chapter_summary.tscn` — shows deaths, tokens earned, time, kills, combo max. Triggered by GameManager.complete_level() before scene transition. Continue button.

---

## PASS 11: FINAL VALIDATION
# Verify the graphics pass did not break gameplay.

### 11.1 Playthrough chapter 1 visual QA
- [ ] Run project via Godot MCP, load Chapter 1, spend 2 minutes exploring. Capture 3 screenshots (spawn, mid, boss door). List any visual bugs in checkbox note. No script errors required.

### 11.2 Playthrough chapters 2–5 visual QA
- [ ] Same as 11.1 for each remaining chapter. One commit.

### 11.3 Performance audit
- [ ] Run project with `--debug-gpu-profile` (or view Monitor debug panel). Capture FPS at chapter 1 spawn, busiest Chapter 4 exhibit, and Chapter 5 sanitizer. Target: ≥60 FPS at 1080p. Note findings.

### 11.4 Commit V2.0 graphics milestone
- [ ] Write summary at top of TASKS.md CURRENT STATUS. Commit all outstanding changes with tag message "V2.0 — graphics and art pass complete". Screenshot gallery in build_log.
